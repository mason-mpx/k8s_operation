package dao

import (
	"k8soperation/internal/app/models"
	"k8soperation/pkg/utils"
	"time"
)

// UserCreate 创建用户（密码使用 bcrypt 加密存储）
func (d *Dao) UserCreate(name, password string) error {
	// 对密码进行 bcrypt 加密
	hashedPassword, err := utils.HashPassword(password)
	if err != nil {
		return err
	}

	// 获取当前时间戳并转换为uint32类型
	nowTime := uint32(time.Now().Unix())
	user := models.User{
		Username: name,
		Password: hashedPassword,
		Base: &models.Base{
			CreatedAt:  nowTime,
			ModifiedAt: nowTime,
			IsDel:      0,
		},
	}
	return user.Create(d.db)
}

// UserDelete 删除用户
func (d *Dao) UserDelete(id uint32) error {
	user := models.User{
		Base: &models.Base{ID: id},
	}
	return user.Delete(d.db)
}

// UserUpdate 更新用户（密码使用 bcrypt 加密存储）
func (d *Dao) UserUpdate(id uint32, name, password string) error {
	nowTime := uint32(time.Now().Unix())
	user := models.User{
		Base: &models.Base{
			ID: id,
		},
	}

	values := map[string]interface{}{
		"username":    name,
		"modified_at": nowTime,
	}

	// 如果提供了新密码，则加密存储
	if password != "" {
		hashedPassword, err := utils.HashPassword(password)
		if err != nil {
			return err
		}
		values["password"] = hashedPassword
	}

	return user.Update(d.db, values)
}

func (d *Dao) UserList(username string, page, limit int) ([]*models.User, error) {
	user := models.User{
		Username: username,
	}

	return user.List(d.db, page, limit)
}

// UserGetByName 根据用户名获取用户信息
func (d *Dao) UserGetByName(username string) (*models.User, error) {
	user := models.User{
		Username: username,
	}
	return user.GetByName(d.db)
}

// UserMigratePassword 将用户密码迁移到 bcrypt 格式
func (d *Dao) UserMigratePassword(userID uint32, plainPassword string) error {
	hashedPassword, err := utils.HashPassword(plainPassword)
	if err != nil {
		return err
	}

	nowTime := uint32(time.Now().Unix())
	user := models.User{
		Base: &models.Base{ID: userID},
	}

	values := map[string]interface{}{
		"password":    hashedPassword,
		"modified_at": nowTime,
	}

	return user.Update(d.db, values)
}
