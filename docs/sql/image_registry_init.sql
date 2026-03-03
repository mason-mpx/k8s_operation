-- ============================================
-- 镜像仓库管理表
-- 参考: Rancher, KubeSphere, Kuboard 设计
-- ============================================

-- 创建镜像仓库表
CREATE TABLE IF NOT EXISTS `image_registry` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `name` VARCHAR(100) NOT NULL COMMENT '仓库名称',
    `type` VARCHAR(50) NOT NULL DEFAULT 'docker' COMMENT '仓库类型: docker, harbor, gcr, ecr, acr, quay',
    `url` VARCHAR(500) NOT NULL COMMENT '仓库地址',
    `username` VARCHAR(100) DEFAULT '' COMMENT '用户名',
    `password` VARCHAR(500) DEFAULT '' COMMENT '密码（加密存储）',
    `insecure` TINYINT(1) DEFAULT 0 COMMENT '是否跳过TLS验证: 0-否, 1-是',
    `description` VARCHAR(500) DEFAULT '' COMMENT '描述',
    `is_default` TINYINT(1) DEFAULT 0 COMMENT '是否默认仓库: 0-否, 1-是',
    `status` VARCHAR(50) DEFAULT 'unknown' COMMENT '连接状态: connected, disconnected, unknown',
    `last_check_at` BIGINT DEFAULT 0 COMMENT '最后检测时间（Unix时间戳）',
    `last_error` VARCHAR(500) DEFAULT '' COMMENT '最后错误信息',
    `created_by` BIGINT DEFAULT 0 COMMENT '创建人ID',
    `created_at` BIGINT DEFAULT 0 COMMENT '创建时间（Unix时间戳）',
    `modified_at` BIGINT DEFAULT 0 COMMENT '更新时间（Unix时间戳）',
    `is_del` TINYINT(1) DEFAULT 0 COMMENT '软删除标记: 0-正常, 1-已删除',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `idx_registry_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像仓库配置表';

-- 插入示例数据
INSERT INTO `image_registry` (`name`, `type`, `url`, `username`, `password`, `insecure`, `description`, `is_default`, `status`, `created_at`, `modified_at`) VALUES
('Docker Hub', 'docker', 'https://registry.hub.docker.com', '', '', 0, 'Docker 官方公共仓库', 1, 'connected', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('Harbor 私有仓库', 'harbor', 'https://harbor.example.com', 'admin', '', 1, '企业私有 Harbor 仓库', 0, 'unknown', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('阿里云 ACR', 'acr', 'https://registry.cn-hangzhou.aliyuncs.com', '', '', 0, '阿里云容器镜像服务', 0, 'unknown', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 验证数据
SELECT id, name, type, url, status, is_default FROM image_registry WHERE is_del = 0;
