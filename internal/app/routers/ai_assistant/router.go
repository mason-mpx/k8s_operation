package ai_assistant

import (
	"github.com/gin-gonic/gin"

	ai "k8soperation/internal/app/controllers/api/v1/ai"
)

type AIAssistantRouter struct{}

func NewAIAssistantRouter() *AIAssistantRouter {
	return &AIAssistantRouter{}
}

// Inject 注入 AI 助手 & 审批管理路由
// 路由前缀: /api/v1/ai/...
func (r *AIAssistantRouter) Inject(router *gin.RouterGroup) {
	chatCtrl := ai.NewAIAssistantController()
	approvalCtrl := ai.NewAIApprovalController()

	g := router.Group("/ai")
	{
		// ===== AI 助手状态 =====
		g.GET("/status", chatCtrl.Status)
		g.GET("/models", chatCtrl.Models) // 获取可用提供商+模型列表
		g.GET("/logs", chatCtrl.Logs)     // AI 日志查询（排查问题用）

		// ===== AI 对话 =====
		g.POST("/chat", chatCtrl.Chat)                // 普通对话
		g.POST("/chat/stream", chatCtrl.ChatStream)    // 流式对话 (SSE)
		g.POST("/quick-ask", chatCtrl.QuickAsk)        // 快捷问答
		g.POST("/intent", chatCtrl.IntentAnalyze)      // 意图分析

		// ===== 会话管理 =====
		g.GET("/conversations", chatCtrl.ConversationList)              // 会话列表
		g.GET("/conversations/:id/messages", chatCtrl.ConversationMessages) // 消息历史
		g.DELETE("/conversations/:id", chatCtrl.ConversationDelete)     // 删除会话

		// ===== 审批管理 =====
		g.GET("/approvals", approvalCtrl.List)                         // 审批列表（管理员）
		g.GET("/approvals/mine", approvalCtrl.MyList)                  // 我的审批申请
		g.GET("/approvals/pending-count", approvalCtrl.PendingCount)   // 待审批数量
		g.GET("/approvals/stats", approvalCtrl.Stats)                  // 审批统计数据
		g.GET("/approvals/:id", approvalCtrl.Detail)                   // 审批详情
		g.POST("/approvals/:id/approve", approvalCtrl.Approve)        // 通过审批
		g.POST("/approvals/:id/reject", approvalCtrl.Reject)          // 拒绝审批
		g.POST("/approvals/:id/cancel", approvalCtrl.Cancel)          // 取消审批
		g.PUT("/approvals/:id", approvalCtrl.Update)                   // 更新审批备注
		g.DELETE("/approvals/:id", approvalCtrl.Delete)                // 删除审批记录
	}
}
