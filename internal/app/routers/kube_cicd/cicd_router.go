package kube_cicd

import (
	"github.com/gin-gonic/gin"
	"k8soperation/internal/app/controllers/api/v1/cicd"
)

type CicdRouter struct {
	releaseCtrl     *cicd.CicdReleaseController
	pipelineCtrl    *cicd.PipelineController
	gitCtrl         *cicd.GitController
	environmentCtrl *cicd.EnvironmentController
	approvalCtrl    *cicd.ApprovalController
	stageCtrl       *cicd.StageController
	templateCtrl    *cicd.TemplateController
	resourceCtrl    *cicd.ResourceController
}

func NewCicdRouter() *CicdRouter {
	return &CicdRouter{
		releaseCtrl:     cicd.NewCicdReleaseController(),
		pipelineCtrl:    cicd.NewPipelineController(),
		gitCtrl:         cicd.NewGitController(),
		environmentCtrl: cicd.NewEnvironmentController(),
		approvalCtrl:    cicd.NewApprovalController(),
		stageCtrl:       cicd.NewStageController(),
		templateCtrl:    cicd.NewTemplateController(),
		resourceCtrl:    cicd.NewResourceController(),
	}
}

func (r *CicdRouter) Inject(rg *gin.RouterGroup) {
	// ==================== 流水线管理 ====================
	// /api/v1/k8s/cicd/pipeline/...
	pipeline := rg.Group("/pipeline")
	{
		pipeline.GET("/list", r.pipelineCtrl.List)         // 获取流水线列表
		pipeline.GET("/detail", r.pipelineCtrl.Detail)     // 获取流水线详情
		pipeline.POST("/create", r.pipelineCtrl.Create)    // 创建流水线
		pipeline.POST("/update", r.pipelineCtrl.Update)    // 更新流水线
		pipeline.POST("/delete", r.pipelineCtrl.Delete)    // 删除流水线
		pipeline.POST("/run", r.pipelineCtrl.Run)          // 运行流水线（触发 Jenkins 构建）
		pipeline.POST("/stop", r.pipelineCtrl.Stop)        // 停止流水线
		pipeline.POST("/batch-run", r.pipelineCtrl.BatchRun)   // 批量运行流水线
		pipeline.POST("/batch-stop", r.pipelineCtrl.BatchStop) // 批量停止流水线
		pipeline.GET("/logs", r.pipelineCtrl.Logs)         // 获取构建日志
		pipeline.GET("/status", r.pipelineCtrl.Status)     // 获取实时状态
		pipeline.GET("/stages", r.pipelineCtrl.Stages)     // 获取阶段数据（Jenkins Pipeline）
		pipeline.GET("/history", r.pipelineCtrl.History)   // 获取运行历史
		// callback 已移至 cicd_callback_router.go（公开接口，跳过 JWT）
	}

	// ==================== 发布单管理 ====================
	// /api/v1/k8s/cicd/release/...
	release := rg.Group("/release")
	{
		release.POST("/create", r.releaseCtrl.Create)     // 创建发布单
		release.GET("/detail", r.releaseCtrl.Detail)      // 发布单详情
		release.GET("/list", r.releaseCtrl.List)          // 发布单列表
		release.POST("/cancel", r.releaseCtrl.Cancel)     // 取消发布（智能判断回滚/取消）
		release.POST("/rollback", r.releaseCtrl.Rollback) // 回滚发布
		release.POST("/retry", r.releaseCtrl.Retry)       // 重试发布
		release.GET("/tasks", r.releaseCtrl.Tasks)        // 获取发布单下的任务列表
	}

	// ==================== 回调接口 ====================
	// 回调接口已移至 cicd_callback_router.go（公开接口，跳过JWT）

	// ==================== Git 仓库操作 ====================
	// /api/v1/k8s/cicd/git/...
	git := rg.Group("/git")
	{
		git.POST("/branches", r.gitCtrl.GetBranches) // 获取远程分支列表
		git.POST("/validate", r.gitCtrl.ValidateRepo) // 验证仓库连接
	}

	// ==================== 环境管理 ====================
	// /api/v1/k8s/cicd/environment/...
	environment := rg.Group("/environment")
	{
		environment.GET("/list", r.environmentCtrl.List)       // 获取环境列表
		environment.GET("/detail", r.environmentCtrl.Detail)   // 获取环境详情
		environment.POST("/create", r.environmentCtrl.Create)  // 创建环境
		environment.POST("/update", r.environmentCtrl.Update)  // 更新环境
		environment.POST("/delete", r.environmentCtrl.Delete)  // 删除环境
	}

	// ==================== 审批流程 ====================
	// /api/v1/k8s/cicd/approval/...
	approval := rg.Group("/approval")
	{
		approval.GET("/list", r.approvalCtrl.List)       // 获取审批列表
		approval.GET("/detail", r.approvalCtrl.Detail)   // 获取审批详情
		approval.GET("/pending", r.approvalCtrl.Pending) // 获取待审批列表
		approval.POST("/create", r.approvalCtrl.Create)  // 创建审批申请
		approval.POST("/action", r.approvalCtrl.Action)  // 审批操作
	}

	// ==================== 流水线阶段 ====================
	// /api/v1/k8s/cicd/stage/...
	stage := rg.Group("/stage")
	{
		stage.GET("/list", r.stageCtrl.GetStages)        // 获取运行阶段列表
		stage.GET("/logs", r.stageCtrl.GetStageLogs)     // 获取阶段日志
		stage.POST("/approve", r.stageCtrl.ApproveStage) // 审批阶段
		stage.POST("/deploy", r.stageCtrl.DeployStage)   // 执行部署阶段
		stage.POST("/cancel", r.stageCtrl.CancelDeploy)  // 取消部署（智能判断）
		stage.POST("/rollback", r.stageCtrl.RollbackDeploy) // 回滚到指定版本
		stage.GET("/history", r.stageCtrl.GetDeployHistory) // 获取历史版本列表
		// callback 已移至 cicd_callback_router.go（公开接口，跳过JWT）
	}

	// ==================== 流水线模板 ====================
	// /api/v1/k8s/cicd/template/...
	template := rg.Group("/template")
	{
		template.GET("/list", r.templateCtrl.List)       // 获取模板列表
		template.GET("/detail", r.templateCtrl.Detail)   // 获取模板详情
		template.POST("/create", r.templateCtrl.Create)  // 创建模板
		template.POST("/update", r.templateCtrl.Update)  // 更新模板
		template.POST("/delete", r.templateCtrl.Delete)  // 删除模板
	}

	// ==================== 资源配置管理 ====================
	// /api/v1/k8s/cicd/resource/...
	resource := rg.Group("/resource")
	{
		// 资源模板
		resource.GET("/templates", r.resourceCtrl.TemplateList)           // 获取资源模板列表
		resource.GET("/template/default", r.resourceCtrl.TemplateDefault) // 获取默认模板
		resource.GET("/template/:id", r.resourceCtrl.TemplateDetail)      // 获取模板详情
		resource.POST("/template", r.resourceCtrl.TemplateCreate)         // 创建模板
		resource.PUT("/template/:id", r.resourceCtrl.TemplateUpdate)      // 更新模板
		resource.DELETE("/template/:id", r.resourceCtrl.TemplateDelete)   // 删除模板

		// 环境规则
		resource.GET("/rules", r.resourceCtrl.RuleList)     // 获取规则列表
		resource.PUT("/rule/:id", r.resourceCtrl.RuleUpdate) // 更新规则

		// 资源校验
		resource.POST("/validate", r.resourceCtrl.Validate) // 校验资源配置

		// 发布审批
		resource.GET("/approvals", r.resourceCtrl.ApprovalList)              // 审批列表
		resource.GET("/approval/:id", r.resourceCtrl.ApprovalDetail)         // 审批详情
		resource.PUT("/approval/:id/approve", r.resourceCtrl.ApprovalApprove) // 通过审批
		resource.PUT("/approval/:id/reject", r.resourceCtrl.ApprovalReject)   // 拒绝审批
	}
}
