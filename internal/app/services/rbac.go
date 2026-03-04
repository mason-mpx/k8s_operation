package services

import (
	"encoding/json"
	"k8soperation/internal/app/models"
	"k8soperation/internal/app/requests"
)

// ==================== 角色管理 ====================

// RoleCreate 创建角色
func (s *Services) RoleCreate(req *requests.RoleCreateRequest) (*models.SysRole, error) {
	return s.dao.RoleCreate(
		req.Name,
		req.DisplayName,
		req.Description,
		req.RoleType,
		req.Color,
		req.Icon,
	)
}

// RoleUpdate 更新角色
func (s *Services) RoleUpdate(req *requests.RoleUpdateRequest) error {
	// 检查是否为系统内置角色
	role, err := s.dao.RoleGetByID(req.ID)
	if err != nil {
		return err
	}
	if role.IsSystem {
		// 系统内置角色只能修改显示名称和描述
		values := map[string]interface{}{
			"display_name": req.DisplayName,
			"description":  req.Description,
		}
		return s.dao.RoleUpdate(req.ID, values)
	}

	values := map[string]interface{}{
		"display_name": req.DisplayName,
		"description":  req.Description,
		"color":        req.Color,
		"icon":         req.Icon,
		"sort_order":   req.SortOrder,
	}
	return s.dao.RoleUpdate(req.ID, values)
}

// RoleDelete 删除角色
func (s *Services) RoleDelete(id int64) error {
	// 检查是否为系统内置角色
	role, err := s.dao.RoleGetByID(id)
	if err != nil {
		return err
	}
	if role.IsSystem {
		return nil // 系统角色不可删除，静默返回
	}
	return s.dao.RoleDelete(id)
}

// RoleGetByID 获取角色详情
func (s *Services) RoleGetByID(id int64) (*models.RoleWithPermissions, error) {
	role, err := s.dao.RoleGetByID(id)
	if err != nil {
		return nil, err
	}
	permissions, _ := s.dao.PermissionGetByRoleID(id)
	return &models.RoleWithPermissions{
		SysRole:     *role,
		Permissions: permissions,
	}, nil
}

// RoleList 获取角色列表
func (s *Services) RoleList(req *requests.RoleListRequest) ([]*models.SysRole, int64, error) {
	return s.dao.RoleList(req.Name, req.RoleType, req.Page, req.Limit)
}

// RoleListAll 获取所有角色
func (s *Services) RoleListAll() ([]*models.SysRole, error) {
	return s.dao.RoleListAll()
}

// ==================== 权限管理 ====================

// PermissionList 获取权限列表
func (s *Services) PermissionList() ([]*models.SysPermission, error) {
	return s.dao.PermissionList()
}

// RolePermissionAssign 分配角色权限
func (s *Services) RolePermissionAssign(roleID int64, permissionIDs []int64) error {
	return s.dao.RolePermissionAssign(roleID, permissionIDs)
}

// ==================== 用户角色管理 ====================

// UserRoleAssign 分配用户角色
func (s *Services) UserRoleAssign(req *requests.UserRoleAssignRequest, operatorID int64) error {
	return s.dao.UserRoleAssign(req.UserID, req.RoleIDs, operatorID)
}

// UserRoleList 获取用户角色列表
func (s *Services) UserRoleList(userID int64) ([]*models.SysRole, error) {
	return s.dao.UserRoleList(userID)
}

// UserRoleRemove 移除用户角色
func (s *Services) UserRoleRemove(userID, roleID int64) error {
	return s.dao.UserRoleRemove(userID, roleID)
}

// ==================== 集群权限管理 ====================

// ClusterPermissionCreate 创建集群权限
func (s *Services) ClusterPermissionCreate(req *requests.ClusterPermissionCreateRequest, operatorID int64) (*models.SysUserCluster, error) {
	return s.dao.ClusterPermissionCreate(
		req.UserID,
		req.ClusterID,
		req.RoleType,
		req.Namespaces,
		req.CanView,
		req.CanCreate,
		req.CanUpdate,
		req.CanDelete,
		req.CanExec,
		req.ExpireAt,
		operatorID,
	)
}

// ClusterPermissionUpdate 更新集群权限
func (s *Services) ClusterPermissionUpdate(req *requests.ClusterPermissionUpdateRequest) error {
	nsJSON := ""
	if len(req.Namespaces) > 0 {
		if data, err := json.Marshal(req.Namespaces); err == nil {
			nsJSON = string(data)
		}
	}

	values := map[string]interface{}{
		"role_type":  req.RoleType,
		"namespaces": nsJSON,
		"can_view":   req.CanView,
		"can_create": req.CanCreate,
		"can_update": req.CanUpdate,
		"can_delete": req.CanDelete,
		"can_exec":   req.CanExec,
		"expire_at":  req.ExpireAt,
	}
	return s.dao.ClusterPermissionUpdate(req.ID, values)
}

// ClusterPermissionDelete 删除集群权限
func (s *Services) ClusterPermissionDelete(id int64) error {
	return s.dao.ClusterPermissionDelete(id)
}

// ClusterPermissionList 获取集群权限列表
func (s *Services) ClusterPermissionList(req *requests.ClusterPermissionListRequest) ([]*models.ClusterPermissionDetail, int64, error) {
	return s.dao.ClusterPermissionList(req.UserID, req.ClusterID, req.Page, req.Limit)
}

// ClusterPermissionListByUser 获取用户的所有集群权限
func (s *Services) ClusterPermissionListByUser(userID int64) ([]*models.ClusterPermissionDetail, error) {
	return s.dao.ClusterPermissionListByUser(userID)
}

// BatchClusterPermissionCreate 批量分配集群权限
func (s *Services) BatchClusterPermissionCreate(req *requests.BatchClusterPermissionRequest, operatorID int64) error {
	return s.dao.BatchClusterPermissionCreate(
		req.UserID,
		req.ClusterIDs,
		req.RoleType,
		req.CanView,
		req.CanCreate,
		req.CanUpdate,
		req.CanDelete,
		req.CanExec,
		operatorID,
	)
}

// ==================== 权限检查 ====================

// CheckClusterPermission 检查用户集群权限
func (s *Services) CheckClusterPermission(userID, clusterID int64, action string) bool {
	// 超级管理员拥有所有权限
	if s.dao.IsSuperAdmin(userID) {
		return true
	}
	return s.dao.ClusterPermissionCheck(userID, clusterID, action)
}

// IsSuperAdmin 检查用户是否为超级管理员
func (s *Services) IsSuperAdmin(userID int64) bool {
	return s.dao.IsSuperAdmin(userID)
}

// GetUserAccessibleClusters 获取用户可访问的集群
func (s *Services) GetUserAccessibleClusters(userID int64) ([]*models.K8sCluster, error) {
	return s.dao.GetUserAccessibleClusters(userID)
}

// ==================== 用户完整信息 ====================

// UserWithRBACInfo 用户完整信息（包含角色和集群权限）
type UserWithRBACInfo struct {
	UserID             int64                            `json:"user_id"`
	Username           string                           `json:"username"`
	IsSuperAdmin       bool                             `json:"is_super_admin"`
	Roles              []*models.SysRole                `json:"roles"`
	ClusterPermissions []*models.ClusterPermissionDetail `json:"cluster_permissions"`
}

// GetUserWithRBACInfo 获取用户完整RBAC信息
func (s *Services) GetUserWithRBACInfo(userID int64) (*UserWithRBACInfo, error) {
	// 获取用户角色
	roles, err := s.dao.UserRoleList(userID)
	if err != nil {
		return nil, err
	}

	// 获取集群权限
	clusterPerms, err := s.dao.ClusterPermissionListByUser(userID)
	if err != nil {
		return nil, err
	}

	// 检查是否超级管理员
	isSuperAdmin := s.dao.IsSuperAdmin(userID)

	// 获取用户名
	username := ""
	if user, err := s.dao.UserGetByID(userID); err == nil && user != nil {
		username = user.Username
	}

	return &UserWithRBACInfo{
		UserID:             userID,
		Username:           username,
		IsSuperAdmin:       isSuperAdmin,
		Roles:              roles,
		ClusterPermissions: clusterPerms,
	}, nil
}

// GetUserAccessibleNamespaces 获取用户在指定集群可访问的命名空间
func (s *Services) GetUserAccessibleNamespaces(userID, clusterID int64) ([]string, error) {
	// 超级管理员可访问所有命名空间
	if s.dao.IsSuperAdmin(userID) {
		return []string{}, nil // 空数组表示所有
	}

	return s.dao.GetUserAccessibleNamespaces(userID, clusterID)
}
