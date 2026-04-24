$ErrorActionPreference = "Continue"

Write-Host "===== 1. 测试登录 API =====" -ForegroundColor Cyan
try {
    $login = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"K8s@2026!Secure"}'
    Write-Host "登录状态码: $($login.code)" -ForegroundColor Green
    $token = $login.data.token
    if ($token) {
        Write-Host "Token: $($token.Substring(0,30))..." -ForegroundColor Green
    } else {
        Write-Host "未获取到 Token，尝试其他字段..." -ForegroundColor Yellow
        $token = $login.token
        Write-Host ($login | ConvertTo-Json -Depth 3)
    }
} catch {
    Write-Host "登录失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$headers = @{ "Authorization" = "Bearer $token" }

Write-Host ""
Write-Host "===== 2. 测试 Deployment 滚动更新 API (路由注册验证) =====" -ForegroundColor Cyan
try {
    $rs = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/k8s/deployment/rollout-status?namespace=default&name=test" -Headers $headers -UseBasicParsing
    Write-Host "Rollout Status API 响应: $($rs.StatusCode)" -ForegroundColor Green
    Write-Host $rs.Content
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "Rollout Status API 状态码: $code (预期: 非404表示路由已注册)" -ForegroundColor Yellow
    if ($code -ne 404) {
        Write-Host "路由已正确注册!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===== 3. 测试 Update Strategy API (路由注册验证) =====" -ForegroundColor Cyan
try {
    $body = '{"namespace":"default","name":"test","max_surge":"1","max_unavailable":"0","min_ready_seconds":10}'
    $us = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/k8s/deployment/update-strategy" -Method POST -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing
    Write-Host "Update Strategy API 响应: $($us.StatusCode)" -ForegroundColor Green
    Write-Host $us.Content
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "Update Strategy API 状态码: $code (预期: 非404表示路由已注册)" -ForegroundColor Yellow
    if ($code -ne 404) {
        Write-Host "路由已正确注册!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===== 4. 测试 Pause API (路由注册验证) =====" -ForegroundColor Cyan
try {
    $body = '{"namespace":"default","name":"test"}'
    $pa = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/k8s/deployment/pause" -Method POST -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing
    Write-Host "Pause API 响应: $($pa.StatusCode)" -ForegroundColor Green
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "Pause API 状态码: $code (预期: 非404表示路由已注册)" -ForegroundColor Yellow
    if ($code -ne 404) {
        Write-Host "路由已正确注册!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===== 5. 测试 Resume API (路由注册验证) =====" -ForegroundColor Cyan
try {
    $body = '{"namespace":"default","name":"test"}'
    $re = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/k8s/deployment/resume" -Method POST -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing
    Write-Host "Resume API 响应: $($re.StatusCode)" -ForegroundColor Green
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "Resume API 状态码: $code (预期: 非404表示路由已注册)" -ForegroundColor Yellow
    if ($code -ne 404) {
        Write-Host "路由已正确注册!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===== 6. 测试 CICD 模板验证 API =====" -ForegroundColor Cyan
try {
    $tv = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/k8s/cicd/pipeline/template-verify" -Headers $headers
    Write-Host "模板验证 API 响应 code: $($tv.code)" -ForegroundColor Green
    if ($tv.data.summary) {
        Write-Host "支持语言: $($tv.data.summary.supported_languages -join ', ')" -ForegroundColor Green
        Write-Host "复用模型: $($tv.data.summary.reuse_model)" -ForegroundColor Green
    }
} catch {
    Write-Host "模板验证 API 失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "===== 验证完成 =====" -ForegroundColor Cyan
