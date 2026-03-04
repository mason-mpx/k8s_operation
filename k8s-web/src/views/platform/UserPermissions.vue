<template>
  <div class="permission-management">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-content">
        <h1>
          <span class="header-icon">🛡️</span>
          用户授权管理
        </h1>
        <p class="header-desc">配置用户的集群权限和命名空间访问范围，支持精细化的 RBAC 权限控制</p>
      </div>
      <div class="header-actions">
        <button class="btn btn-primary" @click="showAssignModal = true">
          <span>➕</span> 新增授权
        </button>
        <button class="btn btn-secondary" @click="refresh" :disabled="loading">
          {{ loading ? '加载中...' : '🔄 刷新' }}
        </button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-grid">
      <div class="stat-card users">
        <div class="stat-icon">👥</div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.totalUsers }}</div>
          <div class="stat-label">已授权用户</div>
        </div>
      </div>
      <div class="stat-card clusters">
        <div class="stat-icon">🌐</div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.totalClusters }}</div>
          <div class="stat-label">集群总数</div>
        </div>
      </div>
      <div class="stat-card permissions">
        <div class="stat-icon">🔐</div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.totalPermissions }}</div>
          <div class="stat-label">授权记录</div>
        </div>
      </div>
      <div class="stat-card namespaces">
        <div class="stat-icon">📦</div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.nsRestricted }}</div>
          <div class="stat-label">命名空间限制</div>
        </div>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="search-box">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="搜索用户名..."
          @input="onSearchInput"
        />
      </div>
      <div class="filter-dropdown">
        <select v-model="clusterFilter">
          <option value="">所有集群</option>
          <option v-for="c in clusters" :key="c.id" :value="c.id">
            {{ c.cluster_name }}
          </option>
        </select>
      </div>
      <div class="filter-dropdown">
        <select v-model="roleFilter">
          <option value="">所有角色</option>
          <option value="cluster_admin">集群管理员</option>
          <option value="developer">开发者</option>
          <option value="viewer">只读用户</option>
        </select>
      </div>
    </div>

    <!-- 用户授权列表 -->
    <div class="table-container">
      <div v-if="loading" class="loading-state">
        <div class="loading-spinner"></div>
        <span>加载中...</span>
      </div>

      <table v-else class="permission-table">
        <thead>
          <tr>
            <th>用户</th>
            <th>集群</th>
            <th>角色</th>
            <th>权限</th>
            <th>命名空间限制</th>
            <th>过期时间</th>
            <th style="width: 180px;">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="perm in filteredPermissions" :key="perm.id" class="permission-row">
            <td>
              <div class="user-info">
                <span class="user-avatar">{{ perm.username?.charAt(0)?.toUpperCase() || 'U' }}</span>
                <span class="user-name">{{ perm.username }}</span>
              </div>
            </td>
            <td>
              <div class="cluster-badge">
                <span class="cluster-icon">🌐</span>
                {{ perm.cluster_name }}
              </div>
            </td>
            <td>
              <span class="role-badge" :class="perm.role_type">
                {{ getRoleLabel(perm.role_type) }}
              </span>
            </td>
            <td>
              <div class="permission-badges">
                <span v-if="perm.can_view" class="perm-badge view">查看</span>
                <span v-if="perm.can_create" class="perm-badge create">创建</span>
                <span v-if="perm.can_update" class="perm-badge update">更新</span>
                <span v-if="perm.can_delete" class="perm-badge delete">删除</span>
                <span v-if="perm.can_exec" class="perm-badge exec">执行</span>
              </div>
            </td>
            <td>
              <div v-if="!perm.namespaces || perm.namespaces.length === 0" class="ns-all">
                <span class="ns-icon">✅</span> 所有命名空间
              </div>
              <div v-else class="ns-limited">
                <span class="ns-icon">📋</span>
                <span class="ns-count">{{ perm.namespaces.length }} 个命名空间</span>
                <div class="ns-tooltip">
                  <div v-for="ns in perm.namespaces" :key="ns" class="ns-item">{{ ns }}</div>
                </div>
              </div>
            </td>
            <td>
              <span v-if="!perm.expire_at || perm.expire_at === '0001-01-01T00:00:00Z'" class="expire-never">
                永不过期
              </span>
              <span v-else class="expire-date" :class="{ expired: isExpired(perm.expire_at) }">
                {{ formatDate(perm.expire_at) }}
              </span>
            </td>
            <td>
              <div class="action-buttons">
                <button class="btn-action edit" @click="editPermission(perm)" title="编辑">
                  ✏️ 编辑
                </button>
                <button class="btn-action delete" @click="deletePermission(perm)" title="删除">
                  🗑️ 删除
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredPermissions.length === 0">
            <td colspan="7" class="empty-state">
              <div class="empty-icon">📭</div>
              <div class="empty-text">暂无授权记录</div>
              <button class="btn btn-primary btn-sm" @click="showAssignModal = true">
                ➕ 添加第一条授权
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- 分页 -->
    <div v-if="filteredPermissions.length > 0" class="pagination">
      <span class="pagination-info">共 {{ filteredPermissions.length }} 条记录</span>
    </div>

    <!-- 新增/编辑授权弹窗 -->
    <div v-if="showAssignModal" class="modal-overlay" @click.self="closeAssignModal">
      <div class="modal-content modal-large">
        <div class="modal-header">
          <h3>{{ editMode ? '✏️ 编辑授权' : '➕ 新增授权' }}</h3>
          <button class="close-btn" @click="closeAssignModal">×</button>
        </div>
        <div class="modal-body">
          <div class="form-section">
            <h4>基础信息</h4>
            <div class="form-row">
              <div class="form-group">
                <label>选择用户 <span class="required">*</span></label>
                <select v-model="assignForm.user_id" :disabled="editMode" class="form-select">
                  <option value="">请选择用户</option>
                  <option v-for="u in users" :key="u.id" :value="u.id">
                    {{ u.username }}
                  </option>
                </select>
              </div>
              <div class="form-group">
                <label>选择集群 <span class="required">*</span></label>
                <select v-model="assignForm.cluster_id" :disabled="editMode" class="form-select" @change="onClusterChange">
                  <option value="">请选择集群</option>
                  <option v-for="c in clusters" :key="c.id" :value="c.id">
                    {{ c.cluster_name }}
                  </option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>角色类型 <span class="required">*</span></label>
                <select v-model="assignForm.role_type" class="form-select" @change="onRoleChange">
                  <option value="">请选择角色</option>
                  <option value="cluster_admin">集群管理员（完全权限）</option>
                  <option value="developer">开发者（可操作资源）</option>
                  <option value="viewer">只读用户（仅查看）</option>
                  <option value="custom">自定义权限</option>
                </select>
              </div>
              <div class="form-group">
                <label>过期时间</label>
                <input v-model="assignForm.expire_at" type="datetime-local" class="form-input" />
                <span class="form-hint">留空表示永不过期</span>
              </div>
            </div>
          </div>

          <div class="form-section" v-if="assignForm.role_type === 'custom'">
            <h4>自定义权限</h4>
            <div class="permission-checkboxes">
              <label class="checkbox-item">
                <input type="checkbox" v-model="assignForm.can_view" />
                <span class="checkbox-label">查看 (View)</span>
              </label>
              <label class="checkbox-item">
                <input type="checkbox" v-model="assignForm.can_create" />
                <span class="checkbox-label">创建 (Create)</span>
              </label>
              <label class="checkbox-item">
                <input type="checkbox" v-model="assignForm.can_update" />
                <span class="checkbox-label">更新 (Update)</span>
              </label>
              <label class="checkbox-item">
                <input type="checkbox" v-model="assignForm.can_delete" />
                <span class="checkbox-label">删除 (Delete)</span>
              </label>
              <label class="checkbox-item">
                <input type="checkbox" v-model="assignForm.can_exec" />
                <span class="checkbox-label">执行 (Exec)</span>
              </label>
            </div>
          </div>

          <div class="form-section">
            <h4>
              命名空间限制
              <span class="section-hint">（不选择表示允许访问所有命名空间）</span>
            </h4>
            <div v-if="loadingNamespaces" class="loading-inline">
              加载命名空间中...
            </div>
            <div v-else-if="clusterNamespaces.length === 0" class="empty-hint">
              请先选择集群
            </div>
            <div v-else class="namespace-selector">
              <div class="ns-actions">
                <button type="button" class="btn btn-sm btn-secondary" @click="selectAllNamespaces">
                  全选
                </button>
                <button type="button" class="btn btn-sm btn-secondary" @click="clearNamespaces">
                  清空
                </button>
                <span class="ns-selected-count">
                  已选择 {{ assignForm.namespaces.length }} / {{ clusterNamespaces.length }}
                </span>
              </div>
              <div class="namespace-grid">
                <label
                  v-for="ns in clusterNamespaces"
                  :key="ns"
                  class="namespace-item"
                  :class="{ selected: assignForm.namespaces.includes(ns) }"
                >
                  <input
                    type="checkbox"
                    :value="ns"
                    v-model="assignForm.namespaces"
                  />
                  <span class="ns-name">{{ ns }}</span>
                </label>
              </div>
            </div>
          </div>

          <div v-if="formError" class="error-box">{{ formError }}</div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary" @click="closeAssignModal" :disabled="saving">
            取消
          </button>
          <button
            class="btn btn-primary"
            @click="submitAssign"
            :disabled="saving || !assignForm.user_id || !assignForm.cluster_id || !assignForm.role_type"
          >
            {{ saving ? '保存中...' : (editMode ? '保存修改' : '确认授权') }}
          </button>
        </div>
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteModal" class="modal-overlay" @click.self="showDeleteModal = false">
      <div class="modal-content modal-small">
        <div class="modal-header danger">
          <h3>⚠️ 删除授权</h3>
          <button class="close-btn" @click="showDeleteModal = false">×</button>
        </div>
        <div class="modal-body">
          <p class="delete-warning">
            确定要删除用户 <strong>{{ deleteTarget?.username }}</strong> 
            在集群 <strong>{{ deleteTarget?.cluster_name }}</strong> 的授权吗？
          </p>
          <p class="delete-hint">删除后该用户将无法访问此集群的任何资源。</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary" @click="showDeleteModal = false">取消</button>
          <button class="btn btn-danger" @click="confirmDelete" :disabled="deleting">
            {{ deleting ? '删除中...' : '确认删除' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import { getUserList } from '@/api/user'
import { getClusterList } from '@/api/cluster'
import namespaceApi from '@/api/cluster/config/namespace'
import {
  getClusterPermissionList,
  createClusterPermission,
  updateClusterPermission,
  deleteClusterPermission
} from '@/api/rbac'
import { useClusterStore } from '@/stores/cluster'

const clusterStore = useClusterStore()

// 状态
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const loadingNamespaces = ref(false)

// 数据
const users = ref([])
const clusters = ref([])
const permissions = ref([])
const clusterNamespaces = ref([])

// 筛选
const searchQuery = ref('')
const clusterFilter = ref('')
const roleFilter = ref('')

// 弹窗
const showAssignModal = ref(false)
const showDeleteModal = ref(false)
const editMode = ref(false)
const deleteTarget = ref(null)
const formError = ref('')

// 表单
const assignForm = ref({
  id: 0,
  user_id: '',
  cluster_id: '',
  role_type: '',
  can_view: true,
  can_create: false,
  can_update: false,
  can_delete: false,
  can_exec: false,
  namespaces: [],
  expire_at: ''
})

// 统计
const stats = computed(() => {
  const userSet = new Set(permissions.value.map(p => p.user_id))
  const nsRestricted = permissions.value.filter(p => p.namespaces && p.namespaces.length > 0).length
  return {
    totalUsers: userSet.size,
    totalClusters: clusters.value.length,
    totalPermissions: permissions.value.length,
    nsRestricted
  }
})

// 过滤后的权限列表
const filteredPermissions = computed(() => {
  return permissions.value.filter(p => {
    const matchSearch = !searchQuery.value || 
      p.username?.toLowerCase().includes(searchQuery.value.toLowerCase())
    const matchCluster = !clusterFilter.value || p.cluster_id === clusterFilter.value
    const matchRole = !roleFilter.value || p.role_type === roleFilter.value
    return matchSearch && matchCluster && matchRole
  })
})

// 角色标签
const getRoleLabel = (role) => {
  const labels = {
    cluster_admin: '集群管理员',
    developer: '开发者',
    viewer: '只读用户',
    custom: '自定义'
  }
  return labels[role] || role
}

// 日期格式化
const formatDate = (dateStr) => {
  if (!dateStr || dateStr === '0001-01-01T00:00:00Z') return '永不过期'
  return dateStr.replace('T', ' ').split('.')[0].substring(0, 16)
}

// 检查是否过期
const isExpired = (dateStr) => {
  if (!dateStr || dateStr === '0001-01-01T00:00:00Z') return false
  return new Date(dateStr) < new Date()
}

// 加载用户列表
const loadUsers = async () => {
  try {
    const res = await getUserList({ page: 1, limit: 1000 })
    if (res.code === 0 && res.data) {
      users.value = res.data.list || res.data || []
    }
  } catch (e) {
    console.error('加载用户失败:', e)
  }
}

// 加载集群列表
const loadClusters = async () => {
  try {
    const res = await getClusterList({ page: 1, limit: 100 })
    if (res.code === 0 && res.data) {
      clusters.value = res.data.list || res.data || []
    }
  } catch (e) {
    console.error('加载集群失败:', e)
  }
}

// 加载权限列表
const loadPermissions = async () => {
  loading.value = true
  try {
    const res = await getClusterPermissionList({ page: 1, limit: 1000 })
    if (res.code === 0 && res.data) {
      const list = Array.isArray(res.data.list) ? res.data.list : (Array.isArray(res.data) ? res.data : [])
      // 补充用户名和集群名
      permissions.value = list.map(p => {
        const user = users.value.find(u => u.id === p.user_id)
        const cluster = clusters.value.find(c => c.id === p.cluster_id)
        // 解析 namespaces JSON
        let namespaces = []
        if (p.namespaces) {
          try {
            namespaces = typeof p.namespaces === 'string' ? JSON.parse(p.namespaces) : p.namespaces
          } catch (e) {
            namespaces = []
          }
        }
        return {
          ...p,
          username: user?.username || `用户${p.user_id}`,
          cluster_name: cluster?.cluster_name || `集群${p.cluster_id}`,
          namespaces
        }
      })
    }
  } catch (e) {
    console.error('加载权限失败:', e)
    Message.error('加载权限列表失败')
  } finally {
    loading.value = false
  }
}

// 加载集群命名空间
const loadClusterNamespaces = async (clusterId) => {
  if (!clusterId) {
    clusterNamespaces.value = []
    return
  }
  
  loadingNamespaces.value = true
  try {
    // 临时设置集群 ID
    const originalCluster = clusterStore.current
    const targetCluster = clusters.value.find(c => c.id === clusterId)
    if (targetCluster) {
      clusterStore.setCurrent(targetCluster)
    }
    
    const res = await namespaceApi.list({ page: 1, limit: 500 })
    const rawList = res?.data?.list || res?.data || []
    const list = Array.isArray(rawList) ? rawList : []
    clusterNamespaces.value = list.map(ns => 
      typeof ns === 'string' ? ns : (ns?.metadata?.name || ns?.name || ns)
    ).filter(Boolean)
    
    // 恢复原集群
    if (originalCluster) {
      clusterStore.setCurrent(originalCluster)
    }
  } catch (e) {
    console.error('加载命名空间失败:', e)
    clusterNamespaces.value = []
  } finally {
    loadingNamespaces.value = false
  }
}

// 集群变化时加载命名空间
const onClusterChange = () => {
  assignForm.value.namespaces = []
  loadClusterNamespaces(assignForm.value.cluster_id)
}

// 角色变化时设置默认权限
const onRoleChange = () => {
  const role = assignForm.value.role_type
  if (role === 'cluster_admin') {
    assignForm.value.can_view = true
    assignForm.value.can_create = true
    assignForm.value.can_update = true
    assignForm.value.can_delete = true
    assignForm.value.can_exec = true
  } else if (role === 'developer') {
    assignForm.value.can_view = true
    assignForm.value.can_create = true
    assignForm.value.can_update = true
    assignForm.value.can_delete = false
    assignForm.value.can_exec = true
  } else if (role === 'viewer') {
    assignForm.value.can_view = true
    assignForm.value.can_create = false
    assignForm.value.can_update = false
    assignForm.value.can_delete = false
    assignForm.value.can_exec = false
  }
}

// 全选命名空间
const selectAllNamespaces = () => {
  assignForm.value.namespaces = [...clusterNamespaces.value]
}

// 清空命名空间
const clearNamespaces = () => {
  assignForm.value.namespaces = []
}

// 搜索防抖
let searchTimer = null
const onSearchInput = () => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {}, 300)
}

// 刷新
const refresh = async () => {
  await Promise.all([loadUsers(), loadClusters()])
  await loadPermissions()
}

// 关闭弹窗
const closeAssignModal = () => {
  showAssignModal.value = false
  editMode.value = false
  formError.value = ''
  assignForm.value = {
    id: 0,
    user_id: '',
    cluster_id: '',
    role_type: '',
    can_view: true,
    can_create: false,
    can_update: false,
    can_delete: false,
    can_exec: false,
    namespaces: [],
    expire_at: ''
  }
  clusterNamespaces.value = []
}

// 编辑权限
const editPermission = (perm) => {
  editMode.value = true
  assignForm.value = {
    id: perm.id,
    user_id: perm.user_id,
    cluster_id: perm.cluster_id,
    role_type: perm.role_type || 'custom',
    can_view: perm.can_view,
    can_create: perm.can_create,
    can_update: perm.can_update,
    can_delete: perm.can_delete,
    can_exec: perm.can_exec,
    namespaces: perm.namespaces || [],
    expire_at: perm.expire_at && perm.expire_at !== '0001-01-01T00:00:00Z' 
      ? perm.expire_at.substring(0, 16) 
      : ''
  }
  loadClusterNamespaces(perm.cluster_id)
  showAssignModal.value = true
}

// 删除权限
const deletePermission = (perm) => {
  deleteTarget.value = perm
  showDeleteModal.value = true
}

// 确认删除
const confirmDelete = async () => {
  if (!deleteTarget.value) return
  
  deleting.value = true
  try {
    const res = await deleteClusterPermission(deleteTarget.value.id)
    if (res.code === 0) {
      Message.success('删除成功')
      showDeleteModal.value = false
      deleteTarget.value = null
      await loadPermissions()
    } else {
      Message.error(res.msg || '删除失败')
    }
  } catch (e) {
    Message.error(e?.msg || '删除失败')
  } finally {
    deleting.value = false
  }
}

// 提交授权
const submitAssign = async () => {
  formError.value = ''
  
  if (!assignForm.value.user_id || !assignForm.value.cluster_id || !assignForm.value.role_type) {
    formError.value = '请填写必填项'
    return
  }
  
  saving.value = true
  try {
    const data = {
      user_id: Number(assignForm.value.user_id),
      cluster_id: Number(assignForm.value.cluster_id),
      role_type: assignForm.value.role_type,
      can_view: assignForm.value.can_view,
      can_create: assignForm.value.can_create,
      can_update: assignForm.value.can_update,
      can_delete: assignForm.value.can_delete,
      can_exec: assignForm.value.can_exec,
      namespaces: JSON.stringify(assignForm.value.namespaces),
      expire_at: assignForm.value.expire_at || null
    }
    
    let res
    if (editMode.value) {
      data.id = assignForm.value.id
      res = await updateClusterPermission(data)
    } else {
      res = await createClusterPermission(data)
    }
    
    if (res.code === 0) {
      Message.success(editMode.value ? '修改成功' : '授权成功')
      closeAssignModal()
      await loadPermissions()
    } else {
      formError.value = res.msg || '操作失败'
    }
  } catch (e) {
    formError.value = e?.msg || '操作失败'
  } finally {
    saving.value = false
  }
}

// 初始化
onMounted(async () => {
  await refresh()
})
</script>

<style scoped>
/* ==================== 大厂风格样式 ==================== */

.permission-management {
  padding: 0;
  min-height: 100%;
}

/* 页面头部 */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 16px;
}

.header-content h1 {
  font-size: 28px;
  font-weight: 700;
  color: #1e293b;
  margin: 0 0 8px 0;
  display: flex;
  align-items: center;
  gap: 10px;
}

.header-icon {
  font-size: 32px;
}

.header-desc {
  color: #64748b;
  font-size: 14px;
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 10px;
}

/* 统计卡片 */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  transition: all 0.2s;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.stat-icon {
  font-size: 36px;
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}

.stat-card.users .stat-icon {
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
}

.stat-card.clusters .stat-icon {
  background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
}

.stat-card.permissions .stat-icon {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
}

.stat-card.namespaces .stat-icon {
  background: linear-gradient(135deg, #ede9fe 0%, #ddd6fe 100%);
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: #1e293b;
}

.stat-label {
  font-size: 13px;
  color: #64748b;
}

/* 筛选栏 */
.filter-bar {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.search-box {
  flex: 1;
  min-width: 200px;
  max-width: 300px;
}

.search-box input {
  width: 100%;
  padding: 10px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.2s;
}

.search-box input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.filter-dropdown select {
  padding: 10px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  cursor: pointer;
}

/* 表格 */
.table-container {
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  overflow: hidden;
}

.permission-table {
  width: 100%;
  border-collapse: collapse;
}

.permission-table thead {
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
}

.permission-table th {
  padding: 14px 16px;
  text-align: left;
  font-weight: 600;
  font-size: 13px;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
}

.permission-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.15s;
}

.permission-table tbody tr:hover {
  background: #f8fafc;
}

.permission-table td {
  padding: 14px 16px;
  font-size: 14px;
  color: #334155;
}

/* 用户信息 */
.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
}

.user-name {
  font-weight: 500;
}

/* 集群徽章 */
.cluster-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  background: #f1f5f9;
  border-radius: 6px;
  font-size: 13px;
}

.cluster-icon {
  font-size: 14px;
}

/* 角色徽章 */
.role-badge {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.role-badge.cluster_admin {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  color: #92400e;
}

.role-badge.developer {
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
  color: #1e40af;
}

.role-badge.viewer {
  background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
  color: #374151;
}

.role-badge.custom {
  background: linear-gradient(135deg, #ede9fe 0%, #ddd6fe 100%);
  color: #5b21b6;
}

/* 权限徽章 */
.permission-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.perm-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 500;
}

.perm-badge.view { background: #d1fae5; color: #065f46; }
.perm-badge.create { background: #dbeafe; color: #1e40af; }
.perm-badge.update { background: #fef3c7; color: #92400e; }
.perm-badge.delete { background: #fee2e2; color: #991b1b; }
.perm-badge.exec { background: #ede9fe; color: #5b21b6; }

/* 命名空间 */
.ns-all {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #059669;
  font-size: 13px;
}

.ns-limited {
  position: relative;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #7c3aed;
  font-size: 13px;
  cursor: pointer;
}

.ns-tooltip {
  position: absolute;
  top: 100%;
  left: 0;
  z-index: 100;
  min-width: 180px;
  max-height: 200px;
  overflow-y: auto;
  padding: 8px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  display: none;
}

.ns-limited:hover .ns-tooltip {
  display: block;
}

.ns-item {
  padding: 4px 8px;
  font-size: 12px;
  color: #334155;
  border-bottom: 1px solid #f1f5f9;
}

.ns-item:last-child {
  border-bottom: none;
}

/* 过期时间 */
.expire-never {
  color: #059669;
  font-size: 13px;
}

.expire-date {
  font-size: 13px;
  color: #64748b;
}

.expire-date.expired {
  color: #dc2626;
}

/* 操作按钮 */
.action-buttons {
  display: flex;
  gap: 8px;
}

.btn-action {
  padding: 6px 12px;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-action.edit {
  background: #dbeafe;
  color: #1e40af;
}

.btn-action.edit:hover {
  background: #bfdbfe;
}

.btn-action.delete {
  background: #fee2e2;
  color: #991b1b;
}

.btn-action.delete:hover {
  background: #fecaca;
}

/* 空状态 */
.empty-state {
  text-align: center;
  padding: 60px 20px;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-text {
  color: #64748b;
  margin-bottom: 20px;
}

/* 分页 */
.pagination {
  display: flex;
  justify-content: flex-end;
  padding: 16px 20px;
  background: white;
  border-radius: 0 0 12px 12px;
}

.pagination-info {
  color: #64748b;
  font-size: 14px;
}

/* 按钮 */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 10px 18px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  color: white;
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
}

.btn-primary:hover {
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  transform: translateY(-1px);
}

.btn-secondary {
  background: #f1f5f9;
  color: #475569;
}

.btn-secondary:hover {
  background: #e2e8f0;
}

.btn-danger {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  color: white;
}

.btn-sm {
  padding: 6px 12px;
  font-size: 13px;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e2e8f0;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-inline {
  color: #64748b;
  font-size: 14px;
  padding: 20px;
}

/* 弹窗 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 12px;
  max-height: 90vh;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: slideUp 0.3s ease;
}

.modal-large {
  width: 700px;
  max-width: 95vw;
}

.modal-small {
  width: 450px;
  max-width: 95vw;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  border-bottom: 1px solid #e2e8f0;
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
}

.modal-header.danger {
  background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #64748b;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}

.close-btn:hover {
  background: #e2e8f0;
}

.modal-body {
  padding: 24px;
  max-height: calc(90vh - 160px);
  overflow-y: auto;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding: 16px 24px;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

/* 表单 */
.form-section {
  margin-bottom: 24px;
}

.form-section h4 {
  font-size: 15px;
  font-weight: 600;
  color: #1e293b;
  margin: 0 0 16px 0;
  padding-bottom: 8px;
  border-bottom: 1px solid #e2e8f0;
}

.section-hint {
  font-size: 12px;
  font-weight: 400;
  color: #64748b;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  font-weight: 500;
  color: #334155;
  font-size: 14px;
  margin-bottom: 6px;
}

.required {
  color: #ef4444;
}

.form-select,
.form-input {
  width: 100%;
  padding: 10px 14px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.2s;
}

.form-select:focus,
.form-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.form-hint {
  font-size: 12px;
  color: #64748b;
  margin-top: 4px;
}

/* 权限复选框 */
.permission-checkboxes {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}

.checkbox-item {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

.checkbox-item input {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.checkbox-label {
  font-size: 14px;
  color: #334155;
}

/* 命名空间选择器 */
.namespace-selector {
  background: #f8fafc;
  border-radius: 8px;
  padding: 16px;
}

.ns-actions {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
  align-items: center;
}

.ns-selected-count {
  font-size: 13px;
  color: #64748b;
  margin-left: auto;
}

.namespace-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.namespace-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s;
}

.namespace-item:hover {
  border-color: #3b82f6;
}

.namespace-item.selected {
  background: #eff6ff;
  border-color: #3b82f6;
}

.namespace-item input {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.ns-name {
  font-size: 13px;
  color: #334155;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 错误提示 */
.error-box {
  padding: 12px 16px;
  background: #fef2f2;
  border-left: 4px solid #ef4444;
  border-radius: 8px;
  color: #991b1b;
  font-size: 14px;
  margin-top: 16px;
}

/* 删除确认 */
.delete-warning {
  font-size: 15px;
  color: #334155;
  margin-bottom: 12px;
}

.delete-hint {
  font-size: 13px;
  color: #64748b;
}

.empty-hint {
  color: #64748b;
  font-size: 14px;
  padding: 20px;
  text-align: center;
}
</style>
