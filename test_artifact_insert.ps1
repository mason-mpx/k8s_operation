# 登录获取 token
$loginBody = @{ username = "test111"; password = "123456" } | ConvertTo-Json
$loginRes = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
$token = $loginRes.data.token
Write-Host "Token: $token"

if (-not $token) {
    Write-Host "Login failed, trying admin..."
    $loginBody2 = @{ username = "admin"; password = "admin123" } | ConvertTo-Json
    $loginRes2 = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/login" -Method POST -Body $loginBody2 -ContentType "application/json"
    $token = $loginRes2.data.token
    Write-Host "Token: $token"
}

if (-not $token) {
    Write-Host "All login attempts failed!"
    exit 1
}

$headers = @{ Authorization = "Bearer $token" }

# 插入测试制品数据
$artifact = @{
    name = "order-service-v1.2.0.jar"
    artifact_type = "jar"
    version = "v1.2.0"
    language_type = "java"
    pipeline_id = 1
    run_id = 1
    build_number = 42
    git_repo = "https://github.com/example/order-service.git"
    git_branch = "main"
    git_commit = "a1b2c3d4e5f6789012345678901234567890abcd"
    image_repo = "harbor.example.com/proj/order-service"
    image_tag = "v1.2.0"
    image_digest = "sha256:abc123def456"
} | ConvertTo-Json

Write-Host "`nCreating artifact..."
$res = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/k8s/cicd/artifact/create" -Method POST -Body $artifact -ContentType "application/json" -Headers $headers
Write-Host "Result: $($res | ConvertTo-Json -Depth 5)"
