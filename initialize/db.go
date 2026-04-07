package initialize

import (
	"context"
	"fmt"
	"gorm.io/driver/mysql"
	"gorm.io/gorm/logger"
	"k8soperation/global"
	"k8soperation/internal/app/dao"
	"k8soperation/internal/app/models"
	"k8soperation/internal/app/services"
	"k8soperation/pkg/database"
	"time"
)

// SetupDB 初始化DB
/*
SetupDB 函数用于初始化和配置数据库连接
根据全局配置中的数据库类型设置相应的数据库连接
目前支持 MySQL 数据库
返回值: error - 如果连接或配置过程中出现错误则返回错误信息
*/
func SetupDB() error {
	// 拼接 DSN，加上超时参数（防止连不通时卡很久）
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=%s&parseTime=%t&loc=Local&timeout=1s&readTimeout=2s&writeTimeout=2s",
		global.DatabaseSetting.Username,
		global.DatabaseSetting.Password,
		global.DatabaseSetting.Host,
		global.DatabaseSetting.Port,
		global.DatabaseSetting.DBName,
		global.DatabaseSetting.Charset,
		global.DatabaseSetting.ParseTime,
	)

	// 创建 gorm dialector
	dbConfig := mysql.New(mysql.Config{DSN: dsn})

	// 连接数据库
	var err error
	global.DB, global.SQLDB, err = database.Connect(dbConfig, logger.Default.LogMode(logger.Info))
	if err != nil {
		return fmt.Errorf("connect db failed: %w", err)
	}

	// 连接池设置
	global.SQLDB.SetMaxOpenConns(global.DatabaseSetting.MaxOpenConns)
	global.SQLDB.SetMaxIdleConns(global.DatabaseSetting.MaxIdleConns)
	global.SQLDB.SetConnMaxLifetime(time.Duration(global.DatabaseSetting.MaxLifeSeconds) * time.Second)

	// 快速 Ping 测试连接，最多等 1 秒
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := global.SQLDB.PingContext(ctx); err != nil {
		return fmt.Errorf("db ping failed: %w", err)
	}

	// 自动迁移表结构
	if err := autoMigrateTables(); err != nil {
		return fmt.Errorf("auto migrate tables failed: %w", err)
	}

	// 初始化默认数据
	if err := initDefaultData(); err != nil {
		return fmt.Errorf("init default data failed: %w", err)
	}

	return nil
}

// autoMigrateTables 自动迁移表结构
func autoMigrateTables() error {
	return global.DB.AutoMigrate(
		&models.PlatformSettings{},
		&models.AppStoreApp{},
		&models.AppStoreInstall{},
		&models.AppStoreComponent{},
		// 其他需要自动迁移的表可以加在这里
	)
}

// initDefaultData 初始化默认数据
func initDefaultData() error {
	ctx := context.Background()
	d := dao.NewDao(global.DB)

	// 初始化平台设置默认值
	if err := d.PlatformSettingsInitDefaults(ctx); err != nil {
		return fmt.Errorf("init platform settings failed: %w", err)
	}

	// 初始化应用商城种子数据
	svc := services.NewServices()
	if err := svc.AppStoreSeed(ctx); err != nil {
		return fmt.Errorf("init appstore seed data failed: %w", err)
	}

	return nil
}
