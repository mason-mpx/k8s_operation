package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const (
	baseURL   = "http://localhost:8080"
	clusterID = "2"
)

// 登录获取 token
func login() (string, error) {
	loginData := map[string]string{
		"username": "admin",
		"password": "admin123", // 根据实际密码修改
	}
	body, _ := json.Marshal(loginData)

	resp, err := http.Post(baseURL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	var result map[string]interface{}
	json.Unmarshal(data, &result)

	if d, ok := result["data"].(map[string]interface{}); ok {
		if token, ok := d["token"].(string); ok {
			return token, nil
		}
	}
	return "", fmt.Errorf("login failed: %s", string(data))
}

// 测试创建 ConfigMap
func testApplyConfigMapYaml(token string) {
	fmt.Println("\n=== 创建 k8s-operation-config ConfigMap ===")

	// 实际生产配置 YAML
	yamlContent := `apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-operation-config
  namespace: default
data:
  config.yaml: |
    Server:
      RunMode: release
      Port: 8080
      ReadTimeout: 3600
      WriteTimeout: 3600
      IdleTimeout: 300
      ShutdownTimeout: 300

    Database:
      DBType: mysql
      Username: root
      Password: your-password
      Host: mysql-service
      Port: 3306
      DBName: k8s-platform
      Charset: utf8
      ParseTime: true
      MaxIdleConns: 5
      MaxOpenConns: 100
      MaxLifeSeconds: 300

    Cache:
      Type: redis
      Name: sk_sid
      Address: redis-service:6379
      Username: ""
      Password: "your-redis-password"
      MaxConnect: 10
      Network: tcp
      Secret: "k8smana"

    App:
      LogLevel: info
      TIMEZONE: "Asia/Shanghai"
      LogType: single
      LogFileName: /app/storage/logs/app.log
      BusinessLogFileName: /app/storage/logs/biz.log
      LogMaxSize: 100
      LogMaxBackup: 5
      LogMaxAge: 30
      LogCompress: true
      MirrorBusinessToSystem: false
      JWTMaxRefreshTime: 86400
      JWTSigningKey: your-jwt-secret-key
      JWTExpireTime: 120000
      AppName: "k8operation"
      GlobalKubeConfigPath: /app/configs/k8s.yaml
      DefaultClusterID: 1
      AutoInitK8s: true

    PodLog:
      EnableStreaming: false
      TailDefault: 500
      TailMax: 5000
      LimitBytes: 2097152
      Timestamps: false
      Previous: false

    ErrorCode:
      AllowOverride: false

    ClusterClient:
      TTL: 30m
      TTLJitter: 3m

    Pod:
      eviction:
        default_grace_seconds: 30

    Node:
      drain:
        max_grace_seconds: 300
        ignore_daemon_sets: true
        delete_empty_dir: false
`

	requestBody := map[string]string{
		"yaml": yamlContent,
	}
	body, _ := json.Marshal(requestBody)

	req, _ := http.NewRequest("POST", baseURL+"/api/v1/k8s/configmap/apply-yaml", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Cluster-ID", clusterID)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("❌ 请求失败: %v\n", err)
		return
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	fmt.Printf("状态码: %d\n", resp.StatusCode)
	fmt.Printf("响应: %s\n", string(data))

	if resp.StatusCode == 200 {
		fmt.Println("✅ ConfigMap 创建成功！")
	} else {
		fmt.Println("❌ ConfigMap 创建失败")
	}
}

// 验证 ConfigMap 是否存在
func verifyConfigMap(token string) {
	fmt.Println("\n=== 验证 ConfigMap 是否创建成功 ===")

	req, _ := http.NewRequest("GET", baseURL+"/api/v1/k8s/configmap/detail?namespace=default&name=k8s-operation-config", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Cluster-ID", clusterID)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("❌ 请求失败: %v\n", err)
		return
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	fmt.Printf("状态码: %d\n", resp.StatusCode)

	var result map[string]interface{}
	json.Unmarshal(data, &result)
	prettyJSON, _ := json.MarshalIndent(result, "", "  ")
	fmt.Printf("响应:\n%s\n", string(prettyJSON))

	if resp.StatusCode == 200 {
		fmt.Println("✅ ConfigMap 验证成功！")
	}
}

// 清理测试 ConfigMap
func cleanupConfigMap(token string) {
	fmt.Println("\n=== 清理测试 ConfigMap ===")

	req, _ := http.NewRequest("DELETE", baseURL+"/api/v1/k8s/configmap/delete?namespace=default&name=k8s-operation-config", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Cluster-ID", clusterID)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("❌ 清理失败: %v\n", err)
		return
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)
	fmt.Printf("状态码: %d, 响应: %s\n", resp.StatusCode, string(data))
}

func main() {
	fmt.Println("========================================")
	fmt.Println("   ConfigMap YAML API 测试")
	fmt.Println("========================================")

	// 1. 登录
	fmt.Println("\n=== 登录获取 Token ===")
	token, err := login()
	if err != nil {
		fmt.Printf("❌ 登录失败: %v\n", err)
		fmt.Println("请确认用户名密码正确，或手动填入 token")
		return
	}
	fmt.Printf("✅ 登录成功，Token: %s...\n", token[:20])

	// 2. 测试创建 ConfigMap
	testApplyConfigMapYaml(token)

	// 3. 验证 ConfigMap
	verifyConfigMap(token)

	// 4. 清理（可选）
	// cleanupConfigMap(token)

	fmt.Println("\n========================================")
	fmt.Println("   测试完成")
	fmt.Println("========================================")
}
