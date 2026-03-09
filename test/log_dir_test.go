package main

import (
	"fmt"
	"k8soperation/global"
	"k8soperation/initialize"
	"log"
	"os"
	"path/filepath"
)

func main() {
	fmt.Println("=== 测试日志目录创建 ===")
	
	// 1. 初始化配置
	fmt.Println("\n[1] 初始化配置...")
	if err := initialize.SetupSetting(); err != nil {
		log.Fatalf("SetupSetting 失败：%v", err)
	}
	fmt.Println("✓ 配置初始化成功")
	
	// 2. 显示配置的日志路径
	fmt.Println("\n[2] 日志路径配置:")
	fmt.Printf("   系统日志：%s\n", global.AppSetting.LogFileName)
	fmt.Printf("   业务日志：%s\n", global.AppSetting.BusinessLogFileName)
	
	// 3. 获取当前工作目录
	wd, _ := os.Getwd()
	fmt.Printf("   当前工作目录：%s\n", wd)
	
	// 4. 计算绝对路径
	sysLogAbs, _ := filepath.Abs(global.AppSetting.LogFileName)
	bizLogAbs, _ := filepath.Abs(global.AppSetting.BusinessLogFileName)
	fmt.Printf("   系统日志绝对路径：%s\n", sysLogAbs)
	fmt.Printf("   业务日志绝对路径：%s\n", bizLogAbs)
	
	// 5. 检查目录是否已存在
	fmt.Println("\n[3] 检查目录是否存在:")
	sysLogDir := filepath.Dir(sysLogAbs)
	bizLogDir := filepath.Dir(bizLogAbs)
	
	if info, err := os.Stat(sysLogDir); err == nil {
		fmt.Printf("   ✓ 系统日志目录已存在：%s\n", sysLogDir)
		if !info.IsDir() {
			fmt.Printf("   ⚠ 警告：这不是一个目录！\n")
		}
	} else {
		fmt.Printf("   ✗ 系统日志目录不存在：%s\n", sysLogDir)
	}
	
	if info, err := os.Stat(bizLogDir); err == nil {
		fmt.Printf("   ✓ 业务日志目录已存在：%s\n", bizLogDir)
		if !info.IsDir() {
			fmt.Printf("   ⚠ 警告：这不是一个目录！\n")
		}
	} else {
		fmt.Printf("   ✗ 业务日志目录不存在：%s\n", bizLogDir)
	}
	
	// 6. 初始化日志（会创建目录）
	fmt.Println("\n[4] 初始化日志模块...")
	if err := initialize.SetupLogger(); err != nil {
		log.Fatalf("SetupLogger 失败：%v", err)
	}
	fmt.Println("✓ 日志初始化成功")
	
	// 7. 再次检查目录
	fmt.Println("\n[5] 再次检查目录:")
	if info, err := os.Stat(sysLogDir); err == nil {
		fmt.Printf("   ✓ 系统日志目录已创建：%s\n", sysLogDir)
	} else {
		fmt.Printf("   ✗ 系统日志目录创建失败：%v\n", err)
	}
	
	if info, err := os.Stat(bizLogDir); err == nil {
		fmt.Printf("   ✓ 业务日志目录已创建：%s\n", bizLogDir)
	} else {
		fmt.Printf("   ✗ 业务日志目录创建失败：%v\n", err)
	}
	
	// 8. 写一条测试日志
	fmt.Println("\n[6] 写入测试日志...")
	global.Logger.Info("这是一条测试日志")
	fmt.Println("✓ 测试日志已写入")
	
	fmt.Println("\n=== 测试完成 ===")
	fmt.Println("\n提示：请检查上述输出的目录路径，确认日志文件是否生成")
}
