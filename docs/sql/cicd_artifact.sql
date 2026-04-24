-- =====================================================
-- 制品库表（CI/CD 构建产物管理）
-- 版本: 1.0.0
-- 说明: 存储构建阶段产出的制品（JAR/Binary/Dist 等），与镜像分离
-- =====================================================
USE `k8s-platform`;

CREATE TABLE IF NOT EXISTS `cicd_artifact` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `pipeline_id` bigint DEFAULT NULL COMMENT '关联流水线ID',
  `run_id` bigint DEFAULT NULL COMMENT '关联运行记录ID',
  `build_number` int DEFAULT 0 COMMENT 'Jenkins构建号',

  -- 制品基本信息
  `name` varchar(200) NOT NULL DEFAULT '' COMMENT '制品名称（如 order-service-1.0.0.jar）',
  `artifact_type` varchar(20) NOT NULL DEFAULT '' COMMENT '制品类型：jar/war/binary/dist/wheel/image/archive',
  `version` varchar(100) NOT NULL DEFAULT '' COMMENT '版本号',
  `language_type` varchar(20) NOT NULL DEFAULT '' COMMENT '语言类型：go/java/frontend/python',

  -- 存储信息
  `file_path` varchar(500) NOT NULL DEFAULT '' COMMENT '文件存储路径',
  `file_size` bigint NOT NULL DEFAULT 0 COMMENT '文件大小（字节）',
  `sha256` varchar(64) NOT NULL DEFAULT '' COMMENT 'SHA256校验和',
  `storage_type` varchar(20) NOT NULL DEFAULT 'local' COMMENT '存储类型：local/s3/oss',

  -- Git 信息（构建来源追溯）
  `git_repo` varchar(500) NOT NULL DEFAULT '' COMMENT 'Git仓库地址',
  `git_branch` varchar(100) NOT NULL DEFAULT '' COMMENT 'Git分支',
  `git_commit` varchar(40) NOT NULL DEFAULT '' COMMENT 'Git Commit SHA',

  -- 镜像信息（如果制品已打包为镜像）
  `image_repo` varchar(500) NOT NULL DEFAULT '' COMMENT '镜像仓库地址',
  `image_tag` varchar(200) NOT NULL DEFAULT '' COMMENT '镜像标签',
  `image_digest` varchar(100) NOT NULL DEFAULT '' COMMENT '镜像摘要',

  -- 构建元数据
  `build_duration` int NOT NULL DEFAULT 0 COMMENT '构建耗时（秒）',
  `build_log` text COMMENT '构建摘要日志',
  `metadata` json DEFAULT NULL COMMENT '扩展元数据',

  -- 状态
  `status` varchar(20) NOT NULL DEFAULT 'ready' COMMENT '状态：uploading/ready/expired/deleted',
  `download_count` int NOT NULL DEFAULT 0 COMMENT '下载次数',

  -- 元数据
  `created_user_id` bigint NOT NULL DEFAULT 0 COMMENT '创建人',
  `created_at` bigint unsigned NOT NULL DEFAULT 0,
  `modified_at` bigint unsigned NOT NULL DEFAULT 0,
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0,
  `is_del` tinyint unsigned NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_pipeline_id` (`pipeline_id`),
  KEY `idx_run_id` (`run_id`),
  KEY `idx_artifact_type` (`artifact_type`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CI/CD 制品库表';
