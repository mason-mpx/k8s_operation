<template>
  <!-- 悬浮按钮 -->
  <div class="ai-fab" :class="{ active: isOpen }" @click="togglePanel">
    <div class="ai-fab-inner">
      <transition name="fab-icon" mode="out-in">
        <svg v-if="!isOpen" key="ai" viewBox="0 0 24 24" fill="none" class="fab-svg">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" fill="url(#fab-grad)"/>
          <defs><linearGradient id="fab-grad" x1="0" y1="0" x2="24" y2="24">
            <stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/>
          </linearGradient></defs>
          <circle cx="8.5" cy="11" r="1.2" fill="#fff"/>
          <circle cx="12" cy="11" r="1.2" fill="#fff"/>
          <circle cx="15.5" cy="11" r="1.2" fill="#fff"/>
          <path d="M7 15.5c1.1 1.3 2.9 2 5 2s3.9-.7 5-2" stroke="#fff" stroke-width="1.5" stroke-linecap="round" fill="none"/>
        </svg>
        <svg v-else key="close" viewBox="0 0 24 24" fill="none" class="fab-svg">
          <line x1="6" y1="6" x2="18" y2="18" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>
          <line x1="18" y1="6" x2="6" y2="18" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>
        </svg>
      </transition>
    </div>
    <span v-if="pendingCount > 0 && !isOpen" class="fab-badge">{{ pendingCount }}</span>
  </div>

  <!-- 聊天面板 -->
  <transition name="panel-slide">
    <div v-if="isOpen" class="ai-panel">
      <!-- 头部 -->
      <div class="panel-header">
        <div class="header-left">
          <div class="ai-avatar-sm">
            <svg viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" fill="url(#head-grad)"/>
              <defs><linearGradient id="head-grad" x1="0" y1="0" x2="24" y2="24">
                <stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/>
              </linearGradient></defs>
              <path d="M8 14s1.5 2 4 2 4-2 4-2" stroke="#fff" stroke-width="1.5" stroke-linecap="round" fill="none"/>
              <circle cx="9" cy="10" r="1" fill="#fff"/><circle cx="15" cy="10" r="1" fill="#fff"/>
            </svg>
          </div>
          <div class="header-info">
            <span class="header-title">K8s AI 助手</span>
            <span class="header-status" :class="{ online: aiEnabled }">
              {{ aiEnabled ? '在线' : '离线' }}
            </span>
          </div>
        </div>
        <div class="header-actions">
          <!-- 模型选择器 -->
          <div class="model-selector-wrap" v-if="aiEnabled && providers.length > 0">
            <button class="header-btn model-trigger" @click.stop="showModelPicker = !showModelPicker" :title="currentModelLabel">
              <span class="model-icon-mini">{{ currentProviderIcon }}</span>
            </button>
            <transition name="picker-fade">
              <div v-if="showModelPicker" class="model-picker" @click.stop>
                <div class="picker-header">
                  <span class="picker-title">选择 AI 模型</span>
                  <button class="picker-close" @click="showModelPicker = false">&times;</button>
                </div>
                <div class="picker-body">
                  <div v-for="provider in providers" :key="provider.id" class="provider-group">
                    <div class="provider-label">
                      <span class="provider-icon">{{ providerIconMap[provider.icon] || '✨' }}</span>
                      <span class="provider-name">{{ provider.name }}</span>
                    </div>
                    <div
                      v-for="model in provider.models" :key="model.id"
                      :class="['model-option', { active: selectedProvider === provider.id && selectedModel === model.id }]"
                      @click="selectModel(provider.id, model.id, model.name, provider.icon)"
                    >
                      <div class="model-main">
                        <span class="model-name">{{ model.name }}</span>
                        <span v-if="model.capability" :class="['cap-tag', model.capability]">{{ capabilityLabel[model.capability] || model.capability }}</span>
                      </div>
                      <div class="model-desc" v-if="model.description">{{ model.description }}</div>
                    </div>
                  </div>
                </div>
              </div>
            </transition>
          </div>
          <button v-if="pendingCount > 0" class="header-btn approval-btn" @click="activeTab = 'approvals'" title="待审批">
            <svg viewBox="0 0 20 20" fill="currentColor"><path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/><path fill-rule="evenodd" d="M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm9.707 5.707a1 1 0 00-1.414-1.414L9 12.586l-1.293-1.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>
            <span class="btn-badge">{{ pendingCount }}</span>
          </button>
          <button class="header-btn" @click="startNewChat" title="新对话">
            <svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"/></svg>
          </button>
          <button class="header-btn" @click="activeTab = activeTab === 'history' ? 'chat' : 'history'" title="历史记录">
            <svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/></svg>
          </button>
        </div>
      </div>

      <!-- Tab 切换区 -->
      <div class="panel-tabs" v-if="activeTab !== 'chat'">
        <button :class="['tab-btn', { active: activeTab === 'history' }]" @click="activeTab = 'history'">历史会话</button>
        <button :class="['tab-btn', { active: activeTab === 'approvals' }]" @click="activeTab = 'approvals'">
          待审批
          <span v-if="pendingCount > 0" class="tab-badge">{{ pendingCount }}</span>
        </button>
      </div>

      <!-- 聊天内容区 -->
      <div v-show="activeTab === 'chat'" class="panel-body" ref="chatBody">
        <!-- 欢迎消息 -->
        <div v-if="messages.length === 0" class="welcome-area">
          <div class="welcome-icon">
            <svg viewBox="0 0 48 48" fill="none">
              <circle cx="24" cy="24" r="22" fill="url(#welcome-grad)" opacity="0.1"/>
              <circle cx="24" cy="24" r="16" fill="url(#welcome-grad)" opacity="0.15"/>
              <defs><linearGradient id="welcome-grad" x1="0" y1="0" x2="48" y2="48">
                <stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/>
              </linearGradient></defs>
              <text x="24" y="30" text-anchor="middle" font-size="20">🤖</text>
            </svg>
          </div>
          <h3 class="welcome-title">Hi，我是 K8s AI 助手</h3>
          <p class="welcome-desc">我可以回答任何问题，也能直接操作 K8s 平台。<br/>高危操作会自动触发审批流程。</p>
          <!-- 分组快捷按钮 -->
          <div class="quick-group">
            <div class="quick-group-label"><span class="qg-icon">💬</span> 常规问答</div>
            <div class="quick-actions">
              <button v-for="q in quickGeneral" :key="q.text" class="quick-btn general" @click="sendQuickQuestion(q.text)">
                {{ q.icon }} {{ q.text }}
              </button>
            </div>
          </div>
          <div class="quick-group">
            <div class="quick-group-label"><span class="qg-icon">🖥️</span> 平台操作</div>
            <div class="quick-actions">
              <button v-for="q in quickPlatform" :key="q.text" class="quick-btn platform" @click="sendQuickQuestion(q.text)">
                {{ q.icon }} {{ q.text }}
              </button>
            </div>
          </div>
        </div>

        <!-- 消息列表 -->
        <div v-for="(msg, idx) in messages" :key="idx" :class="['msg-row', msg.role]">
          <div v-if="msg.role === 'assistant'" class="msg-avatar">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="url(#msg-grad)"/>
              <defs><linearGradient id="msg-grad" x1="0" y1="0" x2="24" y2="24"><stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/></linearGradient></defs>
              <text x="12" y="16" text-anchor="middle" font-size="10" fill="#fff">AI</text>
            </svg>
          </div>
          <div :class="['msg-bubble', msg.role, { 'msg-error': msg.isError }]">
            <!-- 意图标签 -->
            <div v-if="msg.role === 'assistant' && msg.intentTag" :class="['intent-tag', msg.intentTag.type]">
              <span class="intent-icon">{{ msg.intentTag.icon }}</span>
              <span class="intent-label">{{ msg.intentTag.label }}</span>
              <span v-if="msg.toolsCalled && msg.toolsCalled.length" class="intent-tools">
                {{ msg.toolsCalled.join(', ') }}
              </span>
            </div>
            <div class="msg-text" v-html="formatMessage(msg.content)"></div>
            <!-- 错误详情折叠 -->
            <div v-if="msg.isError && msg.errorInfo" class="error-detail">
              <div class="error-detail-header" @click="msg._showDetail = !msg._showDetail">
                <span class="error-detail-icon">{{ msg._showDetail ? '▼' : '▶' }}</span>
                <span>排查信息</span>
              </div>
              <div v-if="msg._showDetail" class="error-detail-body">
                <div v-if="msg.errorInfo.code" class="error-field">
                  <span class="error-label">错误码:</span>
                  <span class="error-value">{{ msg.errorInfo.code }}</span>
                </div>
                <div v-if="msg.errorInfo.detail" class="error-field">
                  <span class="error-label">详情:</span>
                  <span class="error-value">{{ msg.errorInfo.detail }}</span>
                </div>
                <div class="error-field">
                  <span class="error-label">时间:</span>
                  <span class="error-value">{{ msg.errorInfo.timestamp }}</span>
                </div>
                <div class="error-tip">查看 AI 日志: storage/logs/ai.log</div>
              </div>
            </div>
            <!-- 审批提示 -->
            <div v-if="msg.pendingTools && msg.pendingTools.length" class="approval-notice">
              <div class="approval-icon">⚠️</div>
              <div class="approval-info">
                <span class="approval-label">需要审批</span>
                <div v-for="pt in msg.pendingTools" :key="pt.approval_id" class="approval-item">
                  <span class="tool-name">{{ pt.tool_name }}</span>
                  <span :class="['risk-tag', pt.risk_level]">{{ pt.risk_level }}</span>
                </div>
              </div>
            </div>
            <span class="msg-time">{{ formatTime(msg.time) }}</span>
          </div>
        </div>

        <!-- 加载动画 -->
        <div v-if="loading" class="msg-row assistant">
          <div class="msg-avatar">
            <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="url(#load-grad)"/>
              <defs><linearGradient id="load-grad" x1="0" y1="0" x2="24" y2="24"><stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/></linearGradient></defs>
              <text x="12" y="16" text-anchor="middle" font-size="10" fill="#fff">AI</text>
            </svg>
          </div>
          <div class="msg-bubble assistant typing">
            <div class="typing-dots">
              <span></span><span></span><span></span>
            </div>
          </div>
        </div>
      </div>

      <!-- 历史会话列表 -->
      <div v-show="activeTab === 'history'" class="panel-body history-list">
        <div v-if="conversations.length === 0" class="empty-state">
          <span class="empty-icon">💬</span>
          <span>暂无历史会话</span>
        </div>
        <div v-for="conv in conversations" :key="conv.id" class="history-item" @click="loadConversation(conv.id)">
          <div class="history-title">{{ conv.title || '新对话' }}</div>
          <div class="history-meta">
            <span>{{ conv.message_count || 0 }} 条消息</span>
            <span>{{ formatDate(conv.updated_at) }}</span>
          </div>
          <button class="history-delete" @click.stop="removeConversation(conv.id)">
            <svg viewBox="0 0 16 16" fill="currentColor"><path d="M5.5 5.5A.5.5 0 016 6v6a.5.5 0 01-1 0V6a.5.5 0 01.5-.5zm2.5 0a.5.5 0 01.5.5v6a.5.5 0 01-1 0V6a.5.5 0 01.5-.5zm3 .5a.5.5 0 00-1 0v6a.5.5 0 001 0V6z"/><path fill-rule="evenodd" d="M14.5 3a1 1 0 01-1 1H13v9a2 2 0 01-2 2H5a2 2 0 01-2-2V4h-.5a1 1 0 01-1-1V2a1 1 0 011-1H5a1 1 0 011-1h4a1 1 0 011 1h2.5a1 1 0 011 1v1zM4.118 4L4 4.059V13a1 1 0 001 1h6a1 1 0 001-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/></svg>
          </button>
        </div>
      </div>

      <!-- 审批列表 -->
      <div v-show="activeTab === 'approvals'" class="panel-body approval-list">
        <div v-if="approvals.length === 0" class="empty-state">
          <span class="empty-icon">✅</span>
          <span>暂无待审批操作</span>
        </div>
        <div v-for="ap in approvals" :key="ap.id" class="approval-card">
          <div class="approval-card-header">
            <span class="tool-name">{{ ap.tool_name || ap.action }}</span>
            <span :class="['risk-tag', ap.risk_level || 'write']">{{ ap.risk_level || 'write' }}</span>
          </div>
          <div class="approval-card-desc">{{ ap.description }}</div>
          <div class="approval-card-actions">
            <button class="approve-btn" @click="handleApprove(ap.id)">通过</button>
            <button class="reject-btn" @click="handleReject(ap.id)">拒绝</button>
          </div>
        </div>
      </div>

      <!-- 输入区 -->
      <div class="panel-footer" v-show="activeTab === 'chat'">
        <div class="input-wrapper">
          <textarea
            ref="inputRef"
            v-model="inputText"
            class="chat-input"
            placeholder="输入消息，如：查看所有 Pod、扩容 Deployment..."
            rows="1"
            @keydown.enter.exact.prevent="sendMessage"
            @input="autoResize"
          ></textarea>
          <button class="send-btn" :disabled="!inputText.trim() || loading" @click="sendMessage">
            <svg viewBox="0 0 20 20" fill="currentColor">
              <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z"/>
            </svg>
          </button>
        </div>
        <div class="input-hint">
          <span v-if="currentModelLabel !== 'AI 模型'" class="current-model-hint">{{ currentProviderIcon }} {{ currentModelLabel }}</span>
          <span v-else>Enter 发送</span>
          <span class="hint-sep">·</span>
          <span class="hint-general">💬 常规问答</span>
          <span class="hint-sep">·</span>
          <span class="hint-platform">🖥️ 平台操作</span>
          <span class="hint-sep">·</span>
          <span>AI 自动识别</span>
        </div>
      </div>
    </div>
  </transition>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick, watch, onBeforeUnmount } from 'vue'
import { aiChat, getAIStatus, getAIModels, getConversations, getConversationMessages, deleteConversation, getApprovals, approveApproval, rejectApproval, getPendingApprovalCount } from '@/api/ai'
import { Message } from '@arco-design/web-vue'

const isOpen = ref(false)
const activeTab = ref('chat')
const loading = ref(false)
const inputText = ref('')
const inputRef = ref(null)
const chatBody = ref(null)
const aiEnabled = ref(false)
const conversationId = ref(null)
const pendingCount = ref(0)

// 多模型选择器状态
const showModelPicker = ref(false)
const providers = reactive([])
const selectedProvider = ref('')
const selectedModel = ref('')
const currentModelLabel = ref('AI 模型')
const currentProviderIcon = ref('✨')

const providerIconMap = {
  openai: '🟢',
  deepseek: '🔵',
  zhipu: '🟣',
  qwen: '🟠',
  moonshot: '🌙',
}
const capabilityLabel = {
  chat: '对话',
  reasoning: '推理',
  code: '代码',
  vision: '视觉',
}

const messages = reactive([])
const conversations = reactive([])
const approvals = reactive([])

// 分组快捷问题
const quickGeneral = [
  { icon: '💡', text: '什么是 Kubernetes？' },
  { icon: '📝', text: '帮我写个 Nginx Deployment YAML' },
  { icon: '🔧', text: '如何排查 Pod CrashLoopBackOff？' },
]
const quickPlatform = [
  { icon: '📋', text: '查看所有集群' },
  { icon: '🔍', text: '列出 default 命名空间的 Pod' },
  { icon: '📊', text: '集群健康检查' },
  { icon: '🚀', text: '查看 Deployment 状态' },
]

const togglePanel = () => {
  isOpen.value = !isOpen.value
  if (isOpen.value) {
    checkAIStatus()
    loadModels()
    loadPendingCount()
    nextTick(() => inputRef.value?.focus())
  }
}

const checkAIStatus = async () => {
  try {
    const res = await getAIStatus()
    aiEnabled.value = res?.data?.enabled ?? false
    if (res?.data?.default_provider && !selectedProvider.value) {
      selectedProvider.value = res.data.default_provider
    }
    if (res?.data?.default_model && !selectedModel.value) {
      selectedModel.value = res.data.default_model
    }
  } catch { aiEnabled.value = false }
}

const loadModels = async () => {
  try {
    const res = await getAIModels()
    const data = res?.data
    providers.length = 0
    ;(data?.providers || []).forEach(p => providers.push(p))
    if (data?.default_provider && !selectedProvider.value) {
      selectedProvider.value = data.default_provider
    }
    if (data?.default_model && !selectedModel.value) {
      selectedModel.value = data.default_model
    }
    // 设置当前模型显示
    updateCurrentModelLabel()
  } catch { /* ignore */ }
}

const selectModel = (providerId, modelId, modelName, icon) => {
  selectedProvider.value = providerId
  selectedModel.value = modelId
  currentModelLabel.value = modelName
  currentProviderIcon.value = providerIconMap[icon] || '✨'
  showModelPicker.value = false
}

const updateCurrentModelLabel = () => {
  for (const p of providers) {
    for (const m of p.models) {
      if (p.id === selectedProvider.value && m.id === selectedModel.value) {
        currentModelLabel.value = m.name
        currentProviderIcon.value = providerIconMap[p.icon] || '✨'
        return
      }
    }
  }
}

// 点击外部关闭模型选择器
const closePickerOnOutside = (e) => {
  if (showModelPicker.value && !e.target.closest('.model-selector-wrap')) {
    showModelPicker.value = false
  }
}

const loadPendingCount = async () => {
  try {
    const res = await getPendingApprovalCount()
    pendingCount.value = res?.data?.count ?? 0
  } catch (err) {
    // 静默处理：token 过期、后端未启动、网络错误等都忽略
    pendingCount.value = 0
  }
}

const startNewChat = () => {
  messages.length = 0
  conversationId.value = null
  activeTab.value = 'chat'
}

const sendQuickQuestion = (q) => {
  inputText.value = q
  sendMessage()
}

const sendMessage = async () => {
  const text = inputText.value.trim()
  if (!text || loading.value) return

  messages.push({ role: 'user', content: text, time: new Date() })
  inputText.value = ''
  autoResize()
  loading.value = true
  scrollToBottom()

  try {
    const res = await aiChat({
      message: text,
      conversation_id: conversationId.value || undefined,
      provider_id: selectedProvider.value || undefined,
      model_id: selectedModel.value || undefined,
    })
    const data = res?.data || res
    conversationId.value = data.conversation_id || conversationId.value

    const toolsCalled = data.tools_called || []
    const pendingTools = data.pending_tools || []
    const intentTag = getIntentTag(toolsCalled, pendingTools)

    messages.push({
      role: 'assistant',
      content: data.reply || '抱歉，我暂时无法回答。',
      time: new Date(),
      pendingTools,
      toolsCalled,
      intentTag,
    })

    if (data.pending_tools?.length) {
      loadPendingCount()
    }
  } catch (e) {
    const errDetail = e?.data?.details || e?.msg || e?.message || ''
    const errCode = e?.code || e?.status || ''
    messages.push({
      role: 'assistant',
      content: '请求失败，请检查网络或 AI 服务配置。' + (errDetail ? `\n错误: ${errDetail}` : ''),
      time: new Date(),
      isError: true,
      errorInfo: {
        code: errCode,
        detail: errDetail,
        timestamp: new Date().toISOString(),
      },
      intentTag: { type: 'error', icon: '❌', label: 'AI 异常' },
    })
  } finally {
    loading.value = false
    scrollToBottom()
  }
}

const loadConversation = async (id) => {
  try {
    const res = await getConversationMessages(id)
    messages.length = 0
    conversationId.value = id
    const list = res?.data || []
    list.forEach(m => {
      messages.push({ role: m.role, content: m.content, time: new Date(m.created_at) })
    })
    activeTab.value = 'chat'
    scrollToBottom()
  } catch { Message.error('加载会话失败') }
}

const loadHistory = async () => {
  try {
    const res = await getConversations()
    conversations.length = 0
    ;(res?.data || []).forEach(c => conversations.push(c))
  } catch { /* ignore */ }
}

const removeConversation = async (id) => {
  try {
    await deleteConversation(id)
    const idx = conversations.findIndex(c => c.id === id)
    if (idx >= 0) conversations.splice(idx, 1)
    if (conversationId.value === id) startNewChat()
  } catch { Message.error('删除失败') }
}

const loadApprovals = async () => {
  try {
    const res = await getApprovals({ status: 'pending' })
    approvals.length = 0
    ;(res?.data?.list || res?.data || []).forEach(a => approvals.push(a))
  } catch { /* ignore */ }
}

const handleApprove = async (id) => {
  try {
    await approveApproval(id, { comment: '通过' })
    Message.success('已通过')
    loadApprovals()
    loadPendingCount()
  } catch { Message.error('操作失败') }
}

const handleReject = async (id) => {
  try {
    await rejectApproval(id, { comment: '拒绝' })
    Message.success('已拒绝')
    loadApprovals()
    loadPendingCount()
  } catch { Message.error('操作失败') }
}

const scrollToBottom = () => {
  nextTick(() => {
    if (chatBody.value) chatBody.value.scrollTop = chatBody.value.scrollHeight
  })
}

const autoResize = () => {
  nextTick(() => {
    if (!inputRef.value) return
    inputRef.value.style.height = 'auto'
    inputRef.value.style.height = Math.min(inputRef.value.scrollHeight, 120) + 'px'
  })
}

// 根据工具调用情况判断意图标签
const getIntentTag = (toolsCalled, pendingTools) => {
  if (pendingTools && pendingTools.length > 0) {
    const hasCritical = pendingTools.some(t => t.risk_level === 'critical' || t.risk_level === 'danger')
    return {
      type: hasCritical ? 'danger' : 'approval',
      icon: hasCritical ? '🛑' : '⚠️',
      label: hasCritical ? '高危操作 · 需审批' : '写操作 · 需审批',
    }
  }
  if (toolsCalled && toolsCalled.length > 0) {
    return {
      type: 'platform',
      icon: '🖥️',
      label: '平台数据',
    }
  }
  return {
    type: 'general',
    icon: '💬',
    label: '常规回答',
  }
}

const formatMessage = (text) => {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\n/g, '<br/>')
}

const formatTime = (d) => {
  if (!d) return ''
  const date = d instanceof Date ? d : new Date(d)
  return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

const formatDate = (d) => {
  if (!d) return ''
  const date = new Date(d)
  const now = new Date()
  if (date.toDateString() === now.toDateString()) return '今天'
  return date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
}

watch(activeTab, (tab) => {
  if (tab === 'history') loadHistory()
  if (tab === 'approvals') loadApprovals()
})

onMounted(() => {
  loadPendingCount()
  document.addEventListener('click', closePickerOnOutside)
})
onBeforeUnmount(() => {
  document.removeEventListener('click', closePickerOnOutside)
})
</script>

<style scoped>
/* ===== 模型选择器 ===== */
.model-selector-wrap { position: relative; }
.model-trigger { position: relative; }
.model-icon-mini { font-size: 1rem; line-height: 1; }
.model-picker {
  position: absolute;
  top: 2.5rem; right: 0;
  width: 18rem;
  max-height: 22rem;
  background: #fff;
  border-radius: 0.75rem;
  box-shadow: 0 20px 50px -12px rgba(0,0,0,0.2), 0 0 0 1px rgba(0,0,0,0.05);
  z-index: 10000;
  display: flex; flex-direction: column;
  overflow: hidden;
}
.picker-fade-enter-active { transition: all 0.2s ease-out; }
.picker-fade-leave-active { transition: all 0.15s ease-in; }
.picker-fade-enter-from { opacity: 0; transform: translateY(-8px) scale(0.95); }
.picker-fade-leave-to { opacity: 0; transform: translateY(-4px); }
.picker-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.picker-title { font-size: 0.8125rem; font-weight: 700; color: #1e293b; }
.picker-close {
  border: none; background: none; color: #94a3b8; font-size: 1.25rem;
  cursor: pointer; line-height: 1; padding: 0;
}
.picker-close:hover { color: #475569; }
.picker-body { overflow-y: auto; padding: 0.5rem; }
.provider-group { margin-bottom: 0.5rem; }
.provider-group:last-child { margin-bottom: 0; }
.provider-label {
  display: flex; align-items: center; gap: 0.375rem;
  padding: 0.375rem 0.5rem; font-size: 0.6875rem;
  color: #94a3b8; font-weight: 600; text-transform: uppercase;
  letter-spacing: 0.5px;
}
.provider-icon { font-size: 0.875rem; }
.model-option {
  padding: 0.5rem 0.75rem; border-radius: 0.5rem;
  cursor: pointer; transition: all 0.15s;
  border: 1.5px solid transparent;
}
.model-option:hover { background: #f8fafc; border-color: #e2e8f0; }
.model-option.active {
  background: linear-gradient(135deg, #eef2ff, #e0e7ff);
  border-color: #818cf8;
}
.model-main { display: flex; align-items: center; gap: 0.5rem; }
.model-name { font-size: 0.8125rem; font-weight: 600; color: #1e293b; }
.cap-tag {
  padding: 0.0625rem 0.375rem; border-radius: 0.25rem;
  font-size: 0.5625rem; font-weight: 600;
}
.cap-tag.chat { background: #dbeafe; color: #2563eb; }
.cap-tag.reasoning { background: #fef3c7; color: #d97706; }
.cap-tag.code { background: #dcfce7; color: #16a34a; }
.cap-tag.vision { background: #f3e8ff; color: #9333ea; }
.model-desc {
  font-size: 0.6875rem; color: #94a3b8; margin-top: 0.125rem;
  padding-left: 0;
}

/* ===== 悬浮按钮 ===== */
.ai-fab {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  width: 3.5rem;
  height: 3.5rem;
  z-index: 9999;
  cursor: pointer;
  filter: drop-shadow(0 4px 12px rgba(99, 102, 241, 0.4));
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
.ai-fab:hover { transform: scale(1.1); filter: drop-shadow(0 6px 20px rgba(99, 102, 241, 0.5)); }
.ai-fab.active { transform: scale(0.95); }
.ai-fab-inner {
  width: 100%; height: 100%;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  border-radius: 1rem;
  display: flex; align-items: center; justify-content: center;
  transition: border-radius 0.3s ease;
}
.ai-fab.active .ai-fab-inner { border-radius: 50%; background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%); }
.fab-svg { width: 1.75rem; height: 1.75rem; }
.fab-badge {
  position: absolute; top: -0.25rem; right: -0.25rem;
  min-width: 1.25rem; height: 1.25rem;
  background: linear-gradient(135deg, #ef4444, #f97316);
  color: #fff; font-size: 0.7rem; font-weight: 700;
  border-radius: 0.625rem;
  display: flex; align-items: center; justify-content: center;
  border: 2px solid #fff;
}
.fab-icon-enter-active, .fab-icon-leave-active { transition: all 0.2s ease; }
.fab-icon-enter-from { opacity: 0; transform: rotate(-90deg) scale(0.5); }
.fab-icon-leave-to { opacity: 0; transform: rotate(90deg) scale(0.5); }

/* ===== 聊天面板 ===== */
.ai-panel {
  position: fixed;
  bottom: 6.5rem; right: 2rem;
  width: 26rem; height: 38rem;
  max-height: calc(100vh - 8rem);
  background: #ffffff;
  border-radius: 1.25rem;
  box-shadow: 0 25px 60px -12px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0, 0, 0, 0.05);
  display: flex; flex-direction: column;
  z-index: 9998;
  overflow: hidden;
}
.panel-slide-enter-active { transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1); }
.panel-slide-leave-active { transition: all 0.2s ease-in; }
.panel-slide-enter-from { opacity: 0; transform: translateY(20px) scale(0.95); }
.panel-slide-leave-to { opacity: 0; transform: translateY(10px) scale(0.98); }

/* ===== 头部 ===== */
.panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #a78bfa 100%);
  color: #fff;
}
.header-left { display: flex; align-items: center; gap: 0.75rem; }
.ai-avatar-sm { width: 2.25rem; height: 2.25rem; }
.ai-avatar-sm svg { width: 100%; height: 100%; }
.header-info { display: flex; flex-direction: column; }
.header-title { font-size: 0.9375rem; font-weight: 700; letter-spacing: 0.3px; }
.header-status { font-size: 0.6875rem; opacity: 0.8; display: flex; align-items: center; gap: 0.3rem; }
.header-status::before { content: ''; width: 6px; height: 6px; border-radius: 50%; background: #94a3b8; }
.header-status.online::before { background: #4ade80; box-shadow: 0 0 6px #4ade80; }
.header-actions { display: flex; gap: 0.25rem; }
.header-btn {
  width: 2rem; height: 2rem;
  background: rgba(255,255,255,0.15); border: none; border-radius: 0.5rem;
  color: #fff; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: background 0.2s;
  position: relative;
}
.header-btn:hover { background: rgba(255,255,255,0.25); }
.header-btn svg { width: 1rem; height: 1rem; }
.btn-badge {
  position: absolute; top: -0.2rem; right: -0.2rem;
  min-width: 1rem; height: 1rem;
  background: #ef4444; color: #fff; font-size: 0.6rem;
  border-radius: 0.5rem; display: flex; align-items: center; justify-content: center;
}

/* ===== Tabs ===== */
.panel-tabs {
  display: flex; border-bottom: 1px solid #e5e7eb; background: #fafbfc;
}
.tab-btn {
  flex: 1; padding: 0.625rem; border: none; background: none;
  font-size: 0.8125rem; font-weight: 500; color: #6b7280; cursor: pointer;
  position: relative; transition: color 0.2s;
}
.tab-btn.active { color: #6366f1; }
.tab-btn.active::after {
  content: ''; position: absolute; bottom: 0; left: 20%; right: 20%;
  height: 2px; background: #6366f1; border-radius: 1px;
}
.tab-badge {
  margin-left: 0.25rem; padding: 0 0.35rem;
  background: #ef4444; color: #fff; font-size: 0.625rem; border-radius: 0.5rem;
}

/* ===== 消息区 ===== */
.panel-body {
  flex: 1; overflow-y: auto; padding: 1rem;
  scroll-behavior: smooth;
  background: linear-gradient(180deg, #f8f9ff 0%, #ffffff 100%);
}

/* ===== 欢迎区 ===== */
.welcome-area {
  display: flex; flex-direction: column; align-items: center;
  padding: 1.5rem 1rem; text-align: center;
}
.welcome-icon { width: 4rem; height: 4rem; margin-bottom: 1rem; }
.welcome-icon svg { width: 100%; height: 100%; }
.welcome-title { font-size: 1.125rem; font-weight: 700; color: #1e293b; margin-bottom: 0.5rem; }
.welcome-desc { font-size: 0.8125rem; color: #64748b; line-height: 1.6; margin-bottom: 1rem; }
.quick-group {
  width: 100%; text-align: left; margin-bottom: 0.75rem;
}
.quick-group-label {
  display: flex; align-items: center; gap: 0.375rem;
  font-size: 0.6875rem; font-weight: 700; color: #64748b;
  margin-bottom: 0.375rem; padding-left: 0.125rem;
  text-transform: uppercase; letter-spacing: 0.5px;
}
.qg-icon { font-size: 0.8125rem; }
.quick-actions { display: flex; flex-wrap: wrap; gap: 0.375rem; }
.quick-btn {
  padding: 0.4375rem 0.75rem; border: 1px solid #e2e8f0; border-radius: 1.25rem;
  background: #fff; color: #475569; font-size: 0.6875rem; cursor: pointer;
  transition: all 0.2s; white-space: nowrap;
}
.quick-btn:hover {
  transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}
.quick-btn.general:hover { border-color: #6366f1; color: #6366f1; background: #eef2ff; }
.quick-btn.platform:hover { border-color: #0ea5e9; color: #0369a1; background: #e0f2fe; }
.quick-btn.platform { border-color: #bae6fd; }

/* ===== 消息行 ===== */
.msg-row { display: flex; gap: 0.5rem; margin-bottom: 1rem; max-width: 100%; }
.msg-row.user { flex-direction: row-reverse; }
.msg-avatar { width: 1.75rem; height: 1.75rem; flex-shrink: 0; margin-top: 0.125rem; }
.msg-avatar svg { width: 100%; height: 100%; }
.msg-bubble {
  max-width: 80%; padding: 0.75rem 1rem;
  border-radius: 1rem; position: relative;
  font-size: 0.8125rem; line-height: 1.6;
  word-break: break-word;
}
.msg-bubble.assistant {
  background: #f1f5f9; color: #1e293b;
  border-bottom-left-radius: 0.25rem;
}
.msg-bubble.user {
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #fff;
  border-bottom-right-radius: 0.25rem;
}
.msg-text :deep(code) {
  background: rgba(99, 102, 241, 0.1); padding: 0.125rem 0.375rem;
  border-radius: 0.25rem; font-size: 0.75rem; font-family: 'Fira Code', monospace;
}
.msg-bubble.user .msg-text :deep(code) { background: rgba(255,255,255,0.2); }
.msg-time {
  display: block; font-size: 0.625rem; opacity: 0.5; margin-top: 0.375rem; text-align: right;
}

/* ===== 审批提醒 ===== */
.approval-notice {
  display: flex; gap: 0.5rem; margin-top: 0.75rem;
  padding: 0.625rem; background: #fffbeb; border: 1px solid #fde68a;
  border-radius: 0.5rem;
}
.approval-icon { font-size: 1rem; }
.approval-label { font-size: 0.75rem; font-weight: 600; color: #92400e; }
.approval-item {
  display: flex; align-items: center; gap: 0.375rem; margin-top: 0.25rem;
}
.tool-name { font-size: 0.75rem; color: #78716c; font-family: monospace; }
.risk-tag {
  padding: 0.0625rem 0.375rem; border-radius: 0.25rem;
  font-size: 0.625rem; font-weight: 600; text-transform: uppercase;
}
.risk-tag.write { background: #dbeafe; color: #1d4ed8; }
.risk-tag.danger { background: #fee2e2; color: #dc2626; }
.risk-tag.critical { background: #fecaca; color: #991b1b; }

/* ===== 打字动画 ===== */
.typing-dots { display: flex; gap: 0.3rem; padding: 0.25rem 0; }
.typing-dots span {
  width: 0.5rem; height: 0.5rem;
  background: #94a3b8; border-radius: 50%;
  animation: dot-bounce 1.4s infinite ease-in-out both;
}
.typing-dots span:nth-child(1) { animation-delay: -0.32s; }
.typing-dots span:nth-child(2) { animation-delay: -0.16s; }
@keyframes dot-bounce {
  0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; }
  40% { transform: scale(1); opacity: 1; }
}

/* ===== 历史会话 ===== */
.history-list, .approval-list { padding: 0.75rem; }
.empty-state {
  display: flex; flex-direction: column; align-items: center;
  padding: 3rem 1rem; color: #94a3b8; font-size: 0.8125rem; gap: 0.5rem;
}
.empty-icon { font-size: 2rem; }
.history-item {
  padding: 0.75rem; border-radius: 0.75rem;
  cursor: pointer; transition: background 0.2s; position: relative;
  border: 1px solid transparent;
}
.history-item:hover { background: #f8fafc; border-color: #e2e8f0; }
.history-title { font-size: 0.8125rem; font-weight: 600; color: #1e293b; margin-bottom: 0.25rem; }
.history-meta { font-size: 0.6875rem; color: #94a3b8; display: flex; gap: 0.75rem; }
.history-delete {
  position: absolute; right: 0.5rem; top: 50%; transform: translateY(-50%);
  width: 1.5rem; height: 1.5rem; border: none; background: transparent;
  color: #cbd5e1; cursor: pointer; opacity: 0; transition: all 0.2s;
  display: flex; align-items: center; justify-content: center;
}
.history-item:hover .history-delete { opacity: 1; }
.history-delete:hover { color: #ef4444; }
.history-delete svg { width: 0.875rem; height: 0.875rem; }

/* ===== 审批卡片 ===== */
.approval-card {
  padding: 0.875rem; border: 1px solid #e5e7eb; border-radius: 0.75rem;
  margin-bottom: 0.625rem; background: #fff;
}
.approval-card-header { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.375rem; }
.approval-card-desc { font-size: 0.75rem; color: #6b7280; margin-bottom: 0.75rem; }
.approval-card-actions { display: flex; gap: 0.5rem; }
.approve-btn, .reject-btn {
  flex: 1; padding: 0.4rem; border: none; border-radius: 0.5rem;
  font-size: 0.75rem; font-weight: 600; cursor: pointer; transition: all 0.2s;
}
.approve-btn { background: #dcfce7; color: #16a34a; }
.approve-btn:hover { background: #16a34a; color: #fff; }
.reject-btn { background: #fee2e2; color: #dc2626; }
.reject-btn:hover { background: #dc2626; color: #fff; }

/* ===== 输入区 ===== */
.panel-footer { padding: 0.75rem 1rem; border-top: 1px solid #f1f5f9; background: #fff; }
.input-wrapper {
  display: flex; align-items: flex-end; gap: 0.5rem;
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 0.875rem;
  padding: 0.5rem 0.5rem 0.5rem 1rem;
  transition: border-color 0.2s, box-shadow 0.2s;
}
.input-wrapper:focus-within {
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
}
.chat-input {
  flex: 1; border: none; background: transparent; outline: none;
  font-size: 0.8125rem; line-height: 1.5; color: #1e293b;
  resize: none; max-height: 7.5rem; font-family: inherit;
}
.chat-input::placeholder { color: #94a3b8; }
.send-btn {
  width: 2.25rem; height: 2.25rem; flex-shrink: 0;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  border: none; border-radius: 0.625rem; color: #fff;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  transition: all 0.2s;
}
.send-btn:hover:not(:disabled) { transform: scale(1.05); box-shadow: 0 2px 8px rgba(99, 102, 241, 0.4); }
.send-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.send-btn svg { width: 1rem; height: 1rem; }
.input-hint {
  font-size: 0.625rem; color: #94a3b8; text-align: center; margin-top: 0.375rem;
  display: flex; align-items: center; justify-content: center; gap: 0.25rem;
}
.hint-sep { color: #d1d5db; }
.hint-general { color: #6366f1; }
.hint-platform { color: #0ea5e9; }
.current-model-hint {
  color: #6366f1; font-weight: 600;
}

/* ===== 意图标签 ===== */
.intent-tag {
  display: inline-flex; align-items: center; gap: 0.25rem;
  padding: 0.1875rem 0.5rem; border-radius: 0.75rem;
  font-size: 0.5625rem; font-weight: 600;
  margin-bottom: 0.375rem; line-height: 1;
}
.intent-icon { font-size: 0.6875rem; line-height: 1; }
.intent-label { white-space: nowrap; }
.intent-tools {
  font-weight: 400; opacity: 0.7; font-family: 'Fira Code', monospace;
  font-size: 0.5rem; max-width: 10rem; overflow: hidden;
  text-overflow: ellipsis; white-space: nowrap;
}
.intent-tag.general {
  background: #f1f5f9; color: #64748b;
}
.intent-tag.platform {
  background: #e0f2fe; color: #0369a1;
}
.intent-tag.approval {
  background: #fef3c7; color: #92400e;
}
.intent-tag.danger {
  background: #fee2e2; color: #991b1b;
}
.intent-tag.error {
  background: #fee2e2; color: #dc2626;
}

/* ===== 错误消息样式 ===== */
.msg-bubble.msg-error {
  border-left: 3px solid #ef4444;
}
.error-detail {
  margin-top: 0.5rem;
  border-top: 1px dashed #e5e7eb;
  padding-top: 0.375rem;
}
.error-detail-header {
  display: flex; align-items: center; gap: 0.25rem;
  cursor: pointer; font-size: 0.6875rem; color: #6b7280;
  user-select: none;
}
.error-detail-header:hover { color: #374151; }
.error-detail-icon { font-size: 0.5rem; }
.error-detail-body {
  margin-top: 0.25rem;
  padding: 0.375rem 0.5rem;
  background: #fef2f2;
  border-radius: 0.375rem;
  font-size: 0.625rem;
  font-family: 'Fira Code', monospace;
}
.error-field {
  display: flex; gap: 0.375rem; margin-bottom: 0.125rem;
}
.error-label {
  color: #9ca3af; flex-shrink: 0;
}
.error-value {
  color: #374151; word-break: break-all;
}
.error-tip {
  margin-top: 0.25rem;
  color: #9ca3af;
  font-style: italic;
  font-size: 0.5625rem;
}

/* ===== 滚动条美化 ===== */
.panel-body::-webkit-scrollbar { width: 4px; }
.panel-body::-webkit-scrollbar-track { background: transparent; }
.panel-body::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 2px; }
.panel-body::-webkit-scrollbar-thumb:hover { background: #94a3b8; }

/* ===== 响应式 ===== */
@media (max-width: 768px) {
  .ai-panel { width: calc(100vw - 2rem); right: 1rem; bottom: 5.5rem; height: 70vh; }
  .ai-fab { bottom: 1rem; right: 1rem; }
}
</style>
