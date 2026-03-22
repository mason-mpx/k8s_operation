-- CICD 发布平台 - 资源配置分层管理
-- 创建时间: 2026-03-20

-- 1. 资源档位模板表（平台管理员维护）
CREATE TABLE IF NOT EXISTS cicd_resource_template (
    id              BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(64) NOT NULL COMMENT '模板名称：small/medium/large/custom',
    service_type    VARCHAR(32) NOT NULL COMMENT '服务类型：java/go/node/python',
    env             VARCHAR(16) NOT NULL COMMENT '环境：dev/test/staging/prod',
    
    -- 资源配置
    replicas_default INT NOT NULL DEFAULT 1 COMMENT '默认副本数',
    replicas_min     INT NOT NULL DEFAULT 1 COMMENT '最小副本数',
    replicas_max     INT NOT NULL DEFAULT 10 COMMENT '最大副本数',
    
    cpu_request      VARCHAR(16) NOT NULL DEFAULT '200m',
    cpu_limit        VARCHAR(16) NOT NULL DEFAULT '500m',
    memory_request   VARCHAR(16) NOT NULL DEFAULT '256Mi',
    memory_limit     VARCHAR(16) NOT NULL DEFAULT '512Mi',
    
    -- HPA 配置
    hpa_enabled      TINYINT(1) DEFAULT 0 COMMENT '是否启用HPA',
    hpa_min_replicas INT DEFAULT 2,
    hpa_max_replicas INT DEFAULT 10,
    hpa_cpu_target   INT DEFAULT 70 COMMENT 'CPU目标利用率%',
    
    description      VARCHAR(255) DEFAULT '' COMMENT '模板说明',
    is_default       TINYINT(1) DEFAULT 0 COMMENT '是否默认模板',
    sort_order       INT DEFAULT 0,
    created_at       BIGINT UNSIGNED DEFAULT 0,
    modified_at      BIGINT UNSIGNED DEFAULT 0,
    deleted_at       BIGINT UNSIGNED DEFAULT 0,
    
    UNIQUE KEY uk_type_env_name (service_type, env, name, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT '资源档位模板';

-- 2. 环境资源规则表（限制边界）
CREATE TABLE IF NOT EXISTS cicd_env_resource_rule (
    id              BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    env             VARCHAR(16) NOT NULL COMMENT 'dev/test/staging/prod',
    service_type    VARCHAR(32) DEFAULT '' COMMENT '服务类型，空=通用',
    
    -- 资源上限
    cpu_limit_max       VARCHAR(16) NOT NULL DEFAULT '4' COMMENT 'CPU limit 最大值',
    memory_limit_max    VARCHAR(16) NOT NULL DEFAULT '8Gi' COMMENT '内存 limit 最大值',
    replicas_max        INT NOT NULL DEFAULT 10 COMMENT '副本数上限',
    
    -- 资源下限（生产环境）
    cpu_request_min     VARCHAR(16) DEFAULT '' COMMENT 'CPU request 最小值',
    memory_request_min  VARCHAR(16) DEFAULT '' COMMENT '内存 request 最小值',
    replicas_min        INT DEFAULT 1 COMMENT '副本数下限',
    
    -- 审批规则
    require_approval    TINYINT(1) DEFAULT 0 COMMENT '是否需要审批',
    approval_role       VARCHAR(64) DEFAULT '' COMMENT '审批角色：sre/admin',
    
    description         VARCHAR(255) DEFAULT '' COMMENT '规则说明',
    created_at          BIGINT UNSIGNED DEFAULT 0,
    modified_at         BIGINT UNSIGNED DEFAULT 0,
    
    UNIQUE KEY uk_env_type (env, service_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT '环境资源规则';

-- 3. 发布审批记录表
CREATE TABLE IF NOT EXISTS cicd_deploy_approval (
    id              BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    pipeline_id     BIGINT UNSIGNED NOT NULL COMMENT '流水线ID',
    release_id      BIGINT UNSIGNED DEFAULT 0 COMMENT '发布单ID',
    env             VARCHAR(16) NOT NULL COMMENT '目标环境',
    
    -- 申请配置（JSON）
    requested_config TEXT COMMENT '申请的资源配置JSON',
    current_config   TEXT COMMENT '当前线上配置JSON',
    
    -- 风险提示
    risk_level       ENUM('low','medium','high') DEFAULT 'low',
    risk_warnings    TEXT COMMENT '风险提示列表JSON',
    
    -- 审批流程
    status           ENUM('pending','approved','rejected','expired','cancelled') DEFAULT 'pending',
    applicant_id     BIGINT UNSIGNED NOT NULL COMMENT '申请人ID',
    applicant_name   VARCHAR(64) NOT NULL,
    approver_id      BIGINT UNSIGNED DEFAULT 0 COMMENT '审批人ID',
    approver_name    VARCHAR(64) DEFAULT '',
    approve_comment  VARCHAR(500) DEFAULT '' COMMENT '审批意见',
    
    applied_at       BIGINT UNSIGNED DEFAULT 0 COMMENT '申请时间',
    approved_at      BIGINT UNSIGNED DEFAULT 0 COMMENT '审批时间',
    expired_at       BIGINT UNSIGNED DEFAULT 0 COMMENT '过期时间',
    
    INDEX idx_pipeline (pipeline_id),
    INDEX idx_status (status, applied_at),
    INDEX idx_applicant (applicant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT '发布审批记录';

-- 4. 资源配置变更日志表
CREATE TABLE IF NOT EXISTS cicd_resource_change_log (
    id              BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    pipeline_id     BIGINT UNSIGNED NOT NULL,
    env             VARCHAR(16) NOT NULL,
    
    change_type     ENUM('create','update','scale','rollback') NOT NULL,
    before_config   TEXT COMMENT '变更前配置JSON',
    after_config    TEXT COMMENT '变更后配置JSON',
    
    operator_id     BIGINT UNSIGNED NOT NULL,
    operator_name   VARCHAR(64) NOT NULL,
    reason          VARCHAR(500) DEFAULT '' COMMENT '变更原因',
    
    created_at      BIGINT UNSIGNED DEFAULT 0,
    
    INDEX idx_pipeline_env (pipeline_id, env),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT '资源配置变更日志';

-- =============================================
-- 初始化默认数据
-- =============================================

-- Java 服务模板
INSERT INTO cicd_resource_template 
(name, service_type, env, replicas_default, replicas_min, replicas_max, cpu_request, cpu_limit, memory_request, memory_limit, hpa_enabled, description, is_default, sort_order, created_at, modified_at)
VALUES
('small',  'java', 'dev',  1, 1, 2,  '200m', '500m', '512Mi', '1Gi',   0, 'Java开发环境-小型，适合本地调试', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'java', 'test', 1, 1, 3,  '500m', '1',    '1Gi',   '2Gi',   0, 'Java测试环境-小型，适合功能测试', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'java', 'prod', 2, 2, 5,  '500m', '1',    '1Gi',   '2Gi',   0, 'Java生产环境-小型，适合低流量服务', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('medium', 'java', 'prod', 2, 2, 10, '1',    '2',    '2Gi',   '4Gi',   1, 'Java生产环境-中型，适合中等流量服务', 0, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('large',  'java', 'prod', 3, 2, 20, '2',    '4',    '4Gi',   '8Gi',   1, 'Java生产环境-大型，适合高流量核心服务', 0, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- Go 服务模板（资源更小）
INSERT INTO cicd_resource_template 
(name, service_type, env, replicas_default, replicas_min, replicas_max, cpu_request, cpu_limit, memory_request, memory_limit, hpa_enabled, description, is_default, sort_order, created_at, modified_at)
VALUES
('small',  'go', 'dev',  1, 1, 2,  '100m', '200m', '128Mi', '256Mi', 0, 'Go开发环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'go', 'test', 1, 1, 3,  '200m', '500m', '256Mi', '512Mi', 0, 'Go测试环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'go', 'prod', 2, 2, 5,  '200m', '500m', '256Mi', '512Mi', 0, 'Go生产环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('medium', 'go', 'prod', 2, 2, 10, '500m', '1',    '512Mi', '1Gi',   1, 'Go生产环境-中型', 0, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('large',  'go', 'prod', 3, 2, 20, '1',    '2',    '1Gi',   '2Gi',   1, 'Go生产环境-大型', 0, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- Node 服务模板
INSERT INTO cicd_resource_template 
(name, service_type, env, replicas_default, replicas_min, replicas_max, cpu_request, cpu_limit, memory_request, memory_limit, hpa_enabled, description, is_default, sort_order, created_at, modified_at)
VALUES
('small',  'node', 'dev',  1, 1, 2,  '100m', '300m', '256Mi', '512Mi', 0, 'Node开发环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'node', 'test', 1, 1, 3,  '200m', '500m', '512Mi', '1Gi',   0, 'Node测试环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'node', 'prod', 2, 2, 5,  '200m', '500m', '512Mi', '1Gi',   0, 'Node生产环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('medium', 'node', 'prod', 2, 2, 10, '500m', '1',    '1Gi',   '2Gi',   1, 'Node生产环境-中型', 0, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- Python 服务模板
INSERT INTO cicd_resource_template 
(name, service_type, env, replicas_default, replicas_min, replicas_max, cpu_request, cpu_limit, memory_request, memory_limit, hpa_enabled, description, is_default, sort_order, created_at, modified_at)
VALUES
('small',  'python', 'dev',  1, 1, 2,  '100m', '300m', '256Mi', '512Mi', 0, 'Python开发环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'python', 'test', 1, 1, 3,  '200m', '500m', '512Mi', '1Gi',   0, 'Python测试环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('small',  'python', 'prod', 2, 2, 5,  '200m', '500m', '512Mi', '1Gi',   0, 'Python生产环境-小型', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
('medium', 'python', 'prod', 2, 2, 10, '500m', '1',    '1Gi',   '2Gi',   1, 'Python生产环境-中型', 0, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 环境资源规则
INSERT INTO cicd_env_resource_rule 
(env, service_type, cpu_limit_max, memory_limit_max, replicas_max, cpu_request_min, memory_request_min, replicas_min, require_approval, approval_role, description, created_at, modified_at)
VALUES
-- 开发环境（宽松，不审批）
('dev', '', '1', '2Gi', 3, '', '', 1, 0, '', '开发环境通用规则，资源受限，无需审批', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 测试环境（适中，不审批）
('test', '', '2', '4Gi', 5, '', '', 1, 0, '', '测试环境通用规则，资源适中，无需审批', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 预发环境
('staging', '', '4', '8Gi', 10, '200m', '256Mi', 2, 0, '', '预发环境通用规则，接近生产配置', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 生产环境（严格，需审批）
('prod', '', '4', '8Gi', 20, '200m', '256Mi', 2, 1, 'sre', '生产环境通用规则，需要SRE审批', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
-- 生产环境 Java 特殊规则（内存要求更高）
('prod', 'java', '4', '8Gi', 20, '500m', '1Gi', 2, 1, 'sre', '生产环境Java服务规则，内存最低1Gi', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
