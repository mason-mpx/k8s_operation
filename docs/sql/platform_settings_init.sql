-- ============================================================
-- K8s Operation Platform - 平台系统设置表初始化脚本
-- 数据库: k8s-platform (MySQL 8.0+)
-- 创建时间: 2026-03-04
-- 说明: 
--   1. 此脚本用于初始化 platform_settings 表
--   2. 后端启动时会自动执行 AutoMigrate，也可手动执行此脚本
--   3. 执行方式: mysql -u root -p k8s-platform < platform_settings_init.sql
-- ============================================================

-- 使用数据库
USE `k8s-platform`;

-- ============================================================
-- 1. 创建表结构
-- ============================================================
CREATE TABLE IF NOT EXISTS `platform_settings` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `category`    VARCHAR(50)     NOT NULL COMMENT '分类: basic, security, alert, notification',
    `key`         VARCHAR(100)    NOT NULL COMMENT '配置键',
    `value`       TEXT            NULL COMMENT '配置值',
    `value_type`  VARCHAR(20)     DEFAULT 'string' COMMENT '值类型: string, int, bool, json',
    `label`       VARCHAR(100)    NULL COMMENT '显示名称',
    `desc`        VARCHAR(500)    NULL COMMENT '配置描述',
    `created_at`  INT UNSIGNED    NULL COMMENT '创建时间(Unix时间戳)',
    `modified_at` INT UNSIGNED    NULL COMMENT '修改时间(Unix时间戳)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_category_key` (`category`, `key`),
    INDEX `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='平台系统设置表';

-- ============================================================
-- 2. 初始化默认数据（使用 INSERT IGNORE 避免重复插入）
-- ============================================================

-- 清空旧数据（可选，谨慎使用）
-- TRUNCATE TABLE `platform_settings`;

-- 获取当前 Unix 时间戳
SET @now = UNIX_TIMESTAMP();

-- ------------------------------------------------------------
-- 2.1 基础设置 (basic)
-- ------------------------------------------------------------
INSERT IGNORE INTO `platform_settings` (`category`, `key`, `value`, `value_type`, `label`, `desc`, `created_at`, `modified_at`) VALUES
('basic', 'default_page', '/clusters', 'string', '默认进入页', '用户登录后默认跳转的页面', @now, @now),
('basic', 'default_cluster', 'auto', 'string', '默认集群', '进入集群相关页面时的默认选择 (auto=上次使用, first=第一个)', @now, @now),
('basic', 'language', 'zh-CN', 'string', '界面语言', '平台显示语言 (zh-CN, en-US)', @now, @now),
('basic', 'timezone', 'Asia/Shanghai', 'string', '时区设置', '影响日志和告警的时间显示', @now, @now);

-- ------------------------------------------------------------
-- 2.2 安全设置 (security)
-- ------------------------------------------------------------
INSERT IGNORE INTO `platform_settings` (`category`, `key`, `value`, `value_type`, `label`, `desc`, `created_at`, `modified_at`) VALUES
('security', 'session_timeout', '120', 'int', '会话超时', '用户无操作后自动登出的时间（分钟）', @now, @now),
('security', 'enable_2fa', 'false', 'bool', '双因素认证', '强制用户使用2FA登录', @now, @now),
('security', 'password_policy', 'medium', 'string', '密码强度要求', '密码复杂度规则 (low, medium, high)', @now, @now),
('security', 'audit_retention', '30', 'int', '审计日志保留', '审计日志的保留时间（天）', @now, @now);

-- ------------------------------------------------------------
-- 2.3 告警设置 (alert)
-- ------------------------------------------------------------
INSERT IGNORE INTO `platform_settings` (`category`, `key`, `value`, `value_type`, `label`, `desc`, `created_at`, `modified_at`) VALUES
('alert', 'cpu_threshold', '80', 'int', 'CPU使用率告警', '超过阈值时触发告警 (%)', @now, @now),
('alert', 'mem_threshold', '80', 'int', '内存使用率告警', '超过阈值时触发告警 (%)', @now, @now),
('alert', 'disk_threshold', '85', 'int', '磁盘使用率告警', '超过阈值时触发告警 (%)', @now, @now),
('alert', 'alert_silence', '15', 'int', '告警静默期', '相同告警的重复通知间隔（分钟）', @now, @now);

-- ------------------------------------------------------------
-- 2.4 通知设置 (notification)
-- 注意: 敏感信息（如 Webhook URL、SMTP 密码）存放在 config.yaml，不存数据库
-- ------------------------------------------------------------
INSERT IGNORE INTO `platform_settings` (`category`, `key`, `value`, `value_type`, `label`, `desc`, `created_at`, `modified_at`) VALUES
('notification', 'enable_email', 'false', 'bool', '邮件通知', '通过邮件发送告警通知', @now, @now),
('notification', 'smtp_server', '', 'string', 'SMTP服务器', '邮件服务器地址（敏感信息建议放 config.yaml）', @now, @now),
('notification', 'enable_dingtalk', 'false', 'bool', '钉钉通知', '通过钉钉机器人推送告警', @now, @now),
('notification', 'dingtalk_webhook', '', 'string', '钉钉Webhook', '钉钉机器人Webhook地址（敏感信息建议放 config.yaml）', @now, @now),
('notification', 'enable_webhook', 'false', 'bool', 'Webhook通知', '发送到自定义Webhook端点', @now, @now),
('notification', 'webhook_url', '', 'string', 'Webhook URL', '自定义Webhook地址（敏感信息建议放 config.yaml）', @now, @now);

-- ============================================================
-- 3. 验证数据
-- ============================================================
SELECT 
    category AS '分类',
    COUNT(*) AS '配置项数量'
FROM `platform_settings`
GROUP BY category
ORDER BY FIELD(category, 'basic', 'security', 'alert', 'notification');

-- 查看所有配置
SELECT 
    id,
    category AS '分类',
    `key` AS '配置键',
    `value` AS '配置值',
    label AS '显示名称'
FROM `platform_settings`
ORDER BY category, id;

-- ============================================================
-- 4. 常用维护操作（注释状态，按需执行）
-- ============================================================

-- 重置所有设置为默认值
-- UPDATE `platform_settings` SET 
--     `value` = CASE 
--         WHEN `key` = 'default_page' THEN '/clusters'
--         WHEN `key` = 'default_cluster' THEN 'auto'
--         WHEN `key` = 'language' THEN 'zh-CN'
--         WHEN `key` = 'timezone' THEN 'Asia/Shanghai'
--         WHEN `key` = 'session_timeout' THEN '120'
--         WHEN `key` = 'enable_2fa' THEN 'false'
--         WHEN `key` = 'password_policy' THEN 'medium'
--         WHEN `key` = 'audit_retention' THEN '30'
--         WHEN `key` = 'cpu_threshold' THEN '80'
--         WHEN `key` = 'mem_threshold' THEN '80'
--         WHEN `key` = 'disk_threshold' THEN '85'
--         WHEN `key` = 'alert_silence' THEN '15'
--         WHEN `key` = 'enable_email' THEN 'false'
--         WHEN `key` = 'enable_dingtalk' THEN 'false'
--         WHEN `key` = 'enable_webhook' THEN 'false'
--         ELSE `value`
--     END,
--     `modified_at` = UNIX_TIMESTAMP()
-- WHERE 1=1;

-- 删除所有配置（危险操作）
-- DELETE FROM `platform_settings`;

-- 删除表（危险操作）
-- DROP TABLE IF EXISTS `platform_settings`;
