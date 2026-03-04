-- =====================================================
-- K8s Platform 完整数据库初始化脚本
-- 版本: 2.0.0
-- 日期: 2026-03-04
-- 说明: 一键创建数据库、所有表结构和初始数据
-- 使用: mysql -u root -p123456 < k8s_platform_full_init.sql
-- =====================================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `k8s-platform` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `k8s-platform`;

-- =====================================================
-- 1. 用户表
-- =====================================================
CREATE TABLE IF NOT EXISTS `user` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL DEFAULT '' COMMENT '用户名',
  `password` varchar(255) NOT NULL DEFAULT '' COMMENT '密码(加密)',
  `role` varchar(50) NOT NULL DEFAULT 'user' COMMENT '基础角色(兼容旧版)',
  `email` varchar(191) DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) DEFAULT NULL COMMENT '手机号',
  `status` tinyint(1) NOT NULL DEFAULT 1 COMMENT '状态:1=启用,0=禁用',
  `created_at` int unsigned DEFAULT 0,
  `modified_at` int unsigned DEFAULT 0,
  `deleted_at` int unsigned DEFAULT 0,
  `is_del` tinyint unsigned DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- =====================================================
-- 2. K8s集群表 (含环境字段)
-- =====================================================
CREATE TABLE IF NOT EXISTS `kube_cluster` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `cluster_name` varchar(191) NOT NULL DEFAULT '' COMMENT '集群名称',
  `kube_config` longtext NOT NULL COMMENT 'KubeConfig(加密存储)',
  `cluster_version` varchar(191) NOT NULL DEFAULT '' COMMENT '集群版本',
  `status` tinyint unsigned NOT NULL DEFAULT 2 COMMENT '状态:0=正常,1=异常,2=未检测',
  -- 环境相关字段
  `env_type` varchar(50) DEFAULT 'development' COMMENT '环境类型:development,testing,staging,production',
  `env_display_name` varchar(100) DEFAULT '' COMMENT '环境显示名称',
  `env_level` int DEFAULT 1 COMMENT '环境级别:1-4(开发到生产)',
  `access_mode` varchar(50) DEFAULT 'restricted' COMMENT '访问模式:public,restricted,private',
  `require_approval` tinyint(1) DEFAULT 0 COMMENT '操作是否需要审批',
  `approval_users` json DEFAULT NULL COMMENT '审批人列表',
  `env_color` varchar(20) DEFAULT '' COMMENT '环境颜色标识',
  `env_description` varchar(500) DEFAULT '' COMMENT '环境描述',
  `env_labels` json DEFAULT NULL COMMENT '环境标签',
  `project_ids` json DEFAULT NULL COMMENT '关联项目ID列表',
  -- 时间和状态字段
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  `last_check_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '最后检查时间',
  `last_error` varchar(1024) NOT NULL DEFAULT '' COMMENT '最后错误信息',
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_modified` (`modified_at`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='K8s集群配置表';

-- =====================================================
-- 3. RBAC - 系统角色表
-- =====================================================
CREATE TABLE IF NOT EXISTS `sys_role` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '角色标识(唯一)',
  `display_name` varchar(100) NOT NULL COMMENT '显示名称',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `role_type` varchar(30) NOT NULL DEFAULT 'custom' COMMENT '角色类型:super_admin,cluster_admin,developer,viewer,custom',
  `is_system` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否系统内置',
  `color` varchar(20) DEFAULT '#1890ff' COMMENT '角色颜色标识',
  `icon` varchar(50) DEFAULT 'user' COMMENT '图标',
  `sort_order` int DEFAULT 0 COMMENT '排序',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统角色表';

-- =====================================================
-- 4. RBAC - 系统权限表
-- =====================================================
CREATE TABLE IF NOT EXISTS `sys_permission` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '权限标识(唯一)',
  `display_name` varchar(100) NOT NULL COMMENT '显示名称',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `resource_type` varchar(50) NOT NULL COMMENT '资源类型:cluster,namespace,deployment,pod等',
  `action` varchar(30) NOT NULL COMMENT '操作类型:view,create,update,delete,exec,manage',
  `parent_id` bigint DEFAULT 0 COMMENT '父权限ID',
  `path` varchar(200) DEFAULT '' COMMENT '权限路径(树形展示用)',
  `sort_order` int DEFAULT 0 COMMENT '排序',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统权限定义表';

-- =====================================================
-- 5. RBAC - 角色权限关联表
-- =====================================================
CREATE TABLE IF NOT EXISTS `sys_role_permission` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `permission_id` bigint NOT NULL COMMENT '权限ID',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_role_id` (`role_id`),
  KEY `idx_permission_id` (`permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色权限关联表';

-- =====================================================
-- 6. RBAC - 用户角色关联表
-- =====================================================
CREATE TABLE IF NOT EXISTS `sys_user_role` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `created_by` bigint DEFAULT 0 COMMENT '创建人ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户角色关联表';

-- =====================================================
-- 7. RBAC - 用户集群权限表 (细粒度权限控制)
-- =====================================================
CREATE TABLE IF NOT EXISTS `sys_user_cluster` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `cluster_id` bigint NOT NULL COMMENT '集群ID',
  `role_type` varchar(30) NOT NULL DEFAULT 'viewer' COMMENT '在该集群的角色类型',
  `namespaces` text DEFAULT NULL COMMENT '可访问的命名空间(JSON数组,空表示全部)',
  `can_view` tinyint(1) NOT NULL DEFAULT 1 COMMENT '查看权限',
  `can_create` tinyint(1) NOT NULL DEFAULT 0 COMMENT '创建权限',
  `can_update` tinyint(1) NOT NULL DEFAULT 0 COMMENT '更新权限',
  `can_delete` tinyint(1) NOT NULL DEFAULT 0 COMMENT '删除权限',
  `can_exec` tinyint(1) NOT NULL DEFAULT 0 COMMENT '执行权限(进入容器等)',
  `expire_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '过期时间(0=永不过期)',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `created_by` bigint DEFAULT 0 COMMENT '授权人ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_cluster_id` (`cluster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户集群权限表';

-- =====================================================
-- 8. CI/CD - 流水线表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_pipeline` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `project_id` bigint DEFAULT NULL COMMENT '所属项目ID',
  `name` varchar(191) NOT NULL COMMENT '流水线名称',
  `description` varchar(500) NOT NULL DEFAULT '' COMMENT '描述',
  `git_repo` varchar(500) NOT NULL COMMENT 'Git仓库地址',
  `git_branch` varchar(100) NOT NULL DEFAULT 'main' COMMENT 'Git分支',
  `jenkins_url` varchar(500) NOT NULL DEFAULT '' COMMENT 'Jenkins服务地址',
  `jenkins_job` varchar(191) NOT NULL COMMENT 'Jenkins Job名称',
  `jenkins_credential_id` varchar(191) NOT NULL DEFAULT '' COMMENT 'Jenkins凭证ID',
  -- 部署配置
  `auto_deploy` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否自动部署',
  `target_cluster_id` bigint DEFAULT NULL COMMENT '目标集群ID',
  `target_namespace` varchar(100) DEFAULT '' COMMENT '目标命名空间',
  `target_workload_kind` varchar(50) DEFAULT '' COMMENT '工作负载类型',
  `target_workload_name` varchar(200) DEFAULT '' COMMENT '工作负载名称',
  `target_container` varchar(100) DEFAULT '' COMMENT '目标容器名称',
  `deploy_env` varchar(20) DEFAULT 'dev' COMMENT '部署环境',
  `require_approval` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否需要审批',
  -- 最新部署信息
  `last_deploy_image` varchar(500) DEFAULT '' COMMENT '最新部署镜像',
  `last_deploy_digest` varchar(100) DEFAULT '' COMMENT '镜像摘要',
  `last_deploy_time` bigint DEFAULT NULL COMMENT '最新部署时间',
  `last_deploy_status` varchar(32) DEFAULT '' COMMENT '最新部署状态',
  `last_deploy_version` varchar(100) DEFAULT '' COMMENT '最新部署版本',
  -- 运行状态
  `status` varchar(50) NOT NULL DEFAULT 'idle' COMMENT '状态:idle,running,disabled',
  `last_run_status` varchar(50) NOT NULL DEFAULT '' COMMENT '最后运行状态',
  `last_run_time` bigint unsigned NOT NULL DEFAULT 0 COMMENT '最后运行时间',
  `last_build_number` int NOT NULL DEFAULT 0 COMMENT '最后构建号',
  `last_build_url` varchar(500) NOT NULL DEFAULT '' COMMENT '最后构建URL',
  -- JSON配置
  `env_vars` json DEFAULT NULL COMMENT '环境变量',
  `deploy_config` json DEFAULT NULL COMMENT '部署配置',
  `stages` json DEFAULT NULL COMMENT '阶段配置',
  -- 元数据
  `created_user_id` bigint NOT NULL DEFAULT 0 COMMENT '创建人',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_name` (`name`),
  KEY `idx_project_id` (`project_id`),
  KEY `idx_jenkins_job` (`jenkins_job`),
  KEY `idx_status` (`status`),
  KEY `idx_auto_deploy` (`auto_deploy`),
  KEY `idx_target_cluster` (`target_cluster_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD流水线表';

-- =====================================================
-- 9. CI/CD - 流水线运行记录表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_pipeline_run` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `pipeline_id` bigint NOT NULL COMMENT '流水线ID',
  `build_number` int NOT NULL DEFAULT 0 COMMENT '构建号',
  `status` varchar(50) NOT NULL DEFAULT 'pending' COMMENT '状态:pending,running,success,failed,aborted',
  `trigger_type` varchar(50) NOT NULL DEFAULT 'manual' COMMENT '触发类型:manual,webhook,scheduled',
  `trigger_user_id` bigint NOT NULL DEFAULT 0 COMMENT '触发人ID',
  `git_commit` varchar(100) NOT NULL DEFAULT '' COMMENT 'Git Commit',
  `git_branch` varchar(100) NOT NULL DEFAULT '' COMMENT 'Git分支',
  `git_commit_message` varchar(500) NOT NULL DEFAULT '' COMMENT '提交消息',
  `jenkins_build_url` varchar(500) NOT NULL DEFAULT '' COMMENT 'Jenkins构建URL',
  `duration_sec` int NOT NULL DEFAULT 0 COMMENT '执行时长(秒)',
  `console_log` longtext DEFAULT NULL COMMENT '控制台日志',
  `stages_result` json DEFAULT NULL COMMENT '阶段结果',
  `started_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '开始时间',
  `finished_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '结束时间',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `error_message` text DEFAULT NULL COMMENT '错误信息',
  `image_url` varchar(500) DEFAULT '' COMMENT '构建镜像地址',
  `image_digest` varchar(100) DEFAULT '' COMMENT '镜像摘要',
  `callback_received` tinyint(1) DEFAULT 0 COMMENT '是否收到回调',
  PRIMARY KEY (`id`),
  KEY `idx_pipeline_id` (`pipeline_id`),
  KEY `idx_build_number` (`build_number`),
  KEY `idx_status` (`status`),
  KEY `idx_started_at` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='流水线运行记录表';

-- =====================================================
-- 10. CI/CD - 流水线阶段执行记录表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_pipeline_stage` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `run_id` bigint NOT NULL COMMENT '运行记录ID',
  `pipeline_id` bigint NOT NULL COMMENT '流水线ID',
  `stage_order` int NOT NULL DEFAULT 0 COMMENT '阶段顺序',
  `stage_type` varchar(32) NOT NULL COMMENT '阶段类型:checkout,build,test,push,approval,deploy',
  `stage_name` varchar(100) NOT NULL COMMENT '阶段名称',
  `status` varchar(32) NOT NULL DEFAULT 'pending' COMMENT '状态',
  `started_at` bigint DEFAULT NULL COMMENT '开始时间',
  `finished_at` bigint DEFAULT NULL COMMENT '结束时间',
  `duration_sec` int DEFAULT 0 COMMENT '执行时长',
  `logs` longtext DEFAULT NULL COMMENT '阶段日志',
  `jenkins_stage_id` varchar(100) DEFAULT NULL COMMENT 'Jenkins阶段ID',
  -- 审批信息
  `approval_user_id` bigint DEFAULT NULL COMMENT '审批人ID',
  `approval_comment` text DEFAULT NULL COMMENT '审批评论',
  `approval_decision` varchar(32) DEFAULT NULL COMMENT '审批决定:approved,rejected',
  -- 部署信息
  `deploy_cluster_id` bigint DEFAULT NULL COMMENT '部署集群ID',
  `deploy_namespace` varchar(100) DEFAULT NULL COMMENT '部署命名空间',
  `deploy_workload_kind` varchar(50) DEFAULT NULL COMMENT '工作负载类型',
  `deploy_workload_name` varchar(100) DEFAULT NULL COMMENT '工作负载名称',
  `deploy_container` varchar(100) DEFAULT NULL COMMENT '容器名称',
  `deploy_image` varchar(500) DEFAULT NULL COMMENT '部署镜像',
  `deploy_old_image` varchar(500) DEFAULT NULL COMMENT '旧镜像',
  `deploy_replicas` int DEFAULT NULL COMMENT '副本数',
  `error_message` text DEFAULT NULL COMMENT '错误信息',
  `created_at` bigint NOT NULL,
  `modified_at` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_run_id` (`run_id`),
  KEY `idx_pipeline_id` (`pipeline_id`),
  KEY `idx_stage_type` (`stage_type`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='流水线阶段执行记录表';

-- =====================================================
-- 11. CI/CD - 环境配置表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_environment` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '环境标识:dev,staging,prod',
  `display_name` varchar(100) NOT NULL COMMENT '显示名称',
  `description` varchar(500) NOT NULL DEFAULT '' COMMENT '描述',
  `cluster_id` bigint NOT NULL COMMENT '关联集群ID',
  `namespace` varchar(100) NOT NULL DEFAULT '' COMMENT '默认命名空间',
  `color` varchar(20) NOT NULL DEFAULT '#1890ff' COMMENT '环境颜色',
  `sort_order` int NOT NULL DEFAULT 0 COMMENT '排序',
  `require_approval` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否需要审批',
  `approval_users` json DEFAULT NULL COMMENT '审批人列表',
  `created_user_id` bigint NOT NULL DEFAULT 0 COMMENT '创建人',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_name` (`name`),
  KEY `idx_cluster_id` (`cluster_id`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD环境配置表';

-- =====================================================
-- 12. CI/CD - 审批记录表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_approval` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `pipeline_id` bigint NOT NULL COMMENT '流水线ID',
  `pipeline_run_id` bigint NOT NULL COMMENT '运行记录ID',
  `release_id` bigint NOT NULL DEFAULT 0 COMMENT '发布单ID',
  `env_name` varchar(50) NOT NULL COMMENT '目标环境',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '状态:pending,approved,rejected,expired',
  `image` varchar(500) NOT NULL DEFAULT '' COMMENT '待部署镜像',
  `image_digest` varchar(100) NOT NULL DEFAULT '' COMMENT '镜像摘要',
  `request_user_id` bigint NOT NULL COMMENT '申请人ID',
  `request_reason` varchar(500) NOT NULL DEFAULT '' COMMENT '申请原因',
  `approve_user_id` bigint NOT NULL DEFAULT 0 COMMENT '审批人ID',
  `approve_reason` varchar(500) NOT NULL DEFAULT '' COMMENT '审批意见',
  `approve_time` bigint unsigned NOT NULL DEFAULT 0 COMMENT '审批时间',
  `expire_time` bigint unsigned NOT NULL DEFAULT 0 COMMENT '过期时间',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pipeline_id` (`pipeline_id`),
  KEY `idx_pipeline_run_id` (`pipeline_run_id`),
  KEY `idx_status` (`status`),
  KEY `idx_request_user_id` (`request_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD审批记录表';

-- =====================================================
-- 13. CI/CD - 发布单表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_release` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app_name` varchar(191) NOT NULL DEFAULT '' COMMENT '应用名称',
  `namespace` varchar(191) NOT NULL DEFAULT 'default' COMMENT '命名空间',
  `workload_kind` varchar(32) NOT NULL DEFAULT 'Deployment' COMMENT '工作负载类型',
  `workload_name` varchar(191) NOT NULL DEFAULT '' COMMENT '工作负载名称',
  `container_name` varchar(191) NOT NULL DEFAULT '' COMMENT '容器名称',
  `strategy` varchar(32) NOT NULL DEFAULT 'rolling' COMMENT '发布策略',
  `timeout_sec` int unsigned NOT NULL DEFAULT 300 COMMENT '超时时间(秒)',
  `concurrency` int unsigned NOT NULL DEFAULT 3 COMMENT '并发数',
  `status` varchar(32) NOT NULL DEFAULT 'Pending' COMMENT '状态',
  `message` varchar(1024) NOT NULL DEFAULT '' COMMENT '消息',
  `created_user_id` bigint NOT NULL DEFAULT 0 COMMENT '创建人',
  `request_id` varchar(64) NOT NULL DEFAULT '' COMMENT '请求ID',
  `build_id` bigint NOT NULL DEFAULT 0 COMMENT '关联构建ID',
  `image_repo` varchar(512) NOT NULL DEFAULT '' COMMENT '镜像仓库',
  `image_tag` varchar(191) NOT NULL DEFAULT '' COMMENT '镜像标签',
  `image_digest` varchar(255) DEFAULT NULL COMMENT '镜像摘要',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_request_id` (`request_id`),
  KEY `idx_app_name` (`app_name`),
  KEY `idx_status` (`status`),
  KEY `idx_build_id` (`build_id`),
  KEY `idx_modified_at` (`modified_at`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD发布单表';

-- =====================================================
-- 14. CI/CD - 发布阶段表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_release_stage` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `release_id` bigint NOT NULL DEFAULT 0 COMMENT '发布单ID',
  `stage_name` varchar(64) NOT NULL DEFAULT '' COMMENT '阶段名称',
  `stage_order` int NOT NULL DEFAULT 0 COMMENT '阶段顺序',
  `status` varchar(32) NOT NULL DEFAULT 'pending' COMMENT '状态',
  `message` varchar(1024) NOT NULL DEFAULT '' COMMENT '消息',
  `logs` text DEFAULT NULL COMMENT '日志',
  `start_time` bigint unsigned NOT NULL DEFAULT 0 COMMENT '开始时间',
  `end_time` bigint unsigned NOT NULL DEFAULT 0 COMMENT '结束时间',
  `duration` bigint NOT NULL DEFAULT 0 COMMENT '持续时间',
  `build_number` varchar(64) NOT NULL DEFAULT '' COMMENT '构建号',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_release_id` (`release_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD发布阶段表';

-- =====================================================
-- 15. CI/CD - 发布任务表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_release_task` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `release_id` bigint NOT NULL COMMENT '发布单ID',
  `cluster_id` bigint NOT NULL COMMENT '集群ID',
  `status` varchar(32) NOT NULL DEFAULT 'Pending' COMMENT '状态',
  `message` varchar(2048) NOT NULL DEFAULT '' COMMENT '消息',
  `prev_image` varchar(512) NOT NULL DEFAULT '' COMMENT '原镜像',
  `target_image` varchar(512) NOT NULL DEFAULT '' COMMENT '目标镜像',
  `started_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '开始时间',
  `finished_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '结束时间',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_release_id` (`release_id`),
  KEY `idx_cluster_id` (`cluster_id`),
  KEY `idx_status` (`status`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD发布任务表';

-- =====================================================
-- 16. CI/CD - 构建记录表
-- =====================================================
CREATE TABLE IF NOT EXISTS `cicd_build` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app_name` varchar(191) NOT NULL DEFAULT '' COMMENT '应用名称',
  `git_url` varchar(500) NOT NULL DEFAULT '' COMMENT 'Git URL',
  `git_branch` varchar(100) NOT NULL DEFAULT '' COMMENT 'Git分支',
  `git_commit` varchar(100) NOT NULL DEFAULT '' COMMENT 'Git Commit',
  `jenkins_job` varchar(191) NOT NULL DEFAULT '' COMMENT 'Jenkins Job',
  `jenkins_queue_id` bigint NOT NULL DEFAULT 0 COMMENT 'Jenkins队列ID',
  `jenkins_build_number` int NOT NULL DEFAULT 0 COMMENT 'Jenkins构建号',
  `jenkins_build_url` varchar(500) NOT NULL DEFAULT '' COMMENT 'Jenkins构建URL',
  `status` varchar(50) NOT NULL DEFAULT 'pending' COMMENT '状态',
  `message` varchar(1024) NOT NULL DEFAULT '' COMMENT '消息',
  `image_repo` varchar(500) NOT NULL DEFAULT '' COMMENT '镜像仓库',
  `image_tag` varchar(191) NOT NULL DEFAULT '' COMMENT '镜像标签',
  `image_digest` varchar(191) DEFAULT NULL COMMENT '镜像摘要',
  `sbom_ref` varchar(500) NOT NULL DEFAULT '' COMMENT 'SBOM引用',
  `sign_ref` varchar(500) NOT NULL DEFAULT '' COMMENT '签名引用',
  `created_user_id` bigint NOT NULL DEFAULT 0 COMMENT '创建人',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_app_name` (`app_name`),
  KEY `idx_jenkins_job` (`jenkins_job`),
  KEY `idx_status` (`status`),
  KEY `idx_is_del` (`is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD构建记录表';

-- =====================================================
-- 17. 镜像仓库配置表
-- =====================================================
CREATE TABLE IF NOT EXISTS `image_registry` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '仓库名称',
  `type` varchar(50) NOT NULL DEFAULT 'docker' COMMENT '类型:docker,harbor,acr,ecr,gcr,quay',
  `url` varchar(500) NOT NULL COMMENT '仓库地址',
  `username` varchar(100) DEFAULT '' COMMENT '用户名',
  `password` varchar(500) DEFAULT '' COMMENT '密码(加密)',
  `access_key_id` varchar(100) DEFAULT '' COMMENT 'AccessKey ID(云厂商)',
  `access_key_secret` varchar(200) DEFAULT '' COMMENT 'AccessKey Secret(加密)',
  `region` varchar(50) DEFAULT '' COMMENT '区域',
  `insecure` tinyint(1) DEFAULT 0 COMMENT '跳过TLS验证',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `is_default` tinyint(1) DEFAULT 0 COMMENT '是否默认仓库',
  `status` varchar(50) DEFAULT 'unknown' COMMENT '连接状态',
  `last_check_at` bigint DEFAULT 0 COMMENT '最后检测时间',
  `last_error` varchar(500) DEFAULT '' COMMENT '最后错误',
  `created_by` bigint DEFAULT 0 COMMENT '创建人',
  `created_at` bigint DEFAULT 0,
  `modified_at` bigint DEFAULT 0,
  `is_del` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_registry_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像仓库配置表';

-- =====================================================
-- 18. 镜像清理策略表
-- =====================================================
CREATE TABLE IF NOT EXISTS `image_cleanup_policy` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `registry_id` bigint NOT NULL COMMENT '仓库ID',
  `name` varchar(100) NOT NULL COMMENT '策略名称',
  `enabled` tinyint(1) DEFAULT 1 COMMENT '是否启用',
  `repository_pattern` varchar(200) DEFAULT '*' COMMENT '仓库匹配模式',
  `tag_pattern` varchar(200) DEFAULT '*' COMMENT '标签匹配模式',
  `keep_last_count` int DEFAULT 5 COMMENT '保留最近N个',
  `keep_days` int DEFAULT 30 COMMENT '保留N天内',
  `cron_expression` varchar(50) DEFAULT '0 2 * * *' COMMENT 'Cron表达式',
  `last_run_at` bigint DEFAULT 0 COMMENT '最后执行时间',
  `last_run_result` varchar(500) DEFAULT '' COMMENT '最后执行结果',
  `deleted_count` bigint DEFAULT 0 COMMENT '累计删除数',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `created_by` bigint DEFAULT 0 COMMENT '创建人',
  `created_at` bigint DEFAULT 0,
  `modified_at` bigint DEFAULT 0,
  `is_del` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_registry_id` (`registry_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像清理策略表';

-- =====================================================
-- 19. 镜像清理日志表
-- =====================================================
CREATE TABLE IF NOT EXISTS `image_cleanup_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `policy_id` bigint NOT NULL COMMENT '策略ID',
  `registry_id` bigint NOT NULL COMMENT '仓库ID',
  `start_time` bigint NOT NULL COMMENT '开始时间',
  `end_time` bigint DEFAULT 0 COMMENT '结束时间',
  `status` varchar(20) DEFAULT 'running' COMMENT '状态',
  `scanned_count` int DEFAULT 0 COMMENT '扫描数',
  `deleted_count` int DEFAULT 0 COMMENT '删除数',
  `freed_size` bigint DEFAULT 0 COMMENT '释放空间(字节)',
  `error_message` text DEFAULT NULL COMMENT '错误信息',
  `details` json DEFAULT NULL COMMENT '详情',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像清理日志表';

-- =====================================================
-- 20. 平台设置表
-- =====================================================
CREATE TABLE IF NOT EXISTS `platform_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `category` varchar(50) NOT NULL COMMENT '分类:basic,security,alert,notification',
  `key` varchar(100) NOT NULL COMMENT '设置键',
  `value` text DEFAULT NULL COMMENT '设置值',
  `value_type` varchar(20) DEFAULT 'string' COMMENT '值类型:string,int,bool,json',
  `label` varchar(100) DEFAULT NULL COMMENT '显示名称',
  `desc` varchar(500) DEFAULT NULL COMMENT '描述',
  `created_at` int unsigned DEFAULT NULL,
  `modified_at` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_category_key` (`category`, `key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='平台设置表';

-- =====================================================
-- 添加缺少的字段 (兼容已有数据库)
-- 注意: 如果字段已存在会报错，可忽略
-- =====================================================

-- image_registry 添加云厂商字段 (新安装无需执行，升级时按需执行)
-- 使用存储过程安全添加字段
DROP PROCEDURE IF EXISTS add_column_if_not_exists;
DELIMITER //
CREATE PROCEDURE add_column_if_not_exists()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='k8s-platform' AND TABLE_NAME='image_registry' AND COLUMN_NAME='access_key_id') THEN
        ALTER TABLE `image_registry` ADD COLUMN `access_key_id` varchar(100) DEFAULT '' COMMENT 'AccessKey ID' AFTER `password`;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='k8s-platform' AND TABLE_NAME='image_registry' AND COLUMN_NAME='access_key_secret') THEN
        ALTER TABLE `image_registry` ADD COLUMN `access_key_secret` varchar(200) DEFAULT '' COMMENT 'AccessKey Secret' AFTER `access_key_id`;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='k8s-platform' AND TABLE_NAME='image_registry' AND COLUMN_NAME='region') THEN
        ALTER TABLE `image_registry` ADD COLUMN `region` varchar(50) DEFAULT '' COMMENT '区域' AFTER `access_key_secret`;
    END IF;
END //
DELIMITER ;
CALL add_column_if_not_exists();
DROP PROCEDURE IF EXISTS add_column_if_not_exists;

-- =====================================================
-- 初始化 RBAC 角色数据
-- =====================================================
INSERT IGNORE INTO `sys_role` (`id`, `name`, `display_name`, `description`, `role_type`, `is_system`, `color`, `icon`, `sort_order`, `created_at`, `modified_at`) VALUES
(1, 'super_admin', '超级管理员', '拥有系统所有权限，可管理所有集群和用户', 'super_admin', 1, '#f5222d', 'crown', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(2, 'cluster_admin', '集群管理员', '可管理指定集群的所有资源', 'cluster_admin', 1, '#fa8c16', 'cluster', 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(3, 'developer', '开发者', '可查看和操作指定命名空间的资源', 'developer', 1, '#1890ff', 'code', 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(4, 'viewer', '只读用户', '只能查看指定资源，无法进行修改操作', 'viewer', 1, '#52c41a', 'eye', 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- =====================================================
-- 初始化系统权限数据
-- =====================================================
INSERT IGNORE INTO `sys_permission` (`id`, `name`, `display_name`, `description`, `resource_type`, `action`, `parent_id`, `path`, `sort_order`, `created_at`, `modified_at`) VALUES
-- 集群权限
(1, 'cluster:view', '查看集群', '查看集群列表和详情', 'cluster', 'view', 0, '/cluster', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(2, 'cluster:create', '创建集群', '添加新的K8s集群', 'cluster', 'create', 0, '/cluster', 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(3, 'cluster:update', '更新集群', '修改集群配置', 'cluster', 'update', 0, '/cluster', 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(4, 'cluster:delete', '删除集群', '删除K8s集群', 'cluster', 'delete', 0, '/cluster', 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 命名空间权限
(5, 'namespace:view', '查看命名空间', '查看命名空间列表', 'namespace', 'view', 0, '/namespace', 5, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(6, 'namespace:create', '创建命名空间', '创建新命名空间', 'namespace', 'create', 0, '/namespace', 6, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(7, 'namespace:delete', '删除命名空间', '删除命名空间', 'namespace', 'delete', 0, '/namespace', 7, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 工作负载权限
(8, 'deployment:view', '查看Deployment', '查看Deployment列表和详情', 'deployment', 'view', 0, '/deployment', 10, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(9, 'deployment:create', '创建Deployment', '创建新的Deployment', 'deployment', 'create', 0, '/deployment', 11, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(10, 'deployment:update', '更新Deployment', '修改Deployment配置、扩缩容', 'deployment', 'update', 0, '/deployment', 12, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(11, 'deployment:delete', '删除Deployment', '删除Deployment', 'deployment', 'delete', 0, '/deployment', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- Pod权限
(12, 'pod:view', '查看Pod', '查看Pod列表、日志', 'pod', 'view', 0, '/pod', 20, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(13, 'pod:delete', '删除Pod', '删除Pod', 'pod', 'delete', 0, '/pod', 21, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(14, 'pod:exec', '进入容器', '执行exec进入容器终端', 'pod', 'exec', 0, '/pod', 22, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- Service权限
(15, 'service:view', '查看Service', '查看Service列表', 'service', 'view', 0, '/service', 30, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(16, 'service:create', '创建Service', '创建新Service', 'service', 'create', 0, '/service', 31, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(17, 'service:update', '更新Service', '修改Service配置', 'service', 'update', 0, '/service', 32, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(18, 'service:delete', '删除Service', '删除Service', 'service', 'delete', 0, '/service', 33, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- ConfigMap/Secret权限
(19, 'configmap:view', '查看ConfigMap', '查看ConfigMap', 'configmap', 'view', 0, '/configmap', 40, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(20, 'configmap:manage', '管理ConfigMap', '创建、修改、删除ConfigMap', 'configmap', 'manage', 0, '/configmap', 41, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(21, 'secret:view', '查看Secret', '查看Secret', 'secret', 'view', 0, '/secret', 42, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(22, 'secret:manage', '管理Secret', '创建、修改、删除Secret', 'secret', 'manage', 0, '/secret', 43, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- CI/CD权限
(23, 'pipeline:view', '查看流水线', '查看CI/CD流水线', 'pipeline', 'view', 0, '/pipeline', 50, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(24, 'pipeline:manage', '管理流水线', '创建、修改、删除、执行流水线', 'pipeline', 'manage', 0, '/pipeline', 51, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 用户权限
(25, 'user:view', '查看用户', '查看用户列表', 'user', 'view', 0, '/user', 60, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(26, 'user:manage', '管理用户', '创建、修改、删除用户，分配角色', 'user', 'manage', 0, '/user', 61, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- =====================================================
-- 初始化角色权限关联 (超级管理员拥有所有权限)
-- =====================================================
INSERT IGNORE INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`)
SELECT 1, id, UNIX_TIMESTAMP() FROM `sys_permission`;

-- 集群管理员权限
INSERT IGNORE INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`)
SELECT 2, id, UNIX_TIMESTAMP() FROM `sys_permission` WHERE id BETWEEN 1 AND 24;

-- 开发者权限
INSERT IGNORE INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`)
SELECT 3, id, UNIX_TIMESTAMP() FROM `sys_permission` WHERE `action` IN ('view', 'create', 'update', 'exec') AND id NOT IN (25, 26);

-- 只读用户权限
INSERT IGNORE INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`)
SELECT 4, id, UNIX_TIMESTAMP() FROM `sys_permission` WHERE `action` = 'view';

-- =====================================================
-- 初始化管理员账户 (admin/admin123)
-- =====================================================
INSERT IGNORE INTO `user` (`id`, `username`, `password`, `role`, `status`, `created_at`, `modified_at`) VALUES
(1, 'admin', '$2a$10$jWcwxJ.3qLlHaXVZ1nL7MeCsSEXGosmaj1dIFoS74WXq5.gJrfChO', 'admin', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 关联admin用户为超级管理员
INSERT IGNORE INTO `sys_user_role` (`user_id`, `role_id`, `created_at`, `created_by`) VALUES
(1, 1, UNIX_TIMESTAMP(), 0);

-- =====================================================
-- 初始化平台设置
-- =====================================================
INSERT IGNORE INTO `platform_settings` (`category`, `key`, `value`, `value_type`, `label`, `desc`, `created_at`, `modified_at`) VALUES
-- 基本设置
('basic', 'default_page', '/clusters', 'string', '默认首页', '登录后默认跳转页面', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('basic', 'default_cluster', 'auto', 'string', '默认集群', '自动选择或指定集群ID', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('basic', 'language', 'zh-CN', 'string', '系统语言', '界面显示语言', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('basic', 'timezone', 'Asia/Shanghai', 'string', '时区', '系统时区设置', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 安全设置
('security', 'session_timeout', '120', 'int', '会话超时', '会话超时时间(分钟)', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('security', 'enable_2fa', 'false', 'bool', '双因素认证', '是否启用双因素认证', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('security', 'password_policy', 'medium', 'string', '密码策略', '密码复杂度要求', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('security', 'audit_retention', '30', 'int', '审计保留', '审计日志保留天数', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 告警设置
('alert', 'cpu_threshold', '80', 'int', 'CPU告警阈值', 'CPU使用率告警阈值(%)', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('alert', 'mem_threshold', '80', 'int', '内存告警阈值', '内存使用率告警阈值(%)', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('alert', 'disk_threshold', '85', 'int', '磁盘告警阈值', '磁盘使用率告警阈值(%)', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('alert', 'alert_silence', '15', 'int', '告警静默', '告警静默时间(分钟)', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 通知设置
('notification', 'enable_email', 'false', 'bool', '邮件通知', '是否启用邮件通知', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('notification', 'smtp_server', '', 'string', 'SMTP服务器', 'SMTP服务器地址', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('notification', 'enable_dingtalk', 'false', 'bool', '钉钉通知', '是否启用钉钉通知', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('notification', 'dingtalk_webhook', '', 'string', '钉钉Webhook', '钉钉机器人Webhook地址', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('notification', 'enable_webhook', 'false', 'bool', 'Webhook通知', '是否启用自定义Webhook', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('notification', 'webhook_url', '', 'string', 'Webhook地址', '自定义Webhook地址', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- =====================================================
-- 示例镜像仓库配置
-- =====================================================
INSERT IGNORE INTO `image_registry` (`name`, `type`, `url`, `description`, `is_default`, `status`, `created_at`, `modified_at`) VALUES
('Docker Hub', 'docker', 'https://registry-1.docker.io', 'Docker Hub 官方仓库', 1, 'unknown', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- =====================================================
-- 完成
-- =====================================================
SELECT '=====================================================';
SELECT 'K8s Platform 数据库初始化完成!';
SELECT '=====================================================';
SELECT CONCAT('表数量: ', COUNT(*)) as info FROM information_schema.tables WHERE table_schema = 'k8s-platform';
SELECT '默认管理员账户: admin / admin123';
SELECT '=====================================================';
