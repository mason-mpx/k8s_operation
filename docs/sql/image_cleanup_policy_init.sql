-- ============================================
-- 镜像清理策略表
-- 支持按天数自动清理过期镜像
-- ============================================

-- 创建镜像清理策略表
CREATE TABLE IF NOT EXISTS `image_cleanup_policy` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `registry_id` BIGINT NOT NULL COMMENT '关联的镜像仓库ID',
    `name` VARCHAR(100) NOT NULL COMMENT '策略名称',
    `enabled` TINYINT(1) DEFAULT 1 COMMENT '是否启用: 0-禁用, 1-启用',
    `repository_pattern` VARCHAR(200) DEFAULT '*' COMMENT '镜像仓库匹配模式（支持通配符）',
    `tag_pattern` VARCHAR(200) DEFAULT '*' COMMENT '标签匹配模式（支持通配符）',
    `keep_last_count` INT DEFAULT 5 COMMENT '保留最近N个标签',
    `keep_days` INT DEFAULT 30 COMMENT '保留最近N天的镜像',
    `cron_expression` VARCHAR(50) DEFAULT '0 2 * * *' COMMENT 'Cron表达式（默认每天凌晨2点）',
    `last_run_at` BIGINT DEFAULT 0 COMMENT '上次执行时间',
    `last_run_result` VARCHAR(500) DEFAULT '' COMMENT '上次执行结果',
    `deleted_count` BIGINT DEFAULT 0 COMMENT '累计删除镜像数',
    `description` VARCHAR(500) DEFAULT '' COMMENT '策略描述',
    `created_by` BIGINT DEFAULT 0 COMMENT '创建人ID',
    `created_at` BIGINT DEFAULT 0 COMMENT '创建时间（Unix时间戳）',
    `modified_at` BIGINT DEFAULT 0 COMMENT '更新时间（Unix时间戳）',
    `is_del` TINYINT(1) DEFAULT 0 COMMENT '软删除标记: 0-正常, 1-已删除',
    PRIMARY KEY (`id`),
    INDEX `idx_registry_id` (`registry_id`),
    INDEX `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像清理策略表';

-- 创建清理任务日志表
CREATE TABLE IF NOT EXISTS `image_cleanup_log` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `policy_id` BIGINT NOT NULL COMMENT '清理策略ID',
    `registry_id` BIGINT NOT NULL COMMENT '镜像仓库ID',
    `start_time` BIGINT NOT NULL COMMENT '开始时间',
    `end_time` BIGINT DEFAULT 0 COMMENT '结束时间',
    `status` VARCHAR(20) DEFAULT 'running' COMMENT '状态: running, success, failed',
    `scanned_count` INT DEFAULT 0 COMMENT '扫描镜像数',
    `deleted_count` INT DEFAULT 0 COMMENT '删除镜像数',
    `freed_size` BIGINT DEFAULT 0 COMMENT '释放空间（字节）',
    `error_message` TEXT COMMENT '错误信息',
    `details` JSON COMMENT '详细删除记录',
    PRIMARY KEY (`id`),
    INDEX `idx_policy_id` (`policy_id`),
    INDEX `idx_start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='镜像清理日志表';

-- 插入示例清理策略
INSERT INTO `image_cleanup_policy` 
(`registry_id`, `name`, `enabled`, `repository_pattern`, `tag_pattern`, `keep_last_count`, `keep_days`, `cron_expression`, `description`, `created_at`, `modified_at`) 
VALUES
(1, '开发镜像自动清理', 1, 'dev/*', '*', 3, 7, '0 3 * * *', '清理开发环境7天前的镜像，保留最近3个版本', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(1, '测试镜像自动清理', 1, 'test/*', '*', 5, 14, '0 3 * * 0', '每周日清理测试环境14天前的镜像', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 验证数据
SELECT id, name, registry_id, enabled, keep_days, keep_last_count FROM image_cleanup_policy WHERE is_del = 0;
