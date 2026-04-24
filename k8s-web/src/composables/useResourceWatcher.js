/**
 * useResourceWatcher.js - K8s 资源状态实时监听 composable
 * 
 * 功能：
 * - 镜像更新后自动开启快速轮询，追踪 Rollout 状态变化
 * - 实时拉取资源事件（Normal/Warning），展示在事件面板
 * - 状态到达 Running/Complete 后自动停止监听
 * - 支持 Deployment / StatefulSet / DaemonSet / Job 等工作负载
 * 
 * 设计参考：KubeSphere 资源状态追踪机制
 */
import { ref, reactive, onBeforeUnmount } from 'vue'

/**
 * @param {Function} fetchStatusFn - 获取资源最新状态的函数，返回 { status, readyReplicas, ... }
 * @param {Function} fetchEventsFn - 获取资源事件的函数，返回 events 数组
 */
export function useResourceWatcher() {
  // ========== 状态 ==========
  const watching = ref(false)          // 是否在监听中
  const watchTarget = ref(null)        // 当前监听的资源 { namespace, name, kind }
  const watchPhase = ref('')           // Updating / Progressing / Running / Failed
  const watchProgress = ref(0)         // 进度 0~100
  const watchEvents = ref([])          // 事件列表
  const watchStartTime = ref(null)     // 监听开始时间
  const watchElapsed = ref(0)          // 已用时间（秒）

  let pollTimer = null
  let eventTimer = null
  let elapsedTimer = null

  // ========== 核心：开始监听 ==========
  /**
   * 开始监听资源状态变化
   * @param {Object} target - { namespace, name, kind }
   * @param {Object} options
   * @param {Function} options.getStatus - async () => { status, readyReplicas, desiredReplicas, ... }
   * @param {Function} options.getEvents - async () => [{ type, reason, message, time }, ...]
   * @param {Function} [options.onComplete] - 状态到达终态时的回调
   * @param {number} [options.pollInterval=3000] - 状态轮询间隔（毫秒）
   * @param {number} [options.eventInterval=5000] - 事件轮询间隔（毫秒）
   * @param {number} [options.timeout=300000] - 超时自动停止（毫秒）
   */
  const startWatching = (target, options = {}) => {
    stopWatching() // 先停掉旧的

    const {
      getStatus,
      getEvents,
      onComplete,
      pollInterval = 3000,
      eventInterval = 5000,
      timeout = 300000, // 5 分钟
    } = options

    watchTarget.value = target
    watching.value = true
    watchPhase.value = 'Updating'
    watchProgress.value = 0
    watchEvents.value = []
    watchStartTime.value = Date.now()
    watchElapsed.value = 0

    // 计时器
    elapsedTimer = setInterval(() => {
      watchElapsed.value = Math.floor((Date.now() - watchStartTime.value) / 1000)
      // 超时自动停止
      if (Date.now() - watchStartTime.value > timeout) {
        watchPhase.value = 'Timeout'
        stopWatching()
      }
    }, 1000)

    // 状态轮询
    const pollStatus = async () => {
      if (!watching.value) return
      try {
        const status = await getStatus()
        if (!status) return

        // 计算进度和阶段
        const desired = status.desiredReplicas || status.replicas || 1
        const ready = status.readyReplicas || 0
        const updated = status.updatedReplicas || 0

        // 进度计算
        const progress = Math.min(100, Math.round((ready / Math.max(desired, 1)) * 100))
        watchProgress.value = progress

        // 阶段判定
        const s = (status.status || '').toLowerCase()
        if (s === 'running' || s === 'available' || s === 'complete') {
          if (ready >= desired && updated >= desired) {
            watchPhase.value = 'Running'
            // 成功回调
            onComplete?.({ success: true, elapsed: watchElapsed.value })
            // 延迟 2 秒停止，让用户看到最终状态
            setTimeout(() => stopWatching(), 2000)
            return
          }
        }

        if (s === 'failed' || s === 'crashloopbackoff' || s === 'error') {
          watchPhase.value = 'Failed'
          onComplete?.({ success: false, elapsed: watchElapsed.value })
          setTimeout(() => stopWatching(), 5000)
          return
        }

        // 进行中
        if (updated > 0 && updated < desired) {
          watchPhase.value = 'Progressing'
        } else if (ready < desired) {
          watchPhase.value = 'Updating'
        } else {
          watchPhase.value = 'Progressing'
        }
      } catch (e) {
        console.warn('[ResourceWatcher] poll status error:', e)
      }
    }

    // 事件轮询
    const pollEvents = async () => {
      if (!watching.value) return
      try {
        const events = await getEvents()
        if (Array.isArray(events) && events.length > 0) {
          // 合并去重（基于 time + message）
          const seen = new Set(watchEvents.value.map(e => `${e.time}|${e.message}`))
          const newEvents = events.filter(e => !seen.has(`${e.time}|${e.message}`))
          if (newEvents.length > 0) {
            watchEvents.value = [...newEvents, ...watchEvents.value].slice(0, 100) // 最多保留 100 条
          }
        }
      } catch (e) {
        console.warn('[ResourceWatcher] poll events error:', e)
      }
    }

    // 立即执行一次
    pollStatus()
    pollEvents()

    // 定时轮询
    pollTimer = setInterval(pollStatus, pollInterval)
    eventTimer = setInterval(pollEvents, eventInterval)
  }

  // ========== 停止监听 ==========
  const stopWatching = () => {
    watching.value = false
    clearInterval(pollTimer)
    clearInterval(eventTimer)
    clearInterval(elapsedTimer)
    pollTimer = null
    eventTimer = null
    elapsedTimer = null
  }

  // ========== 格式化 ==========
  const formatElapsed = (seconds) => {
    if (seconds < 60) return `${seconds}s`
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}m ${s}s`
  }

  const phaseColor = (phase) => {
    const map = {
      Updating: '#e0af68',
      Progressing: '#7aa2f7',
      Running: '#9ece6a',
      Failed: '#f7768e',
      Timeout: '#ff9e64',
    }
    return map[phase] || '#565f89'
  }

  const phaseIcon = (phase) => {
    const map = {
      Updating: '🔄',
      Progressing: '⏳',
      Running: '✅',
      Failed: '❌',
      Timeout: '⏰',
    }
    return map[phase] || '📌'
  }

  // ========== Cleanup ==========
  onBeforeUnmount(() => {
    stopWatching()
  })

  return {
    // state
    watching,
    watchTarget,
    watchPhase,
    watchProgress,
    watchEvents,
    watchElapsed,
    // methods
    startWatching,
    stopWatching,
    formatElapsed,
    phaseColor,
    phaseIcon,
  }
}
