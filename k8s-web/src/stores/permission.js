/**
 * 权限状态管理 - 参考 Rancher/Kuboard/KubeSphere 设计
 * 三层权限模型：平台角色 → 集群权限 → 命名空间权限
 */
import { reactive, computed, readonly } from 'vue'
import { getUserPermissions } from '@/api/rbac'

// ==================== 权限常量定义 ====================

/**
 * 平台角色类型
 */
export const ROLE_TYPES = {
  SUPER_ADMIN: 'super_admin',       // 超级管理员
  PLATFORM_ADMIN: 'platform_admin', // 平台管理员
  CLUSTER_ADMIN: 'cluster_admin',   // 集群管理员
  DEVELOPER: 'developer',           // 开发者
  VIEWER: 'viewer',                 // 只读用户
  CUSTOM: 'custom'                  // 自定义角色
}

/**
 * 操作权限类型
 */
export const ACTIONS = {
  VIEW: 'view',
  CREATE: 'create',
  UPDATE: 'update',
  DELETE: 'delete',
  EXEC: 'exec',      // Pod 终端
  MANAGE: 'manage'   // 管理权限（如修改配置）
}

/**
 * 资源类型
 */
export const RESOURCES = {
  CLUSTER: 'cluster',
  NAMESPACE: 'namespace',
  DEPLOYMENT: 'deployment',
  STATEFULSET: 'statefulset',
  DAEMONSET: 'daemonset',
  JOB: 'job',
  CRONJOB: 'cronjob',
  POD: 'pod',
  SERVICE: 'service',
  INGRESS: 'ingress',
  CONFIGMAP: 'configmap',
  SECRET: 'secret',
  PVC: 'pvc',
  USER: 'user',
  ROLE: 'role',
  PIPELINE: 'pipeline',
  IMAGE: 'image'
}

/**
 * 菜单权限映射
 * 定义每个菜单需要的最小权限
 */
export const MENU_PERMISSIONS = {
  // 平台管理
  '/clusters': { roles: ['*'] },  // 所有角色可见
  '/platform/health': { roles: ['super_admin', 'platform_admin'] },
  '/platform/settings': { roles: ['super_admin', 'platform_admin'] },
  
  // 安全管理（精简后的5个模块）
  '/security/users': { roles: ['super_admin', 'platform_admin'] },
  '/security/roles': { roles: ['super_admin', 'platform_admin'] },
  '/security/authorization': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/security/audit': { roles: ['super_admin', 'platform_admin'] },
  '/security/diagnosis': { roles: ['*'] },
  
  // 兼容旧路径
  '/users': { roles: ['super_admin', 'platform_admin'] },
  '/rbac': { roles: ['super_admin', 'platform_admin'] },
  '/security/rbac/serviceaccounts': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/security/rbac/roles': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/security/rbac/rolebindings': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/security/rbac/permission-check': { roles: ['*'] },
  
  // CI/CD
  '/cicd/pipelines': { roles: ['super_admin', 'platform_admin', 'developer'] },
  '/cicd/releases': { roles: ['super_admin', 'platform_admin', 'developer'] },
  '/cicd/templates': { roles: ['super_admin', 'platform_admin'] },
  '/cicd/approvals': { roles: ['super_admin', 'platform_admin'] },
  
  // 镜像管理
  '/images/repositories': { roles: ['super_admin', 'platform_admin'] },
  '/images/browse': { roles: ['*'] },
  '/images/cleanup': { roles: ['super_admin', 'platform_admin'] },
  
  // K8s 资源（需要集群权限）
  '/c/:clusterId/nodes': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/c/:clusterId/namespaces': { roles: ['super_admin', 'platform_admin', 'cluster_admin'] },
  '/c/:clusterId/workloads': { roles: ['*'], requireCluster: true },
  '/c/:clusterId/networking': { roles: ['*'], requireCluster: true },
  '/c/:clusterId/config': { roles: ['*'], requireCluster: true },
  '/c/:clusterId/storage': { roles: ['*'], requireCluster: true }
}

// ==================== 权限状态 ====================

const state = reactive({
  // 是否已加载权限
  loaded: false,
  loading: false,
  
  // 用户基本信息
  userId: 0,
  username: '',
  
  // 是否超级管理员（拥有所有权限）
  isSuperAdmin: false,
  
  // 平台角色列表
  roles: [],
  
  // 集群权限映射 { clusterId: { can_view, can_create, can_update, can_delete, can_exec, namespaces } }
  clusterPermissions: {},
  
  // 可访问的集群 ID 列表
  accessibleClusterIds: [],
  
  // 权限定义列表（从后端获取）
  permissions: []
})

// ==================== 计算属性 ====================

/**
 * 获取用户的角色类型列表
 * 包含平台角色和集群权限中的角色类型
 */
const roleTypes = computed(() => {
  // 平台角色
  const platformRoles = state.roles.map(r => r.role_type || r.name)
  
  // 集群权限中的角色类型
  const clusterRoles = Object.values(state.clusterPermissions)
    .map(p => p.role_type)
    .filter(Boolean)
  
  // 合并去重
  return [...new Set([...platformRoles, ...clusterRoles])]
})

/**
 * 是否为管理员角色（包含 super_admin 或 platform_admin）
 */
const isAdmin = computed(() => {
  return state.isSuperAdmin || 
         roleTypes.value.includes(ROLE_TYPES.SUPER_ADMIN) ||
         roleTypes.value.includes(ROLE_TYPES.PLATFORM_ADMIN)
})

/**
 * 是否为集群管理员
 */
const isClusterAdmin = computed(() => {
  return isAdmin.value || roleTypes.value.includes(ROLE_TYPES.CLUSTER_ADMIN)
})

/**
 * 是否为开发者（包含开发者及以上角色）
 */
const isDeveloper = computed(() => {
  return isClusterAdmin.value || roleTypes.value.includes(ROLE_TYPES.DEVELOPER)
})

// ==================== 权限检查方法 ====================

/**
 * 检查是否有访问某个菜单的权限
 * @param {string} path 菜单路径
 * @returns {boolean}
 */
function canAccessMenu(path) {
  // 超级管理员可以访问所有菜单
  if (state.isSuperAdmin) return true
  
  // 查找菜单权限配置
  const menuPerm = MENU_PERMISSIONS[path]
  if (!menuPerm) return true // 未配置则默认允许
  
  // 检查角色
  if (menuPerm.roles.includes('*')) return true
  
  return menuPerm.roles.some(role => roleTypes.value.includes(role))
}

/**
 * 检查是否有访问某个集群的权限
 * @param {number|string} clusterId 集群ID
 * @param {string} action 操作类型 (view/create/update/delete/exec)
 * @returns {boolean}
 */
function canAccessCluster(clusterId, action = ACTIONS.VIEW) {
  // 超级管理员可以访问所有集群
  if (state.isSuperAdmin) return true
  
  const perm = state.clusterPermissions[clusterId]
  if (!perm) return false
  
  switch (action) {
    case ACTIONS.VIEW: return perm.can_view
    case ACTIONS.CREATE: return perm.can_create
    case ACTIONS.UPDATE: return perm.can_update
    case ACTIONS.DELETE: return perm.can_delete
    case ACTIONS.EXEC: return perm.can_exec
    default: return perm.can_view
  }
}

/**
 * 检查是否有访问某个命名空间的权限
 * @param {number|string} clusterId 集群ID
 * @param {string} namespace 命名空间名称
 * @returns {boolean}
 */
function canAccessNamespace(clusterId, namespace) {
  // 超级管理员可以访问所有命名空间
  if (state.isSuperAdmin) return true
  
  const perm = state.clusterPermissions[clusterId]
  if (!perm) return false
  
  // 如果没有限制命名空间，则可以访问所有
  if (!perm.namespaces || perm.namespaces.length === 0) return true
  if (perm.namespaces.includes('*')) return true
  
  return perm.namespaces.includes(namespace)
}

/**
 * 获取用户在某个集群中可访问的命名空间列表
 * @param {number|string} clusterId 集群ID
 * @returns {string[]} 命名空间列表，空数组表示所有
 */
function getAccessibleNamespaces(clusterId) {
  // 超级管理员可以访问所有命名空间
  if (state.isSuperAdmin) return []
  
  const perm = state.clusterPermissions[clusterId]
  if (!perm) return ['__none__'] // 返回特殊标记，表示无权限
  
  // 如果没有限制，返回空数组（表示所有）
  if (!perm.namespaces || perm.namespaces.length === 0) return []
  if (perm.namespaces.includes('*')) return []
  
  return perm.namespaces
}

/**
 * 检查是否有某个资源的操作权限
 * @param {string} resource 资源类型
 * @param {string} action 操作类型
 * @param {number|string} clusterId 集群ID（可选）
 * @returns {boolean}
 */
function hasPermission(resource, action, clusterId = null) {
  // 超级管理员拥有所有权限
  if (state.isSuperAdmin) return true
  
  // 如果指定了集群，检查集群权限
  if (clusterId) {
    if (!canAccessCluster(clusterId, action)) return false
  }
  
  // 检查角色权限
  // 只读用户只能查看
  if (roleTypes.value.length === 1 && roleTypes.value[0] === ROLE_TYPES.VIEWER) {
    return action === ACTIONS.VIEW
  }
  
  // 开发者不能删除集群级资源
  if (!isClusterAdmin.value && action === ACTIONS.DELETE) {
    const clusterResources = [RESOURCES.CLUSTER, RESOURCES.NAMESPACE]
    if (clusterResources.includes(resource)) return false
  }
  
  // 其他情况根据集群权限决定
  return true
}

/**
 * 过滤命名空间列表，只返回用户有权限访问的
 * @param {number|string} clusterId 集群ID
 * @param {Array} namespaces 原始命名空间列表
 * @returns {Array} 过滤后的命名空间列表
 */
function filterNamespaces(clusterId, namespaces) {
  // 超级管理员可以看到所有
  if (state.isSuperAdmin) return namespaces
  
  const accessible = getAccessibleNamespaces(clusterId)
  
  // 如果没有限制，返回所有
  if (accessible.length === 0) return namespaces
  
  // 过滤
  return namespaces.filter(ns => {
    const name = typeof ns === 'string' ? ns : (ns.name || ns.metadata?.name)
    return accessible.includes(name)
  })
}

// ==================== 状态管理方法 ====================

/**
 * 加载用户权限信息
 * @param {boolean} force 是否强制刷新
 */
async function loadPermissions(force = false) {
  if (state.loaded && !force) return
  if (state.loading) return
  
  state.loading = true
  
  try {
    const res = await getUserPermissions()
    const data = res.data || res
    
    // 更新状态
    state.userId = data.user_id || 0
    state.username = data.username || ''
    state.isSuperAdmin = data.is_super_admin || false
    state.roles = data.roles || []
    state.permissions = data.permissions || []
    
    // 解析集群权限
    const clusterPerms = data.cluster_permissions || []
    state.clusterPermissions = {}
    state.accessibleClusterIds = []
    
    clusterPerms.forEach(cp => {
      // 解析命名空间 JSON
      let namespaces = []
      if (cp.namespaces) {
        try {
          namespaces = typeof cp.namespaces === 'string' 
            ? JSON.parse(cp.namespaces) 
            : cp.namespaces
        } catch (e) {
          namespaces = []
        }
      }
      
      state.clusterPermissions[cp.cluster_id] = {
        can_view: cp.can_view,
        can_create: cp.can_create,
        can_update: cp.can_update,
        can_delete: cp.can_delete,
        can_exec: cp.can_exec,
        role_type: cp.role_type,
        namespaces: namespaces,
        expire_at: cp.expire_at
      }
      
      if (cp.can_view) {
        state.accessibleClusterIds.push(cp.cluster_id)
      }
    })
    
    state.loaded = true
    console.log('[Permission] 权限加载成功', { 
      userId: state.userId,
      isSuperAdmin: state.isSuperAdmin,
      roles: state.roles.map(r => r.name),
      clusters: state.accessibleClusterIds
    })
  } catch (e) {
    console.error('[Permission] 加载权限失败', e)
    // 设置默认权限（只读）
    state.loaded = true
  } finally {
    state.loading = false
  }
}

/**
 * 清除权限信息（退出登录时调用）
 */
function clearPermissions() {
  state.loaded = false
  state.loading = false
  state.userId = 0
  state.username = ''
  state.isSuperAdmin = false
  state.roles = []
  state.clusterPermissions = {}
  state.accessibleClusterIds = []
  state.permissions = []
}

/**
 * 初始化权限（登录成功后调用）
 * @param {Object} userInfo 用户信息（从登录响应中获取）
 */
function initPermissions(userInfo) {
  if (!userInfo) return
  
  state.userId = userInfo.user_id || userInfo.id || 0
  state.username = userInfo.username || ''
  state.isSuperAdmin = userInfo.is_super_admin || false
  state.roles = userInfo.roles || []
  
  // 如果登录响应中包含权限信息，直接使用
  if (userInfo.cluster_permissions) {
    const clusterPerms = userInfo.cluster_permissions
    state.clusterPermissions = {}
    state.accessibleClusterIds = []
    
    clusterPerms.forEach(cp => {
      let namespaces = []
      if (cp.namespaces) {
        try {
          namespaces = typeof cp.namespaces === 'string' 
            ? JSON.parse(cp.namespaces) 
            : cp.namespaces
        } catch (e) {
          namespaces = []
        }
      }
      
      state.clusterPermissions[cp.cluster_id] = {
        can_view: cp.can_view,
        can_create: cp.can_create,
        can_update: cp.can_update,
        can_delete: cp.can_delete,
        can_exec: cp.can_exec,
        role_type: cp.role_type,
        namespaces: namespaces
      }
      
      if (cp.can_view) {
        state.accessibleClusterIds.push(cp.cluster_id)
      }
    })
    
    state.loaded = true
  }
}

// ==================== 导出 ====================

export const permissionStore = {
  // 状态（只读）
  state: readonly(state),
  
  // 计算属性
  roleTypes,
  isAdmin,
  isClusterAdmin,
  isDeveloper,
  
  // 权限检查方法
  canAccessMenu,
  canAccessCluster,
  canAccessNamespace,
  getAccessibleNamespaces,
  hasPermission,
  filterNamespaces,
  
  // 状态管理方法
  loadPermissions,
  clearPermissions,
  initPermissions
}

export default permissionStore
