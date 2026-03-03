-- ============================================================
-- K8s Platform RBAC 初始化脚本
-- 版本: v1.0
-- 说明: 用于初始化RBAC权限管理相关的表和数据
-- 使用: mysql -u root -p123456 k8s < rbac_init.sql
-- ============================================================

-- ==================== 角色表 ====================
CREATE TABLE IF NOT EXISTS `sys_role` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '角色ID',
  `name` varchar(50) NOT NULL COMMENT '角色标识（唯一）',
  `display_name` varchar(100) NOT NULL COMMENT '显示名称',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `role_type` varchar(30) NOT NULL DEFAULT 'custom' COMMENT '角色类型: super_admin/cluster_admin/developer/viewer/custom',
  `is_system` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否系统内置',
  `color` varchar(20) DEFAULT '#1890ff' COMMENT '角色颜色',
  `icon` varchar(50) DEFAULT 'user' COMMENT '图标',
  `sort_order` int DEFAULT 0 COMMENT '排序',
  `created_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `modified_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '修改时间',
  `deleted_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '删除时间',
  `is_del` tinyint unsigned NOT NULL DEFAULT 0 COMMENT '是否删除: 0-否 1-是',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统角色表';

-- ==================== 权限定义表 ====================
CREATE TABLE IF NOT EXISTS `sys_permission` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '权限ID',
  `name` varchar(100) NOT NULL COMMENT '权限标识（唯一）',
  `display_name` varchar(100) NOT NULL COMMENT '显示名称',
  `description` varchar(500) DEFAULT '' COMMENT '描述',
  `resource_type` varchar(50) NOT NULL COMMENT '资源类型: cluster/namespace/deployment/pod/service等',
  `action` varchar(30) NOT NULL COMMENT '操作类型: view/create/update/delete/exec/manage',
  `parent_id` bigint DEFAULT 0 COMMENT '父权限ID',
  `path` varchar(200) DEFAULT '' COMMENT '权限路径（用于树形展示）',
  `sort_order` int DEFAULT 0 COMMENT '排序',
  `created_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `modified_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统权限定义表';

-- ==================== 角色权限关联表 ====================
CREATE TABLE IF NOT EXISTS `sys_role_permission` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `permission_id` bigint NOT NULL COMMENT '权限ID',
  `created_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_role_id` (`role_id`),
  KEY `idx_permission_id` (`permission_id`),
  UNIQUE KEY `uk_role_perm` (`role_id`, `permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色权限关联表';

-- ==================== 用户角色关联表 ====================
CREATE TABLE IF NOT EXISTS `sys_user_role` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `role_id` bigint NOT NULL COMMENT '角色ID',
  `created_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `created_by` bigint DEFAULT 0 COMMENT '创建人ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_role_id` (`role_id`),
  UNIQUE KEY `uk_user_role` (`user_id`, `role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户角色关联表';

-- ==================== 用户集群权限表 ====================
CREATE TABLE IF NOT EXISTS `sys_user_cluster` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `cluster_id` bigint NOT NULL COMMENT '集群ID',
  `role_type` varchar(30) NOT NULL DEFAULT 'viewer' COMMENT '角色类型: cluster_admin/developer/viewer',
  `namespaces` text COMMENT '可访问的命名空间（JSON数组，空表示全部）',
  `can_view` tinyint(1) NOT NULL DEFAULT 1 COMMENT '查看权限',
  `can_create` tinyint(1) NOT NULL DEFAULT 0 COMMENT '创建权限',
  `can_update` tinyint(1) NOT NULL DEFAULT 0 COMMENT '更新权限',
  `can_delete` tinyint(1) NOT NULL DEFAULT 0 COMMENT '删除权限',
  `can_exec` tinyint(1) NOT NULL DEFAULT 0 COMMENT '执行权限（进入容器等）',
  `expire_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '过期时间（0表示永不过期）',
  `created_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '创建时间',
  `modified_at` bigint unsigned NOT NULL DEFAULT 0 COMMENT '修改时间',
  `created_by` bigint DEFAULT 0 COMMENT '授权人ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_cluster_id` (`cluster_id`),
  UNIQUE KEY `uk_user_cluster` (`user_id`, `cluster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户集群权限表';

-- ==================== 初始化角色数据 ====================
INSERT INTO `sys_role` (`id`, `name`, `display_name`, `description`, `role_type`, `is_system`, `color`, `icon`, `sort_order`, `created_at`, `modified_at`) VALUES
(1, 'super_admin', '超级管理员', '拥有系统所有权限，可管理所有集群和用户', 'super_admin', 1, '#f5222d', 'admin', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(2, 'cluster_admin', '集群管理员', '可管理指定集群的所有资源', 'cluster_admin', 1, '#1890ff', 'admin', 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(3, 'developer', '开发者', '可创建和管理工作负载、配置等资源', 'developer', 1, '#52c41a', 'dev', 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(4, 'viewer', '只读用户', '只能查看资源，不能进行任何修改操作', 'viewer', 1, '#722ed1', 'viewer', 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`);

-- ==================== 初始化权限定义 ====================
INSERT INTO `sys_permission` (`id`, `name`, `display_name`, `resource_type`, `action`, `sort_order`, `created_at`, `modified_at`) VALUES
-- 集群权限
(1, 'cluster:view', '查看集群', 'cluster', 'view', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(2, 'cluster:create', '创建集群', 'cluster', 'create', 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(3, 'cluster:update', '更新集群', 'cluster', 'update', 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(4, 'cluster:delete', '删除集群', 'cluster', 'delete', 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 命名空间权限
(5, 'namespace:view', '查看命名空间', 'namespace', 'view', 5, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(6, 'namespace:create', '创建命名空间', 'namespace', 'create', 6, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(7, 'namespace:update', '更新命名空间', 'namespace', 'update', 7, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(8, 'namespace:delete', '删除命名空间', 'namespace', 'delete', 8, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 工作负载权限
(9, 'deployment:view', '查看Deployment', 'deployment', 'view', 9, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(10, 'deployment:create', '创建Deployment', 'deployment', 'create', 10, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(11, 'deployment:update', '更新Deployment', 'deployment', 'update', 11, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(12, 'deployment:delete', '删除Deployment', 'deployment', 'delete', 12, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- Pod权限
(13, 'pod:view', '查看Pod', 'pod', 'view', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(14, 'pod:exec', '进入Pod', 'pod', 'exec', 14, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(15, 'pod:delete', '删除Pod', 'pod', 'delete', 15, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 用户管理权限
(16, 'user:view', '查看用户', 'user', 'view', 16, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(17, 'user:create', '创建用户', 'user', 'create', 17, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(18, 'user:update', '更新用户', 'user', 'update', 18, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(19, 'user:delete', '删除用户', 'user', 'delete', 19, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 角色管理权限
(20, 'role:view', '查看角色', 'role', 'view', 20, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(21, 'role:manage', '管理角色', 'role', 'manage', 21, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 流水线权限
(22, 'pipeline:view', '查看流水线', 'pipeline', 'view', 22, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(23, 'pipeline:create', '创建流水线', 'pipeline', 'create', 23, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(24, 'pipeline:update', '更新流水线', 'pipeline', 'update', 24, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(25, 'pipeline:delete', '删除流水线', 'pipeline', 'delete', 25, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(26, 'pipeline:run', '运行流水线', 'pipeline', 'exec', 26, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`);

-- ==================== 角色权限关联（超级管理员拥有所有权限） ====================
INSERT INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`)
SELECT 1, id, UNIX_TIMESTAMP() FROM `sys_permission`
ON DUPLICATE KEY UPDATE `created_at` = VALUES(`created_at`);

-- ==================== 集群管理员权限 ====================
INSERT INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`) VALUES
(2, 1, UNIX_TIMESTAMP()), -- cluster:view
(2, 3, UNIX_TIMESTAMP()), -- cluster:update
(2, 5, UNIX_TIMESTAMP()), -- namespace:view
(2, 6, UNIX_TIMESTAMP()), -- namespace:create
(2, 7, UNIX_TIMESTAMP()), -- namespace:update
(2, 8, UNIX_TIMESTAMP()), -- namespace:delete
(2, 9, UNIX_TIMESTAMP()), -- deployment:view
(2, 10, UNIX_TIMESTAMP()), -- deployment:create
(2, 11, UNIX_TIMESTAMP()), -- deployment:update
(2, 12, UNIX_TIMESTAMP()), -- deployment:delete
(2, 13, UNIX_TIMESTAMP()), -- pod:view
(2, 14, UNIX_TIMESTAMP()), -- pod:exec
(2, 15, UNIX_TIMESTAMP()), -- pod:delete
(2, 22, UNIX_TIMESTAMP()), -- pipeline:view
(2, 23, UNIX_TIMESTAMP()), -- pipeline:create
(2, 24, UNIX_TIMESTAMP()), -- pipeline:update
(2, 25, UNIX_TIMESTAMP()), -- pipeline:delete
(2, 26, UNIX_TIMESTAMP())  -- pipeline:run
ON DUPLICATE KEY UPDATE `created_at` = VALUES(`created_at`);

-- ==================== 开发者权限 ====================
INSERT INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`) VALUES
(3, 1, UNIX_TIMESTAMP()), -- cluster:view
(3, 5, UNIX_TIMESTAMP()), -- namespace:view
(3, 9, UNIX_TIMESTAMP()), -- deployment:view
(3, 10, UNIX_TIMESTAMP()), -- deployment:create
(3, 11, UNIX_TIMESTAMP()), -- deployment:update
(3, 13, UNIX_TIMESTAMP()), -- pod:view
(3, 14, UNIX_TIMESTAMP()), -- pod:exec
(3, 22, UNIX_TIMESTAMP()), -- pipeline:view
(3, 23, UNIX_TIMESTAMP()), -- pipeline:create
(3, 26, UNIX_TIMESTAMP())  -- pipeline:run
ON DUPLICATE KEY UPDATE `created_at` = VALUES(`created_at`);

-- ==================== 只读用户权限 ====================
INSERT INTO `sys_role_permission` (`role_id`, `permission_id`, `created_at`) VALUES
(4, 1, UNIX_TIMESTAMP()), -- cluster:view
(4, 5, UNIX_TIMESTAMP()), -- namespace:view
(4, 9, UNIX_TIMESTAMP()), -- deployment:view
(4, 13, UNIX_TIMESTAMP()), -- pod:view
(4, 22, UNIX_TIMESTAMP())  -- pipeline:view
ON DUPLICATE KEY UPDATE `created_at` = VALUES(`created_at`);

-- ==================== 初始化管理员用户角色 ====================
-- 假设 admin 用户的 ID 是 1
INSERT INTO `sys_user_role` (`user_id`, `role_id`, `created_at`, `created_by`) VALUES
(1, 1, UNIX_TIMESTAMP(), 0)  -- 用户1 = 超级管理员
ON DUPLICATE KEY UPDATE `created_at` = VALUES(`created_at`);

SELECT '✅ RBAC 初始化完成！' AS message;
SELECT CONCAT('角色数量: ', COUNT(*)) AS roles FROM `sys_role` WHERE `is_del` = 0;
SELECT CONCAT('权限数量: ', COUNT(*)) AS permissions FROM `sys_permission`;

