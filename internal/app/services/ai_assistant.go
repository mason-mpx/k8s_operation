package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go.uber.org/zap"

	"k8soperation/global"
	"k8soperation/internal/app/models"
	"k8soperation/pkg/openai"
)

// aiLog 获取 AI 专属日志器（兑底到系统日志）
func aiLog() *zap.Logger {
	if global.AILogger != nil {
		return global.AILogger.Logger()
	}
	if global.Logger != nil {
		return global.Logger.Logger()
	}
	return zap.NewNop()
}

// =========================================================================
// AI 助手 Service —— Function Calling 对话 + 自动执行 + 高危审批
// =========================================================================

// AI 客户端单例（懒加载）—— 仅作为无指定 provider/model 时的默认回退
var aiClient *openai.Client

// getAIClientWithModel 通过 Registry 获取指定提供商+模型的客户端
func getAIClientWithModel(providerID, modelID string) (*openai.Client, error) {
	if global.AISetting == nil || !global.AISetting.Enabled {
		return nil, fmt.Errorf("AI 助手未启用")
	}

	// 优先使用 Registry
	if global.AIRegistry != nil {
		systemPrompt := global.AISetting.SystemPrompt
		if systemPrompt == "" {
			systemPrompt = defaultSystemPrompt
		}
		return global.AIRegistry.GetClient(providerID, modelID, systemPrompt)
	}

	// 回退到旧版单客户端
	return getAIClient()
}

// getAIClient 获取默认 AI 客户端（兼容旧版）
func getAIClient() (*openai.Client, error) {
	if global.AISetting == nil || !global.AISetting.Enabled {
		return nil, fmt.Errorf("AI 助手未启用")
	}
	if aiClient != nil {
		return aiClient, nil
	}

	systemPrompt := global.AISetting.SystemPrompt
	if systemPrompt == "" {
		systemPrompt = defaultSystemPrompt
	}

	aiClient = openai.NewClient(openai.Config{
		APIKey:       global.AISetting.APIKey,
		BaseURL:      global.AISetting.BaseURL,
		Model:        global.AISetting.Model,
		MaxTokens:    global.AISetting.MaxTokens,
		Temperature:  global.AISetting.Temperature,
		SystemPrompt: systemPrompt,
	})
	return aiClient, nil
}

const defaultSystemPrompt = `你是 K8s 管理平台的智能操作助手。你可以通过工具函数直接操作平台：
1. 查询和管理 Kubernetes 集群资源（Pod、Deployment、Service、Node、Namespace 等）
2. 执行资源操作（创建、删除、扩缩容、重启、回滚、镜像更新）
3. 管理 CI/CD 流水线（查询、触发构建）
4. 节点管理（查询、cordon/uncordon、drain）
5. 集群级资源管理（ConfigMap、Secret、Ingress、PVC 等）

重要规则：
- 用简洁专业的中文回答
- 当用户查询资源时，优先调用工具函数获取真实数据，而不是编造
- 用户没有指定 cluster_id 时，先调用 list_clusters 获取集群列表
- 查询类操作直接执行，写操作和删除操作会需要人工审批
- 将工具返回的数据整理成对用户友好的格式进行回答`

// =========================================================================
// 会话管理
// =========================================================================

// AIConversationCreate 创建新会话
func (s *Services) AIConversationCreate(ctx context.Context, userID uint32, title string) (*models.AIConversation, error) {
	if title == "" {
		title = "新对话"
	}
	conv := &models.AIConversation{
		UserID: userID,
		Title:  title,
		Status: 1,
	}
	if err := s.dao.AIConversationCreate(conv); err != nil {
		return nil, err
	}
	return conv, nil
}

// AIConversationList 获取用户会话列表
func (s *Services) AIConversationList(ctx context.Context, userID uint32, page, pageSize int) ([]*models.AIConversation, int64, error) {
	return s.dao.AIConversationList(userID, page, pageSize)
}

// AIConversationDelete 归档（软删除）会话
func (s *Services) AIConversationDelete(ctx context.Context, convID, userID uint32) error {
	return s.dao.AIConversationDelete(convID, userID)
}

// AIMessageHistory 获取会话历史消息
func (s *Services) AIMessageHistory(ctx context.Context, convID, userID uint32) ([]*models.AIMessage, error) {
	// 先验证会话归属
	if _, err := s.dao.AIConversationGet(convID, userID); err != nil {
		return nil, fmt.Errorf("会话不存在或无权访问")
	}
	return s.dao.AIMessageListByConversation(convID)
}

// =========================================================================
// AI 对话（核心逻辑）
// =========================================================================

// AIChatRequest 聊天请求
type AIChatRequest struct {
	ConversationID uint32 `json:"conversation_id"` // 可选，0 = 新建会话
	Message        string `json:"message"`
	ProviderID     string `json:"provider_id,omitempty"` // 可选，指定 AI 提供商
	ModelID        string `json:"model_id,omitempty"`    // 可选，指定模型
	UserID         uint32 `json:"-"`                     // 从 JWT 中获取
}

// AIChatResponse 聊天响应
type AIChatResponse struct {
	ConversationID uint32           `json:"conversation_id"`
	Reply          string           `json:"reply"`
	NeedApproval   bool             `json:"need_approval"`
	ApprovalID     uint32           `json:"approval_id,omitempty"`
	ToolsCalled    []string         `json:"tools_called,omitempty"`  // 本次对话调用了哪些工具
	PendingTools   []PendingToolInfo `json:"pending_tools,omitempty"` // 等待审批的工具
}

// PendingToolInfo 等待审批的工具信息
type PendingToolInfo struct {
	ToolName   string `json:"tool_name"`
	ApprovalID uint32 `json:"approval_id"`
	RiskLevel  string `json:"risk_level"`
	Summary    string `json:"summary"`
}

// AIChat 智能对话（Function Calling + 自动执行 + 高危审批）
func (s *Services) AIChat(ctx context.Context, req *AIChatRequest, factory *ClusterClientFactory) (*AIChatResponse, error) {
	start := time.Now()
	l := aiLog().With(
		zap.Uint32("user_id", req.UserID),
		zap.String("provider", req.ProviderID),
		zap.String("model", req.ModelID),
	)
	l.Info("[AI-Chat] 对话开始",
		zap.Uint32("conv_id", req.ConversationID),
		zap.String("message", truncateMsg(req.Message, 200)),
	)

	client, err := getAIClientWithModel(req.ProviderID, req.ModelID)
	if err != nil {
		l.Error("[AI-Chat] 获取客户端失败", zap.Error(err))
		return nil, err
	}

	// 1. 获取或创建会话
	convID := req.ConversationID
	if convID == 0 {
		conv, err := s.AIConversationCreate(ctx, req.UserID, "")
		if err != nil {
			return nil, fmt.Errorf("创建会话失败: %w", err)
		}
		convID = conv.ID
	}

	// 2. 保存用户消息
	userMsg := &models.AIMessage{
		ConversationID: convID,
		Role:           "user",
		Content:        req.Message,
	}
	if err := s.dao.AIMessageCreate(userMsg); err != nil {
		global.Logger.Error("保存用户消息失败", zap.Error(err))
	}

	// 3. 构建历史上下文
	messages, err := s.buildHistoryMessages(convID)
	if err != nil {
		global.Logger.Warn("获取历史消息失败", zap.Error(err))
		messages = []openai.Message{{Role: "user", Content: req.Message}}
	}

	// 4. 构建工具列表 & 调用 ChatWithTools
	tools := BuildAllTools()
	resp := &AIChatResponse{ConversationID: convID}

	// Function Calling 循环（最多 5 轮，防止死循环）
	const maxRounds = 5
	for round := 0; round < maxRounds; round++ {
		l.Info("[AI-Chat] Function Calling 轮次",
			zap.Int("round", round+1),
			zap.Int("context_msgs", len(messages)),
		)

		result, err := client.ChatWithTools(ctx, messages, tools)
		if err != nil {
			l.Error("[AI-Chat] AI 请求失败",
				zap.Int("round", round+1),
				zap.Duration("total_latency", time.Since(start)),
				zap.Error(err),
			)
			return nil, fmt.Errorf("AI 请求失败: %w", err)
		}

		// 如果 GPT 没有调用工具，直接返回文本回复
		if len(result.ToolCalls) == 0 {
			resp.Reply = result.Content
			break
		}

		// 将 assistant 的 tool_calls 消息加入上下文（必须携带 ToolCalls，否则 API 报错）
		messages = append(messages, openai.Message{
			Role:      "assistant",
			Content:   result.Content,
			ToolCalls: result.ToolCalls,
		})

		// 逐个处理工具调用
		hasApproval := false
		for _, tc := range result.ToolCalls {
			toolName := tc.Function
			meta, _ := GetToolMeta(toolName)

			// 检查是否需要审批
			if meta.NeedApproval {
				l.Warn("[AI-Chat] 工具需要审批",
					zap.String("tool", toolName),
					zap.String("risk_level", meta.RiskLevel),
					zap.String("args", truncateMsg(tc.Args, 500)),
				)
				// 高危/写操作 → 创建审批请求，不直接执行
				approval, aErr := s.createToolApproval(ctx, convID, req.UserID, tc, meta)
				if aErr != nil {
					global.Logger.Error("创建审批请求失败", zap.Error(aErr))
					// 审批创建失败时，告知 GPT
					messages = append(messages, openai.Message{
						Role:       "tool",
						Content:    fmt.Sprintf(`{"error": "创建审批失败: %s"}`, aErr.Error()),
						ToolCallID: tc.ID,
					})
				} else {
					hasApproval = true
					resp.NeedApproval = true
					resp.ApprovalID = approval.ID
					resp.PendingTools = append(resp.PendingTools, PendingToolInfo{
						ToolName:   toolName,
						ApprovalID: approval.ID,
						RiskLevel:  meta.RiskLevel,
						Summary:    meta.Description,
					})
					// 告知 GPT 该操作需要审批
					messages = append(messages, openai.Message{
						Role:       "tool",
						Content:    fmt.Sprintf(`{"status": "pending_approval", "approval_id": %d, "message": "该操作属于%s级别，已提交审批请求(ID:%d)，等待管理员确认后执行"}`, approval.ID, meta.RiskLevel, approval.ID),
						ToolCallID: tc.ID,
					})
				}
			} else {
				// 只读操作 → 直接执行
				toolStart := time.Now()
				toolResult, execErr := s.ExecuteToolCall(ctx, factory, toolName, tc.Args)
				toolLatency := time.Since(toolStart)

				if execErr != nil {
					l.Error("[AI-Chat] 工具执行失败",
						zap.String("tool", toolName),
						zap.Duration("tool_latency", toolLatency),
						zap.String("args", truncateMsg(tc.Args, 500)),
						zap.Error(execErr),
					)
					toolResult = fmt.Sprintf(`{"error": "%s"}`, execErr.Error())
				} else {
					l.Info("[AI-Chat] 工具执行成功",
						zap.String("tool", toolName),
						zap.Duration("tool_latency", toolLatency),
						zap.Int("result_length", len(toolResult)),
					)
				}
				resp.ToolsCalled = append(resp.ToolsCalled, toolName)

				// 将执行结果反馈给 GPT
				messages = append(messages, openai.Message{
					Role:       "tool",
					Content:    toolResult,
					ToolCallID: tc.ID,
				})
			}
		}

		// 如果有审批操作，让 GPT 生成最终回复后结束循环
		if hasApproval {
			finalResult, fErr := client.ContinueWithToolResults(ctx, messages, tools)
			if fErr == nil && finalResult.Content != "" {
				resp.Reply = finalResult.Content
			} else {
				// 回退方案
				resp.Reply = s.buildApprovalReplyText(resp.PendingTools)
			}
			break
		}
		// 否则继续循环，让 GPT 根据工具结果继续对话
	}

	// 5. 保存 AI 回复消息
	toolsJSON, _ := json.Marshal(resp.ToolsCalled)
	assistantMsg := &models.AIMessage{
		ConversationID: convID,
		Role:           "assistant",
		Content:        resp.Reply,
		IntentJSON:     string(toolsJSON),
	}
	if err := s.dao.AIMessageCreate(assistantMsg); err != nil {
		global.Logger.Error("保存AI回复消息失败", zap.Error(err))
	}

	// 6. 自动更新会话标题（首条消息时）
	if req.ConversationID == 0 {
		title := req.Message
		if len([]rune(title)) > 30 {
			title = string([]rune(title)[:30]) + "..."
		}
		_ = s.dao.AIConversationUpdateTitle(convID, title)
	}

	totalLatency := time.Since(start)
	l.Info("[AI-Chat] 对话完成",
		zap.Uint32("conv_id", convID),
		zap.Duration("total_latency", totalLatency),
		zap.Int("tools_called", len(resp.ToolsCalled)),
		zap.Strings("tools", resp.ToolsCalled),
		zap.Bool("need_approval", resp.NeedApproval),
		zap.Int("reply_length", len(resp.Reply)),
	)

	return resp, nil
}

// buildApprovalReplyText 构建审批提示文本（GPT 生成失败时的回退方案）
func (s *Services) buildApprovalReplyText(pendingTools []PendingToolInfo) string {
	text := "⚠️ **检测到需要审批的操作**\n\n"
	for _, pt := range pendingTools {
		text += fmt.Sprintf("- **%s**（风险等级: %s，审批ID: %d）\n", pt.Summary, pt.RiskLevel, pt.ApprovalID)
	}
	text += "\n请等待管理员审批后自动执行，或在「审批管理」页面查看进度。"
	return text
}

// AIChatStream 流式对话（SSE）—— 流式不支持 Function Calling，回退为普通流式对话
func (s *Services) AIChatStream(ctx context.Context, req *AIChatRequest, callback openai.StreamCallback) (*AIChatResponse, error) {
	start := time.Now()
	l := aiLog().With(
		zap.Uint32("user_id", req.UserID),
		zap.String("provider", req.ProviderID),
		zap.String("model", req.ModelID),
	)
	l.Info("[AI-Stream] 流式对话开始",
		zap.Uint32("conv_id", req.ConversationID),
		zap.String("message", truncateMsg(req.Message, 200)),
	)

	client, err := getAIClientWithModel(req.ProviderID, req.ModelID)
	if err != nil {
		l.Error("[AI-Stream] 获取客户端失败", zap.Error(err))
		return nil, err
	}

	// 获取或创建会话
	convID := req.ConversationID
	if convID == 0 {
		conv, err := s.AIConversationCreate(ctx, req.UserID, "")
		if err != nil {
			return nil, fmt.Errorf("创建会话失败: %w", err)
		}
		convID = conv.ID
	}

	// 保存用户消息
	userMsg := &models.AIMessage{
		ConversationID: convID,
		Role:           "user",
		Content:        req.Message,
	}
	_ = s.dao.AIMessageCreate(userMsg)

	// 构建历史上下文
	messages, err := s.buildHistoryMessages(convID)
	if err != nil {
		messages = []openai.Message{{Role: "user", Content: req.Message}}
	}

	// 流式调用
	fullReply, err := client.ChatStream(ctx, messages, callback)
	if err != nil {
		l.Error("[AI-Stream] 流式调用失败",
			zap.Duration("latency", time.Since(start)),
			zap.Error(err),
		)
		return nil, err
	}

	l.Info("[AI-Stream] 流式对话完成",
		zap.Duration("latency", time.Since(start)),
		zap.Int("reply_length", len(fullReply)),
	)

	// 保存 AI 回复
	assistantMsg := &models.AIMessage{
		ConversationID: convID,
		Role:           "assistant",
		Content:        fullReply,
	}
	_ = s.dao.AIMessageCreate(assistantMsg)

	// 自动更新标题
	if req.ConversationID == 0 {
		title := req.Message
		if len([]rune(title)) > 30 {
			title = string([]rune(title)[:30]) + "..."
		}
		_ = s.dao.AIConversationUpdateTitle(convID, title)
	}

	return &AIChatResponse{
		ConversationID: convID,
		Reply:          fullReply,
	}, nil
}

// =========================================================================
// 审批管理
// =========================================================================

// AIApprovalList 获取审批列表（管理员用）
func (s *Services) AIApprovalList(ctx context.Context, status uint8, page, pageSize int) ([]*models.AIApprovalRequest, int64, error) {
	return s.dao.AIApprovalListAll(status, page, pageSize)
}

// AIApprovalMyList 获取我的审批申请
func (s *Services) AIApprovalMyList(ctx context.Context, userID uint32, page, pageSize int) ([]*models.AIApprovalRequest, int64, error) {
	return s.dao.AIApprovalListByUser(userID, page, pageSize)
}

// AIApprovalDetail 获取审批详情
func (s *Services) AIApprovalDetail(ctx context.Context, approvalID uint32) (*models.AIApprovalRequest, []*models.AIApprovalLog, error) {
	req, err := s.dao.AIApprovalGetByID(approvalID)
	if err != nil {
		return nil, nil, err
	}
	logs, err := s.dao.AIApprovalLogList(approvalID)
	if err != nil {
		return req, nil, err
	}
	return req, logs, nil
}

// AIApprovalApprove 通过审批（通过后自动执行工具调用）
func (s *Services) AIApprovalApprove(ctx context.Context, approvalID, approverID uint32, comment string, factory *ClusterClientFactory) error {
	req, err := s.dao.AIApprovalGetByID(approvalID)
	if err != nil {
		return fmt.Errorf("审批请求不存在")
	}
	if req.Status != models.AIApprovalPending {
		return fmt.Errorf("审批已处理")
	}
	// 检查是否过期
	if req.ExpireAt > 0 && uint32(time.Now().Unix()) > req.ExpireAt {
		_ = s.dao.AIApprovalUpdateStatus(approvalID, models.AIApprovalExpired, 0, "已过期")
		return fmt.Errorf("审批已过期")
	}

	if err := s.dao.AIApprovalUpdateStatus(approvalID, models.AIApprovalApproved, approverID, comment); err != nil {
		return err
	}

	// 记录审批日志
	_ = s.dao.AIApprovalLogCreate(&models.AIApprovalLog{
		ApprovalID: approvalID,
		UserID:     approverID,
		Action:     "approve",
		Comment:    comment,
	})

	// 审批通过后自动执行工具调用
	if req.ToolName != "" && !req.Executed && factory != nil {
		go s.executeApprovedTool(context.Background(), req, factory)
	}

	return nil
}

// executeApprovedTool 异步执行审批通过的工具调用
func (s *Services) executeApprovedTool(ctx context.Context, approval *models.AIApprovalRequest, factory *ClusterClientFactory) {
	global.Logger.Info("开始执行审批通过的操作",
		zap.Uint32("approval_id", approval.ID),
		zap.String("tool", approval.ToolName))

	result, err := s.ExecuteToolCall(ctx, factory, approval.ToolName, approval.ToolArgsJSON)
	if err != nil {
		result = fmt.Sprintf(`{"error": "%s"}`, err.Error())
		global.Logger.Error("审批操作执行失败",
			zap.Uint32("approval_id", approval.ID), zap.Error(err))
	}

	// 更新执行结果
	_ = s.dao.AIApprovalUpdateExecuteResult(approval.ID, result)

	// 记录执行日志
	_ = s.dao.AIApprovalLogCreate(&models.AIApprovalLog{
		ApprovalID: approval.ID,
		UserID:     0, // 系统自动执行
		Action:     "execute",
		Comment:    fmt.Sprintf("审批通过后自动执行: %s", approval.ToolName),
	})

	global.Logger.Info("审批操作执行完成",
		zap.Uint32("approval_id", approval.ID),
		zap.String("tool", approval.ToolName))
}

// AIApprovalReject 拒绝审批
func (s *Services) AIApprovalReject(ctx context.Context, approvalID, approverID uint32, comment string) error {
	req, err := s.dao.AIApprovalGetByID(approvalID)
	if err != nil {
		return fmt.Errorf("审批请求不存在")
	}
	if req.Status != models.AIApprovalPending {
		return fmt.Errorf("审批已处理")
	}

	if err := s.dao.AIApprovalUpdateStatus(approvalID, models.AIApprovalRejected, approverID, comment); err != nil {
		return err
	}

	_ = s.dao.AIApprovalLogCreate(&models.AIApprovalLog{
		ApprovalID: approvalID,
		UserID:     approverID,
		Action:     "reject",
		Comment:    comment,
	})

	return nil
}

// AIApprovalCancel 取消审批（申请人自己取消）
func (s *Services) AIApprovalCancel(ctx context.Context, approvalID, userID uint32) error {
	req, err := s.dao.AIApprovalGetByID(approvalID)
	if err != nil {
		return fmt.Errorf("审批请求不存在")
	}
	if req.RequestUserID != userID {
		return fmt.Errorf("只有申请人可以取消")
	}
	if req.Status != models.AIApprovalPending {
		return fmt.Errorf("审批已处理")
	}

	if err := s.dao.AIApprovalUpdateStatus(approvalID, models.AIApprovalCanceled, 0, "申请人取消"); err != nil {
		return err
	}

	_ = s.dao.AIApprovalLogCreate(&models.AIApprovalLog{
		ApprovalID: approvalID,
		UserID:     userID,
		Action:     "cancel",
		Comment:    "申请人主动取消",
	})

	return nil
}

// AIApprovalPendingCount 获取待审批数量（用于前端 Badge）
func (s *Services) AIApprovalPendingCount(ctx context.Context) (int64, error) {
	_, total, err := s.dao.AIApprovalListPending(1, 1)
	return total, err
}

// =========================================================================
// 内部辅助方法
// =========================================================================

// buildHistoryMessages 构建历史消息上下文
func (s *Services) buildHistoryMessages(convID uint32) ([]openai.Message, error) {
	history, err := s.dao.AIMessageListByConversation(convID)
	if err != nil {
		return nil, err
	}

	maxRounds := 20
	if global.AISetting != nil && global.AISetting.MaxHistoryRound > 0 {
		maxRounds = global.AISetting.MaxHistoryRound
	}

	// 只取最近 N 轮
	start := 0
	if len(history) > maxRounds*2 {
		start = len(history) - maxRounds*2
	}

	var messages []openai.Message
	for _, msg := range history[start:] {
		// 跳过 tool 角色消息（中间态 Function Calling 结果，无法在历史中重放，
		// 因为对应的 assistant tool_calls 已丢失，API 会报 400 错误）
		if msg.Role == "tool" {
			continue
		}
		messages = append(messages, openai.Message{
			Role:    msg.Role,
			Content: msg.Content,
		})
	}
	return messages, nil
}

// createToolApproval 为 Function Calling 工具调用创建审批请求
func (s *Services) createToolApproval(ctx context.Context, convID, userID uint32, tc openai.ToolCall, meta ToolMeta) (*models.AIApprovalRequest, error) {
	expireMinutes := 30
	if global.AISetting != nil && global.AISetting.ApprovalExpire > 0 {
		expireMinutes = global.AISetting.ApprovalExpire
	}

	// 从参数中提取关键信息
	var args map[string]interface{}
	_ = json.Unmarshal([]byte(tc.Args), &args)

	namespace := ""
	if ns, ok := args["namespace"]; ok {
		namespace = fmt.Sprintf("%v", ns)
	}
	resourceName := ""
	if rn, ok := args["name"]; ok {
		resourceName = fmt.Sprintf("%v", rn)
	}
	var clusterID uint32
	if cid, ok := args["cluster_id"]; ok {
		switch v := cid.(type) {
		case float64:
			clusterID = uint32(v)
		}
	}

	req := &models.AIApprovalRequest{
		ConversationID: convID,
		RequestUserID:  userID,
		Intent:         tc.Function,
		Resource:       meta.Description,
		ResourceName:   resourceName,
		Namespace:      namespace,
		ClusterID:      clusterID,
		RiskLevel:      meta.RiskLevel,
		OperationJSON:  tc.Args,
		ToolName:       tc.Function,
		ToolArgsJSON:   tc.Args,
		ToolCallID:     tc.ID,
		Summary:        fmt.Sprintf("%s: %s/%s", meta.Description, namespace, resourceName),
		Status:         models.AIApprovalPending,
		ExpireAt:       uint32(time.Now().Add(time.Duration(expireMinutes) * time.Minute).Unix()),
	}
	if err := s.dao.AIApprovalCreate(req); err != nil {
		return nil, err
	}

	// 记录审批创建日志
	_ = s.dao.AIApprovalLogCreate(&models.AIApprovalLog{
		ApprovalID: req.ID,
		UserID:     userID,
		Action:     "create",
		Comment:    fmt.Sprintf("AI Function Calling 检测到%s级操作，自动创建审批: %s", meta.RiskLevel, meta.Description),
	})

	return req, nil
}

// truncateMsg 截断消息用于日志（避免过长日志）
func truncateMsg(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen]) + "..."
}
