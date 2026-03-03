package models

import (
	"gorm.io/gorm"
)

// ==================== 角色类型常量 ====================

const (
	RoleTypeSuperAdmin   = "super_admin"   // 超级管理员
	RoleTypeClusterAdmin = "cluster_admin" // 集群管理员
	RoleTypeDeveloper    = "developer"     // 开发者
	RoleTypeViewer       = "viewer"        // 只读用户
)

// ==================== 权限操作常量 ====================

const (
	PermissionActionView   = "view"   // 查看
	PermissionActionCreate = "create" // 创建
	PermissionActionUpdate = "update" // 更新
	PermissionActionDelete = "delete" // 删除
	PermissionActionExec   = "exec"   // 执行（如进入容器）
	PermissionActionManage = "manage" // 管理（完整权限）
)

// ==================== 资源类型常量 ====================

const (
	ResourceTypeCluster     = "cluster"     // 集群
	ResourceTypeNamespace   = "namespace"   // 命名空间
	ResourceTypeDeployment  = "deployment"  // Deployment
	ResourceTypePod         = "pod"         // Pod
	ResourceTypeService     = "service"     // Service
	ResourceTypeConfigMap   = "configmap"   // ConfigMap
	ResourceTypeSecret      = "secret"      // Secret
	ResourceTypePVC         = "pvc"         // PVC
	ResourceTypeIngress     = "ingress"     // Ingress
	ResourceTypePipeline    = "pipeline"    // CI/CD 流水线
	ResourceTypeUser        = "user"        // 用户管理
	ResourceTypeRole        = "role"        // 角色管理
)

// ==================== 系统角色表 ====================

// SysRole 系统角色
type SysRole struct {
	ID          int64  `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Name        string `gorm:"column:name;uniqueIndex" json:"name"`                 // 角色标识（唯一）
	DisplayName string `gorm:"column:display_name" json:"display_name"`             // 显示名称
	Description string `gorm:"column:description" json:"description"`               // 描述
	RoleType    string `gorm:"column:role_type" json:"role_type"`                   // 角色类型
	IsSystem    bool   `gorm:"column:is_system;default:false" json:"is_system"`     // 是否系统内置
	Color       string `gorm:"column:color;default:'#1890ff'" json:"color"`         // 角色颜色标识
	Icon        string `gorm:"column:icon;default:'user'" json:"icon"`              // 图标
	SortOrder   int    `gorm:"column:sort_order;default:0" json:"sort_order"`       // 排序
	CreatedAt   uint64 `gorm:"column:created_at" json:"created_at"`
	ModifiedAt  uint64 `gorm:"column:modified_at" json:"modified_at"`
	DeletedAt   uint64 `gorm:"column:deleted_at" json:"deleted_at"`
	IsDel       uint8  `gorm:"column:is_del;default:0" json:"is_del"`
}

func (SysRole) TableName() string { return "sys_role" }

// ==================== 系统权限表 ====================

// SysPermission 系统权限定义
type SysPermission struct {
	ID           int64  `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Name         string `gorm:"column:name;uniqueIndex" json:"name"`           // 权限标识（唯一）
	DisplayName  string `gorm:"column:display_name" json:"display_name"`       // 显示名称
	Description  string `gorm:"column:description" json:"description"`         // 描述
	ResourceType string `gorm:"column:resource_type" json:"resource_type"`     // 资源类型
	Action       string `gorm:"column:action" json:"action"`                   // 操作类型
	ParentID     int64  `gorm:"column:parent_id;default:0" json:"parent_id"`   // 父权限ID
	Path         string `gorm:"column:path" json:"path"`                       // 权限路径（用于树形展示）
	SortOrder    int    `gorm:"column:sort_order;default:0" json:"sort_order"` // 排序
	CreatedAt    uint64 `gorm:"column:created_at" json:"created_at"`
	ModifiedAt   uint64 `gorm:"column:modified_at" json:"modified_at"`
}

func (SysPermission) TableName() string { return "sys_permission" }

// ==================== 角色权限关联表 ====================

// SysRolePermission 角色权限关联
type SysRolePermission struct {
	ID           int64  `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	RoleID       int64  `gorm:"column:role_id;index" json:"role_id"`           // 角色ID
	PermissionID int64  `gorm:"column:permission_id;index" json:"permission_id"` // 权限ID
	CreatedAt    uint64 `gorm:"column:created_at" json:"created_at"`
}

func (SysRolePermission) TableName() string { return "sys_role_permission" }

// ==================== 用户角色关联表 ====================

// SysUserRole 用户角色关联
type SysUserRole struct {
	ID         int64  `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID     int64  `gorm:"column:user_id;index" json:"user_id"`     // 用户ID
	RoleID     int64  `gorm:"column:role_id;index" json:"role_id"`     // 角色ID
	CreatedAt  uint64 `gorm:"column:created_at" json:"created_at"`
	CreatedBy  int64  `gorm:"column:created_by" json:"created_by"`     // 创建人
}

func (SysUserRole) TableName() string { return "sys_user_role" }

// ==================== 用户集群权限表 ====================

// SysUserCluster 用户集群权限（细粒度控制用户对特定集群的访问）
type SysUserCluster struct {
	ID          int64  `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID      int64  `gorm:"column:user_id;index" json:"user_id"`               // 用户ID
	ClusterID   int64  `gorm:"column:cluster_id;index" json:"cluster_id"`         // 集群ID
	RoleType    string `gorm:"column:role_type" json:"role_type"`                 // 在该集群的角色类型
	Namespaces  string `gorm:"column:namespaces;type:text" json:"namespaces"`     // 可访问的命名空间（JSON数组，空表示全部）
	CanView     bool   `gorm:"column:can_view;default:true" json:"can_view"`      // 查看权限
	CanCreate   bool   `gorm:"column:can_create;default:false" json:"can_create"` // 创建权限
	CanUpdate   bool   `gorm:"column:can_update;default:false" json:"can_update"` // 更新权限
	CanDelete   bool   `gorm:"column:can_delete;default:false" json:"can_delete"` // 删除权限
	CanExec     bool   `gorm:"column:can_exec;default:false" json:"can_exec"`     // 执行权限（进入容器等）
	ExpireAt    uint64 `gorm:"column:expire_at;default:0" json:"expire_at"`       // 过期时间（0表示永不过期）
	CreatedAt   uint64 `gorm:"column:created_at" json:"created_at"`
	ModifiedAt  uint64 `gorm:"column:modified_at" json:"modified_at"`
	CreatedBy   int64  `gorm:"column:created_by" json:"created_by"` // 授权人
}

func (SysUserCluster) TableName() string { return "sys_user_cluster" }

// ==================== 扩展用户模型（添加角色相关字段） ====================

// UserWithRole 带角色信息的用户
type UserWithRole struct {
	ID          uint32     `json:"id"`
	Username    string     `json:"username"`
	Email       string     `json:"email"`
	Phone       string     `json:"phone"`
	Avatar      string     `json:"avatar"`
	Status      uint8      `json:"status"`
	Roles       []*SysRole `json:"roles" gorm:"-"`           // 用户角色列表
	RoleNames   []string   `json:"role_names" gorm:"-"`      // 角色名称列表
	ClusterIDs  []int64    `json:"cluster_ids" gorm:"-"`     // 可访问的集群ID列表
	IsSuperAdmin bool      `json:"is_super_admin" gorm:"-"`  // 是否超级管理员
	CreatedAt   uint32     `json:"created_at"`
	ModifiedAt  uint32     `json:"modified_at"`
}

// ==================== 角色权限详情 ====================

// RoleWithPermissions 带权限的角色
type RoleWithPermissions struct {
	SysRole
	Permissions []*SysPermission `json:"permissions" gorm:"-"` // 权限列表
	UserCount   int64            `json:"user_count" gorm:"-"`  // 用户数量
}

// ==================== 集群权限详情 ====================

// ClusterPermissionDetail 集群权限详情
type ClusterPermissionDetail struct {
	SysUserCluster
	ClusterName string   `json:"cluster_name" gorm:"-"` // 集群名称
	Username    string   `json:"username" gorm:"-"`     // 用户名
	NsList      []string `json:"ns_list" gorm:"-"`      // 命名空间列表
}

// ==================== DAO 方法 ====================

// GetUserRoles 获取用户角色列表
func GetUserRoles(db *gorm.DB, userID int64) ([]*SysRole, error) {
	var roles []*SysRole
	err := db.Table("sys_role").
		Joins("JOIN sys_user_role ON sys_role.id = sys_user_role.role_id").
		Where("sys_user_role.user_id = ? AND sys_role.is_del = 0", userID).
		Find(&roles).Error
	return roles, err
}

// GetUserClusterPermissions 获取用户集群权限
func GetUserClusterPermissions(db *gorm.DB, userID int64) ([]*SysUserCluster, error) {
	var permissions []*SysUserCluster
	err := db.Where("user_id = ?", userID).Find(&permissions).Error
	return permissions, err
}

// HasClusterPermission 检查用户是否有集群权限
func HasClusterPermission(db *gorm.DB, userID, clusterID int64, action string) bool {
	var count int64
	query := db.Model(&SysUserCluster{}).Where("user_id = ? AND cluster_id = ?", userID, clusterID)
	
	switch action {
	case PermissionActionView:
		query = query.Where("can_view = true")
	case PermissionActionCreate:
		query = query.Where("can_create = true")
	case PermissionActionUpdate:
		query = query.Where("can_update = true")
	case PermissionActionDelete:
		query = query.Where("can_delete = true")
	case PermissionActionExec:
		query = query.Where("can_exec = true")
	}
	
	query.Count(&count)
	return count > 0
}

// IsSuperAdmin 检查用户是否为超级管理员
func IsSuperAdmin(db *gorm.DB, userID int64) bool {
	var count int64
	db.Table("sys_user_role").
		Joins("JOIN sys_role ON sys_role.id = sys_user_role.role_id").
		Where("sys_user_role.user_id = ? AND sys_role.role_type = ? AND sys_role.is_del = 0", userID, RoleTypeSuperAdmin).
		Count(&count)
	return count > 0
}
