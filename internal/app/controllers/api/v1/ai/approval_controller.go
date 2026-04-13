package ai

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"k8soperation/global"
	"k8soperation/internal/app/services"
	"k8soperation/internal/errorcode"
	"k8soperation/pkg/app/response"
)

// AIApprovalController 高危操作审批控制器
type AIApprovalController struct {
	factory *services.ClusterClientFactory
}

func NewAIApprovalController() *AIApprovalController {
	svc := services.NewServices()
	return &AIApprovalController{
		factory: services.NewClusterClientFactory(svc),
	}
}

// List 获取审批列表（管理员）
// @Summary 获取审批列表
// @Description 获取所有高危操作审批请求，支持按状态筛选
// @Tags AI 审批管理
// @Produce json
// @Param status query int false "状态筛选: 1=待审批 2=已通过 3=已拒绝 4=已过期 5=已取消" default(0)
// @Param page query int false "页码" default(1)
// @Param page_size query int false "每页数量" default(20)
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals [get]
func (c *AIApprovalController) List(ctx *gin.Context) {
	resp := response.NewResponse(ctx)

	status, _ := strconv.ParseUint(ctx.DefaultQuery("status", "0"), 10, 8)
	page, _ := strconv.Atoi(ctx.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(ctx.DefaultQuery("page_size", "20"))

	svc := services.NewServices()
	list, total, err := svc.AIApprovalList(ctx.Request.Context(), uint8(status), page, pageSize)
	if err != nil {
		resp.ToErrorResponse(errorcode.ServerError.WithDetails(err.Error()))
		return
	}

	resp.SuccessList(list, total)
}

// MyList 获取我的审批申请
// @Summary 获取我的审批申请
// @Tags AI 审批管理
// @Produce json
// @Param page query int false "页码" default(1)
// @Param page_size query int false "每页数量" default(20)
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/mine [get]
func (c *AIApprovalController) MyList(ctx *gin.Context) {
	resp := response.NewResponse(ctx)
	userID := getUserID(ctx)
	if userID == 0 {
		resp.ToErrorResponse(errorcode.UserNotLogin)
		return
	}

	page, _ := strconv.Atoi(ctx.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(ctx.DefaultQuery("page_size", "20"))

	svc := services.NewServices()
	list, total, err := svc.AIApprovalMyList(ctx.Request.Context(), userID, page, pageSize)
	if err != nil {
		resp.ToErrorResponse(errorcode.ServerError.WithDetails(err.Error()))
		return
	}

	resp.SuccessList(list, total)
}

// Detail 获取审批详情
// @Summary 获取审批详情
// @Tags AI 审批管理
// @Param id path int true "审批ID"
// @Produce json
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/{id} [get]
func (c *AIApprovalController) Detail(ctx *gin.Context) {
	resp := response.NewResponse(ctx)

	approvalID, _ := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if approvalID == 0 {
		resp.ToErrorResponse(errorcode.InvalidParams.WithDetails("无效的审批ID"))
		return
	}

	svc := services.NewServices()
	req, logs, err := svc.AIApprovalDetail(ctx.Request.Context(), uint32(approvalID))
	if err != nil {
		resp.ToErrorResponse(errorcode.AIApprovalNotFound)
		return
	}

	resp.Success(gin.H{
		"approval": req,
		"logs":     logs,
	})
}

// Approve 通过审批
// @Summary 通过审批
// @Description 管理员通过高危操作审批
// @Tags AI 审批管理
// @Accept json
// @Produce json
// @Param id path int true "审批ID"
// @Param body body object true "审批备注" example({"comment":"确认执行"})
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/{id}/approve [post]
func (c *AIApprovalController) Approve(ctx *gin.Context) {
	resp := response.NewResponse(ctx)
	userID := getUserID(ctx)
	if userID == 0 {
		resp.ToErrorResponse(errorcode.UserNotLogin)
		return
	}

	approvalID, _ := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if approvalID == 0 {
		resp.ToErrorResponse(errorcode.InvalidParams.WithDetails("无效的审批ID"))
		return
	}

	var body struct {
		Comment string `json:"comment"`
	}
	_ = ctx.ShouldBindJSON(&body)

	svc := services.NewServices()
	if err := svc.AIApprovalApprove(ctx.Request.Context(), uint32(approvalID), userID, body.Comment, c.factory); err != nil {
		global.Logger.Error("审批通过失败", zap.Error(err))
		resp.ToErrorResponse(errorcode.AIApprovalProcessed.WithDetails(err.Error()))
		return
	}

	resp.Success(gin.H{"message": "审批已通过"})
}

// Reject 拒绝审批
// @Summary 拒绝审批
// @Description 管理员拒绝高危操作审批
// @Tags AI 审批管理
// @Accept json
// @Produce json
// @Param id path int true "审批ID"
// @Param body body object true "拒绝原因" example({"comment":"操作风险过高"})
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/{id}/reject [post]
func (c *AIApprovalController) Reject(ctx *gin.Context) {
	resp := response.NewResponse(ctx)
	userID := getUserID(ctx)
	if userID == 0 {
		resp.ToErrorResponse(errorcode.UserNotLogin)
		return
	}

	approvalID, _ := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if approvalID == 0 {
		resp.ToErrorResponse(errorcode.InvalidParams.WithDetails("无效的审批ID"))
		return
	}

	var body struct {
		Comment string `json:"comment"`
	}
	_ = ctx.ShouldBindJSON(&body)

	svc := services.NewServices()
	if err := svc.AIApprovalReject(ctx.Request.Context(), uint32(approvalID), userID, body.Comment); err != nil {
		global.Logger.Error("审批拒绝失败", zap.Error(err))
		resp.ToErrorResponse(errorcode.AIApprovalProcessed.WithDetails(err.Error()))
		return
	}

	resp.Success(gin.H{"message": "审批已拒绝"})
}

// Cancel 取消审批（申请人自己取消）
// @Summary 取消审批
// @Tags AI 审批管理
// @Param id path int true "审批ID"
// @Produce json
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/{id}/cancel [post]
func (c *AIApprovalController) Cancel(ctx *gin.Context) {
	resp := response.NewResponse(ctx)
	userID := getUserID(ctx)
	if userID == 0 {
		resp.ToErrorResponse(errorcode.UserNotLogin)
		return
	}

	approvalID, _ := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if approvalID == 0 {
		resp.ToErrorResponse(errorcode.InvalidParams.WithDetails("无效的审批ID"))
		return
	}

	svc := services.NewServices()
	if err := svc.AIApprovalCancel(ctx.Request.Context(), uint32(approvalID), userID); err != nil {
		global.Logger.Error("审批取消失败", zap.Error(err))
		resp.ToErrorResponse(errorcode.AIApprovalForbidden.WithDetails(err.Error()))
		return
	}

	resp.Success(gin.H{"message": "审批已取消"})
}

// PendingCount 获取待审批数量
// @Summary 获取待审批数量
// @Description 用于前端侧边栏 Badge 显示
// @Tags AI 审批管理
// @Produce json
// @Success 200 {object} response.SuccessResponse
// @Router /api/v1/ai/approvals/pending-count [get]
func (c *AIApprovalController) PendingCount(ctx *gin.Context) {
	resp := response.NewResponse(ctx)
	svc := services.NewServices()
	count, err := svc.AIApprovalPendingCount(ctx.Request.Context())
	if err != nil {
		global.Logger.Error("获取待审批数量失败", zap.Error(err))
		resp.ToErrorResponse(errorcode.ServerError.WithDetails(err.Error()))
		return
	}

	resp.Success(gin.H{"count": count})
}
