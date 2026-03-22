package services

import (
	"k8soperation/internal/app/models"
	"k8soperation/internal/app/requests"
)

// UserCreate 创建用户
func (s *Services) UserCreate(parm *requests.UserCreateRequest) (*models.User, error) {
	return s.dao.UserCreate(parm.Username, parm.Password)
}

// UserDelete 删除用户
func (s *Services) UserDelete(param *requests.CommonIdRequest) error {
	return s.dao.UserDelete(param.ID)
}

// UserUpdate 更新用户
func (s *Services) UserUpdate(param *requests.UserUpdateRequest) error {
	return s.dao.UserUpdate(param.ID, param.Username, param.Password, param.Role, param.Status)
}

func (s *Services) UserList(param *requests.UserListRequest) ([]*models.User, int64, error) {
	return s.dao.UserList(param.Username, param.Role, param.Status, param.Page, param.Limit)
}

// MigrateUserPassword 将用户密码迁移到 bcrypt 格式
func (s *Services) MigrateUserPassword(userID uint32, plainPassword string) error {
	return s.dao.UserMigratePassword(userID, plainPassword)
}
