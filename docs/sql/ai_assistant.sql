-- =====================================================
-- AI 助手模块 - 数据库建表 SQL
-- 适用于 MySQL 8.0+
-- =====================================================

-- AI 会话表
CREATE TABLE IF NOT EXISTS `ai_conversations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `user_id` int unsigned NOT NULL COMMENT '关联用户ID',
  `title` varchar(200) NOT NULL DEFAULT '新对话' COMMENT '会话标题',
  `status` tinyint unsigned NOT NULL DEFAULT 1 COMMENT '状态: 1=活跃 2=归档',
  `created_at` int unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `modified_at` int unsigned NOT NULL DEFAULT 0 COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI 会话表';

-- AI 聊天消息表
CREATE TABLE IF NOT EXISTS `ai_messages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `conversation_id` int unsigned NOT NULL COMMENT '关联会话ID',
  `role` varchar(20) NOT NULL COMMENT '角色: system/user/assistant',
  `content` text COMMENT '消息内容',
  `intent_json` text COMMENT '意图识别结果JSON',
  `token_used` int NOT NULL DEFAULT 0 COMMENT 'Token消耗',
  `created_at` int unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_conversation_id` (`conversation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI 聊天消息表';

-- 高危操作审批请求表
CREATE TABLE IF NOT EXISTS `ai_approval_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `conversation_id` int unsigned NOT NULL DEFAULT 0 COMMENT '关联AI会话ID',
  `request_user_id` int unsigned NOT NULL COMMENT '发起人ID',
  `approver_user_id` int unsigned NOT NULL DEFAULT 0 COMMENT '审批人ID',
  `intent` varchar(50) NOT NULL COMMENT '操作意图: delete/drain/scale等',
  `resource` varchar(100) NOT NULL DEFAULT '' COMMENT '资源类型: deployment/namespace/node',
  `resource_name` varchar(200) NOT NULL DEFAULT '' COMMENT '资源名称',
  `namespace` varchar(100) NOT NULL DEFAULT '' COMMENT '命名空间',
  `cluster_id` int unsigned NOT NULL DEFAULT 0 COMMENT '目标集群ID',
  `risk_level` varchar(20) NOT NULL DEFAULT 'medium' COMMENT '风险等级: low/medium/high/critical',
  `operation_json` text COMMENT '完整操作参数JSON',
  `tool_name` varchar(100) NOT NULL DEFAULT '' COMMENT 'Function Calling工具名',
  `tool_args_json` text COMMENT '工具调用参数JSON',
  `tool_call_id` varchar(100) NOT NULL DEFAULT '' COMMENT 'OpenAI tool_call_id',
  `execute_result` text COMMENT '执行结果',
  `executed` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否已执行',
  `summary` varchar(500) NOT NULL DEFAULT '' COMMENT '操作摘要(AI生成)',
  `status` tinyint unsigned NOT NULL DEFAULT 1 COMMENT '审批状态: 1=待审批 2=已通过 3=已拒绝 4=已过期 5=已取消',
  `approve_comment` varchar(500) NOT NULL DEFAULT '' COMMENT '审批备注',
  `expire_at` int unsigned NOT NULL DEFAULT 0 COMMENT '过期时间戳',
  `created_at` int unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `modified_at` int unsigned NOT NULL DEFAULT 0 COMMENT '修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_request_user_id` (`request_user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_conversation_id` (`conversation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='高危操作审批请求表';

-- 审批操作日志表
CREATE TABLE IF NOT EXISTS `ai_approval_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `approval_id` int unsigned NOT NULL COMMENT '关联审批请求ID',
  `user_id` int unsigned NOT NULL COMMENT '操作人ID',
  `action` varchar(50) NOT NULL COMMENT '操作: create/approve/reject/cancel/expire',
  `comment` varchar(500) NOT NULL DEFAULT '' COMMENT '操作说明',
  `created_at` int unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_approval_id` (`approval_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='审批操作日志表';
