# CICD 发布平台架构设计文档

> 本文档用于面试讲解，详细介绍平台的 CI/CD 架构设计思路，特别是人工审批机制。

---

## 一、架构概览

### 1.1 设计理念

本平台参考 **Rancher、KubeSphere、Jenkins** 等企业级平台设计，实现了 **CI 与 CD 解耦**：

| 阶段 | 执行方 | 说明 |
|------|--------|------|
| CI（持续集成） | Jenkins | 代码检出、构建、测试、推送镜像 |
| CD（持续部署） | 平台 | 人工审批、K8s 部署、通知闭环 |

**核心优势**：
- 构建与部署解耦，职责清晰
- 生产环境强制审批，防止误发布
- 部署支持多集群灵活选择
- 全流程可审计、可追溯

### 1.2 流程图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CI/CD 完整流程                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│   │ 代码检出 │──▶│   构建   │──▶│   测试   │──▶│ 推送镜像 │            │
│   │ checkout │   │  build   │   │   test   │   │   push   │            │
│   └──────────┘   └──────────┘   └──────────┘   └────┬─────┘            │
│                                                      │                  │
│                        Jenkins 执行阶段              │                  │
│   ═══════════════════════════════════════════════════╪═════════════    │
│                        平台执行阶段                  │                  │
│                                                      ▼                  │
│                                               ┌──────────┐             │
│                                               │ 人工审批 │ ← 核心卡点   │
│                                               │ approval │             │
│                                               └────┬─────┘             │
│                                                    │                   │
│                                                    ▼                   │
│                                               ┌──────────┐             │
│                                               │   部署   │             │
│                                               │  deploy  │             │
│                                               └────┬─────┘             │
│                                                    │                   │
│                                                    ▼                   │
│                                               ┌──────────┐             │
│                                               │ 钉钉通知 │             │
│                                               └──────────┘             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 阶段状态展示

```
代码检出 [✅ 完成 3s] → 构建 [✅ 完成 45s] → 测试 [✅ 完成 12s] → 推送镜像 [✅ 完成 8s]
                                        ↓
                        审批 [⏳ 待通过] → 部署 [⏳ 等待]
```

---

## 二、人工审批机制（核心亮点）

### 2.1 审批触发条件

| 配置字段 | 类型 | 作用 |
|----------|------|------|
| `require_approval` | bool | 是否需要人工审批 |
| `deploy_env` | string | 部署环境（prod 生产环境建议强制开启） |

**触发逻辑**：
```go
// 生产环境或显式配置需要审批
if pipeline.DeployEnv == "prod" || pipeline.RequireApproval {
    // 创建审批记录，状态设为 pending
    approval := &models.CicdApproval{
        Status:        models.ApprovalStatusPending,
        RequestReason: "构建成功，申请部署到" + pipeline.DeployEnv + "环境",
        ExpireTime:    7天后过期,
    }
}
```

### 2.2 审批状态机

```
               构建成功
                  │
                  ▼
     ┌─────────────────────────┐
     │  审批阶段 (waiting)     │ ← 等待人工操作
     └───────────┬─────────────┘
                 │
        ┌───────┴───────┐
        │               │
     approve         reject
        │               │
        ▼               ▼
   ┌─────────┐    ┌─────────┐
   │ success │    │ failed  │
   └────┬────┘    └─────────┘
        │
        ▼
   自动触发部署阶段
```

### 2.3 审批 API 接口

| 接口 | 方法 | 功能 |
|------|------|------|
| `/api/v1/k8s/cicd/approval/list` | GET | 获取审批列表 |
| `/api/v1/k8s/cicd/approval/pending` | GET | 获取待审批列表 |
| `/api/v1/k8s/cicd/approval/action` | POST | 执行审批操作（approve/reject） |
| `/api/v1/k8s/cicd/stage/approve` | POST | 阶段级审批 |

### 2.4 审批核心逻辑

```go
func (s *Services) ApproveStage(ctx context.Context, stageID int64, userID int64, comment string) error {
    // 1. 校验阶段类型必须是 approval
    if stage.StageType != models.StageTypeApproval {
        return errors.New("该阶段不是审批阶段")
    }
    
    // 2. 校验状态必须是 waiting
    if stage.Status != models.StageStatusWaiting {
        return errors.New("该阶段当前不处于等待审批状态")
    }
    
    // 3. 记录审批人、审批意见
    s.dao.StageUpdateApproval(ctx, stageID, userID, "approved", comment)
    
    // 4. 审批通过后，自动激活部署阶段
    deployStage, _ := s.dao.StageGetByRunIDAndType(ctx, stage.RunID, models.StageTypeDeploy)
    if deployStage != nil {
        _ = s.dao.StageUpdate(ctx, deployStage.ID, map[string]interface{}{
            "status":       models.StageStatusPending,  // 变为待部署
            "deploy_image": run.ImageURL,
        })
    }
    
    return nil
}
```

### 2.5 审批数据模型

```go
// CicdPipelineStage 流水线阶段执行记录
type CicdPipelineStage struct {
    ID         int64  `json:"id"`
    RunID      int64  `json:"run_id"`        // 关联流水线运行记录
    StageType  string `json:"stage_type"`    // 阶段类型: checkout/build/test/push/approval/deploy
    StageName  string `json:"stage_name"`    // 阶段名称
    Status     string `json:"status"`        // 执行状态
    
    // 审批信息（适用于 approval 类型）
    ApprovalUserID   int64  `json:"approval_user_id"`   // 审批人
    ApprovalComment  string `json:"approval_comment"`   // 审批评论
    ApprovalDecision string `json:"approval_decision"`  // 审批决定: approved/rejected
    
    // 时间信息
    StartedAt   uint64 `json:"started_at"`
    FinishedAt  uint64 `json:"finished_at"`
}
```

### 2.6 阶段类型与状态常量

**阶段类型**：
| 常量 | 值 | 说明 |
|------|-----|------|
| `StageTypeCheckout` | checkout | 代码检出 |
| `StageTypeBuild` | build | 构建 |
| `StageTypeTest` | test | 测试 |
| `StageTypePush` | push | 推送镜像 |
| `StageTypeApproval` | approval | 人工审批 |
| `StageTypeDeploy` | deploy | 部署 |

**阶段状态**：
| 常量 | 值 | 说明 |
|------|-----|------|
| `StageStatusPending` | pending | 等待中 |
| `StageStatusRunning` | running | 执行中 |
| `StageStatusSuccess` | success | 成功 |
| `StageStatusFailed` | failed | 失败 |
| `StageStatusSkipped` | skipped | 跳过 |
| `StageStatusWaiting` | waiting | 等待审批 |
| `StageStatusAborted` | aborted | 已中止 |

---

## 三、Jenkins 与平台协作

### 3.1 回调机制

```
┌─────────────┐                      ┌─────────────┐
│   Jenkins   │                      │    平台     │
└──────┬──────┘                      └──────┬──────┘
       │                                    │
       │  1. 阶段回调 (实时)                │
       │  POST /stage/callback             │
       │  {stage_type, status}             │
       │ ──────────────────────────────────▶│
       │                                    │ 更新阶段状态
       │                                    │
       │  2. 最终回调 (构建完成)            │
       │  POST /pipeline/callback          │
       │  {status, image_url, digest}      │
       │ ──────────────────────────────────▶│
       │                                    │ 创建审批/部署阶段
       │                                    │ 发送钉钉通知
       │                                    │
```

### 3.2 回调安全：HMAC 签名验证

```go
// Jenkins 发送请求时计算签名
signature = HMAC-SHA256(secret, job_name + build_number + status)

// 请求头
X-Signature: <signature>

// 平台验证
func (s *Services) VerifyHMACSignature(signature, jobName string, buildNumber int, status string) bool {
    data := fmt.Sprintf("%s%d%s", jobName, buildNumber, status)
    expected := computeHMAC(s.hmacSecret, data)
    return hmac.Equal([]byte(signature), []byte(expected))
}
```

### 3.3 Jenkinsfile 阶段回调示例

```groovy
stage('构建') {
    steps {
        script { stageCallback('build', 'running') }  // 开始
        sh 'mvn clean package -DskipTests'
    }
    post {
        success { script { stageCallback('build', 'success') } }  // 成功
        failure { script { stageCallback('build', 'failed') } }   // 失败
    }
}

def stageCallback(String stageType, String status) {
    def body = [
        job_name     : env.JOB_NAME,
        build_number : env.BUILD_NUMBER.toInteger(),
        pipeline_id  : env.PIPELINE_ID.toLong(),
        stage_type   : stageType,
        status       : status
    ]
    httpRequest(
        url: "${PLATFORM_URL}/api/v1/k8s/cicd/stage/callback",
        httpMode: 'POST',
        contentType: 'APPLICATION_JSON',
        requestBody: groovy.json.JsonOutput.toJson(body)
    )
}
```

---

## 四、通知闭环设计

### 4.1 通知时机

```
┌─────────────────────────────────────────────────────────────┐
│                    钉钉群通知                                │
├─────────────────────────────────────────────────────────────┤
│  ✅ 构建成功 → ⏳ 待审批 → ✅ 部署成功                       │
│  ❌ 构建失败                ❌ 部署失败                      │
│                            ❌ 审批拒绝                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 待审批通知示例

```markdown
### ⏳ 待审批

**流水线**: my-frontend-app
**环境**: 🚀 生产环境
**分支**: main
**构建号**: #42
**镜像**: harbor.example.com/proj/app:main-abc123
**时间**: 2024-01-01 12:00:00

---
✅ [点击进行审批](http://platform.example.com/#/cicd/pipeline/15)

🛠 [查看 Jenkins 构建日志](http://jenkins.example.com:8080/job/my-frontend-app/42/console)
```

### 4.3 部署成功通知示例

```markdown
### ✅ 部署成功

**流水线**: my-frontend-app
**环境**: 🚀 生产环境
**命名空间**: production
**工作负载**: Deployment/my-app
**镜像**: harbor.example.com/proj/app:main-abc123
**时间**: 2024-01-01 12:05:00

---
🔗 [查看流水线详情](http://platform.example.com/#/cicd/pipeline/15)
```

---

## 五、流水线配置选项

| 选项 | 类型 | 说明 |
|------|------|------|
| `auto_deploy` | bool | 是否自动部署（构建成功后） |
| `require_approval` | bool | 是否需要人工审批 |
| `target_cluster_id` | int64 | 目标集群ID |
| `target_namespace` | string | 目标命名空间 |
| `target_workload_kind` | string | 工作负载类型 (Deployment/StatefulSet/DaemonSet) |
| `target_workload_name` | string | 工作负载名称 |
| `target_container` | string | 容器名称 |
| `deploy_env` | string | 部署环境 (dev/staging/prod) |

---

## 六、技术亮点总结

| 特性 | 实现方式 | 价值 |
|------|----------|------|
| **阶段化执行** | 6种阶段类型独立记录状态和日志 | 精细化追踪，问题定位快 |
| **审批可配置** | 流水线级别可开关 | 灵活适配不同环境需求 |
| **审批记录** | 记录审批人、时间、意见 | 满足审计合规要求 |
| **审批后自动部署** | 审批通过自动激活 deploy 阶段 | 减少人工操作，提升效率 |
| **HMAC 签名** | Jenkins 回调签名验证 | 防止伪造回调，安全可靠 |
| **钉钉即时通知** | 构建/审批/部署实时推送 | 团队实时感知发布状态 |
| **平台内嵌部署** | 部署在平台侧执行 | 支持多集群，灵活选择 |
| **幂等回调** | job_name + build_number 唯一键 | 防止重复处理 |

---

## 七、相关代码文件

| 文件路径 | 说明 |
|----------|------|
| `internal/app/models/cicd_pipeline.go` | 流水线/阶段数据模型 |
| `internal/app/dao/cicd_pipeline.go` | 数据访问层 |
| `internal/app/services/cicd_stage.go` | 阶段业务逻辑（含审批） |
| `internal/app/services/cicd_environment.go` | 环境/审批检查逻辑 |
| `internal/app/services/cicd_notify.go` | 钉钉通知服务 |
| `internal/app/controllers/api/v1/cicd/stage_controller.go` | 阶段控制器 |
| `internal/app/routers/kube_cicd/cicd_router.go` | 路由注册 |
| `k8s-web/src/views/cicd/PipelineDetail.vue` | 前端阶段展示/审批交互 |
| `configs/jenkins-templates/*.groovy` | Jenkins 流水线模板 |

---

## 八、面试回答要点

1. **为什么要 CI/CD 解耦？**
   - Jenkins 专注构建，平台专注部署和审批
   - 生产环境部署需要人工卡点，防止误发布
   - 部署目标可灵活选择（多集群支持）

2. **审批机制如何保证安全？**
   - 生产环境强制审批
   - 审批记录完整（who/when/why），满足审计
   - HMAC 签名防止回调伪造

3. **如何实现实时状态更新？**
   - Jenkins 每个阶段开始/结束都回调平台
   - 前端轮询 + 状态推送，实时展示进度

4. **与 Rancher/KubeSphere 的区别？**
   - 更轻量，专注于多集群权限管控场景
   - 审批流程可配置，适配不同团队需求
   - 与 Jenkins 深度集成，复用现有 CI 能力
