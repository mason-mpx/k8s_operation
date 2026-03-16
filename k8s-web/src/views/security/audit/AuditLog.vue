<template>
  <div class="resource-view">
    <!-- 页面头部 -->
    <div class="view-header">
      <h1>📋 审计日志</h1>
      <p>K8s 集群事件记录（Warning/Normal 事件）</p>
    </div>

    <!-- 操作栏 -->
    <div class="action-bar">
      <!-- 集群选择器 -->
      <div class="filter-dropdown">
        <select v-model="selectedClusterId">
          <option value="">请选择集群</option>
          <option v-for="cluster in clusters" :key="cluster.id" :value="cluster.id">
            {{ cluster.name }}
          </option>
        </select>
      </div>

      <div class="filter-dropdown">
        <select v-model="namespaceFilter" @change="loadEvents">
          <option value="">所有命名空间</option>
          <option v-for="ns in namespaces" :key="ns" :value="ns">{{ ns }}</option>
        </select>
      </div>

      <div class="filter-dropdown">
        <select v-model="typeFilter" @change="loadEvents">
          <option value="">所有类型</option>
          <option value="Warning">⚠️ Warning</option>
          <option value="Normal">✅ Normal</option>
        </select>
      </div>

      <div class="filter-dropdown">
        <select v-model="timeRange" @change="loadEvents">
          <option value="3600">最近 1 小时</option>
          <option value="21600">最近 6 小时</option>
          <option value="86400">最近 24 小时</option>
          <option value="259200">最近 3 天</option>
          <option value="604800">最近 7 天</option>
        </select>
      </div>

      <div class="action-buttons">
        <button class="btn btn-secondary" @click="loadEvents" :disabled="loading">
          {{ loading ? '加载中...' : '🔄 刷新' }}
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading && events.length === 0" class="loading-state">
      <div class="loading-spinner"></div>
      <p>加载中...</p>
    </div>

    <!-- 表格视图 -->
    <div v-else class="table-container">
      <table class="table">
        <thead>
          <tr>
            <th style="width: 160px;">时间</th>
            <th style="width: 100px;">类型</th>
            <th style="width: 150px;">原因</th>
            <th style="width: 150px;">对象</th>
            <th>消息</th>
            <th style="width: 80px;">次数</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(event, index) in events" :key="index">
            <td>{{ formatTime(event.last_time || event.first_time) }}</td>
            <td>
              <span :class="['pill', event.type === 'Warning' ? 'warning' : 'normal']">
                {{ event.type === 'Warning' ? '⚠️ Warning' : '✅ Normal' }}
              </span>
            </td>
            <td>{{ event.reason }}</td>
            <td>
              <span class="object-tag">
                {{ event.kind }}/{{ event.name }}
              </span>
            </td>
            <td class="message-cell">{{ event.message }}</td>
            <td>{{ event.count || 1 }}</td>
          </tr>
        </tbody>
      </table>

      <div v-if="events.length === 0" class="empty-state">
        <div class="empty-icon">📭</div>
        <div class="empty-text">暂无事件记录</div>
      </div>
    </div>

    <!-- 分页信息 -->
    <div v-if="events.length > 0" class="pagination-info">
      共 {{ events.length }} 条记录
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import { getK8sEvents } from '@/api/k8sRbac'
import { getClusterList } from '@/api/cluster'
import { getNamespaces } from '@/api/namespace'
import permissionStore from '@/stores/permission'

// 数据状态
const loading = ref(false)
const events = ref([])
const namespaces = ref([])

// 筛选条件
const namespaceFilter = ref('')
const typeFilter = ref('')
const timeRange = ref('86400') // 默认24小时

// 集群选择
const clusters = ref([])
const selectedClusterId = ref('')

// 监听集群变化
watch(selectedClusterId, () => {
  if (selectedClusterId.value) {
    loadNamespaces()
    loadEvents()
  }
})

// 加载集群列表
const loadClusters = async () => {
  try {
    const res = await getClusterList({ page: 1, limit: 100 })
    if (res.code === 0 && res.data?.list) {
      // 权限过滤：只显示用户有权限访问的集群
      const allClusters = res.data.list
      clusters.value = allClusters.filter(c => 
        permissionStore.state.isSuperAdmin ||
        permissionStore.state.accessibleClusterIds.includes(c.id)
      )
      if (clusters.value.length > 0 && !selectedClusterId.value) {
        selectedClusterId.value = clusters.value[0].id
      }
    } else {
      console.warn('集群列表返回异常:', res)
    }
  } catch (error) {
    console.error('加载集群列表失败:', error)
    Message.error({ content: '加载集群列表失败: ' + (error.msg || error.message) })
  }
}

// 加载命名空间列表
const loadNamespaces = async () => {
  if (!selectedClusterId.value) return
  try {
    const res = await getNamespaces(selectedClusterId.value)
    if (res.code === 0 && res.data?.list) {
      namespaces.value = res.data.list.map(ns => ns.name || ns)
    }
  } catch (error) {
    console.error('加载命名空间失败:', error)
    namespaces.value = ['default', 'kube-system', 'kube-public']
  }
}

// 加载事件列表 - 调用真实 API
const loadEvents = async () => {
  if (!selectedClusterId.value) {
    Message.warning({ content: '请先选择集群' })
    return
  }
  
  loading.value = true
  try {
    const res = await getK8sEvents(selectedClusterId.value, {
      namespace: namespaceFilter.value,
      type: typeFilter.value,
      limit: 200,
      since_seconds: parseInt(timeRange.value)
    })
    
    if (res.code === 0 && res.data?.events) {
      events.value = res.data.events
    } else {
      events.value = []
    }
  } catch (error) {
    console.error('加载事件失败:', error)
    Message.error({ content: '加载事件失败: ' + (error.msg || error.message) })
    events.value = []
  } finally {
    loading.value = false
  }
}

// 格式化时间
const formatTime = (timeStr) => {
  if (!timeStr) return '-'
  const date = new Date(timeStr)
  return date.toLocaleString('zh-CN')
}

onMounted(() => {
  loadClusters()
})
</script>

<style scoped>
.resource-view {
  padding: 0;
}

.view-header {
  margin-bottom: 24px;
}

.view-header h1 {
  font-size: 28px;
  font-weight: 700;
  color: #1e293b;
  margin: 0 0 8px 0;
}

.view-header p {
  color: #64748b;
  font-size: 14px;
  margin: 0;
}

.action-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 20px;
  align-items: center;
}

.filter-dropdown select {
  padding: 10px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  background-color: white;
  cursor: pointer;
}

.action-buttons {
  margin-left: auto;
}

.btn {
  padding: 10px 18px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
}

.btn-secondary {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
}

.btn-secondary:hover {
  background: #e2e8f0;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 60px 20px;
  color: #64748b;
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

.table-container {
  background: #fff;
  border-radius: 10px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: #fff;
}

.table th, .table td {
  padding: 12px 14px;
  border-bottom: 1px solid #eef2f7;
  text-align: left;
  font-size: 14px;
}

.table th {
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  font-weight: 600;
  color: #475569;
}

.table tr:last-child td {
  border-bottom: 0;
}

.table tr:hover {
  background: #f8fafc;
}

.pill {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
}

.pill.warning {
  background: #fef3c7;
  color: #92400e;
}

.pill.normal {
  background: #dcfce7;
  color: #16a34a;
}

.object-tag {
  display: inline-block;
  padding: 4px 8px;
  background: #e0f2fe;
  color: #0369a1;
  border-radius: 4px;
  font-size: 12px;
  font-family: 'Courier New', monospace;
}

.message-cell {
  max-width: 400px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.empty-state {
  padding: 60px 20px;
  text-align: center;
  color: #64748b;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.empty-text {
  font-size: 14px;
}

.pagination-info {
  padding: 16px;
  text-align: center;
  color: #64748b;
  font-size: 14px;
  background: #f8fafc;
  border-radius: 0 0 10px 10px;
}
</style>
