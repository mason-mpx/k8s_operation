package dao

import (
	"k8soperation/internal/app/models"
)

// =========================================================================
// AI 会话
// =========================================================================

func (d *Dao) AIConversationCreate(conv *models.AIConversation) error {
	return conv.Create(d.db)
}

func (d *Dao) AIConversationList(userID uint32, page, pageSize int) ([]*models.AIConversation, int64, error) {
	m := &models.AIConversation{}
	return m.ListByUser(d.db, userID, page, pageSize)
}

func (d *Dao) AIConversationGet(id, userID uint32) (*models.AIConversation, error) {
	m := &models.AIConversation{}
	return m.GetByID(d.db, id, userID)
}

func (d *Dao) AIConversationDelete(id, userID uint32) error {
	m := &models.AIConversation{}
	return m.Delete(d.db, id, userID)
}

func (d *Dao) AIConversationUpdateTitle(id uint32, title string) error {
	return d.db.Model(&models.AIConversation{}).Where("id = ?", id).Update("title", title).Error
}

// =========================================================================
// AI 消息
// =========================================================================

func (d *Dao) AIMessageCreate(msg *models.AIMessage) error {
	return msg.Create(d.db)
}

func (d *Dao) AIMessageListByConversation(convID uint32) ([]*models.AIMessage, error) {
	m := &models.AIMessage{}
	return m.ListByConversation(d.db, convID)
}

// =========================================================================
// AI 审批请求
// =========================================================================

func (d *Dao) AIApprovalCreate(req *models.AIApprovalRequest) error {
	return req.Create(d.db)
}

func (d *Dao) AIApprovalGetByID(id uint32) (*models.AIApprovalRequest, error) {
	m := &models.AIApprovalRequest{}
	return m.GetByID(d.db, id)
}

func (d *Dao) AIApprovalListPending(page, pageSize int) ([]*models.AIApprovalRequest, int64, error) {
	m := &models.AIApprovalRequest{}
	return m.ListPending(d.db, page, pageSize)
}

func (d *Dao) AIApprovalListAll(status uint8, page, pageSize int) ([]*models.AIApprovalRequest, int64, error) {
	m := &models.AIApprovalRequest{}
	return m.ListAll(d.db, status, page, pageSize)
}

func (d *Dao) AIApprovalListByUser(userID uint32, page, pageSize int) ([]*models.AIApprovalRequest, int64, error) {
	m := &models.AIApprovalRequest{}
	return m.ListByUser(d.db, userID, page, pageSize)
}

func (d *Dao) AIApprovalUpdateStatus(id uint32, status uint8, approverID uint32, comment string) error {
	m := &models.AIApprovalRequest{}
	return m.UpdateStatus(d.db, id, status, approverID, comment)
}

func (d *Dao) AIApprovalUpdateExecuteResult(id uint32, result string) error {
	return d.db.Model(&models.AIApprovalRequest{}).Where("id = ?", id).Updates(map[string]interface{}{
		"executed":       true,
		"execute_result": result,
	}).Error
}

// =========================================================================
// AI 审批日志
// =========================================================================

func (d *Dao) AIApprovalLogCreate(log *models.AIApprovalLog) error {
	return log.Create(d.db)
}

func (d *Dao) AIApprovalLogList(approvalID uint32) ([]*models.AIApprovalLog, error) {
	m := &models.AIApprovalLog{}
	return m.ListByApproval(d.db, approvalID)
}
