package rbac

import (
	"github.com/gin-gonic/gin"
	v1 "k8soperation/internal/app/controllers/api/v1/rbac"
)

type RBACRouter struct{}

func NewRBACRouter() *RBACRouter {
	return &RBACRouter{}
}

func (r *RBACRouter) Inject(router *gin.RouterGroup) {
	c := v1.NewRBACController()

	// 角色管理
	role := router.Group("/role")
	{
		role.GET("/list", c.RoleList)         // 获取角色列表（分页）
		role.GET("/all", c.RoleListAll)       // 获取所有角色（下拉用）
		role.GET("/detail", c.RoleDetail)     // 获取角色详情
		role.POST("/create", c.RoleCreate)    // 创建角色
		role.POST("/update", c.RoleUpdate)    // 更新角色
		role.POST("/delete", c.RoleDelete)    // 删除角色
	}

	// 权限管理
	permission := router.Group("/permission")
	{
		permission.GET("/list", c.PermissionList) // 获取权限列表
	}

	// 用户角色管理
	userRole := router.Group("/user-role")
	{
		userRole.POST("/assign", c.UserRoleAssign) // 分配用户角色
		userRole.GET("/list", c.UserRoleList)      // 获取用户角色
	}

	// 集群权限管理
	clusterPerm := router.Group("/cluster-permission")
	{
		clusterPerm.POST("/create", c.ClusterPermissionCreate)   // 创建集群权限
		clusterPerm.POST("/update", c.ClusterPermissionUpdate)   // 更新集群权限
		clusterPerm.POST("/delete", c.ClusterPermissionDelete)   // 删除集群权限
		clusterPerm.GET("/list", c.ClusterPermissionList)        // 获取集群权限列表
		clusterPerm.POST("/batch", c.BatchClusterPermissionCreate) // 批量分配
	}

	// 用户RBAC信息
	user := router.Group("/user")
	{
		user.GET("/info", c.UserRBACInfo)            // 获取用户RBAC信息
		user.GET("/clusters", c.UserAccessibleClusters) // 获取用户可访问集群
	}

	// 权限检查
	router.GET("/check", c.CheckPermission) // 检查权限
}
