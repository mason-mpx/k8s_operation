# E2E 完整验证：审批通过 -> 自动扩缩容 demo-nginx
$ErrorActionPreference = "SilentlyContinue"

# === 1. Login ===
$loginBody = '{"username":"admin","password":"123456"}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $loginBody)
$loginRes = curl.exe -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
$tokenMatch = [regex]::Match($loginRes, '"token":"([^"]+)"')
$token = $tokenMatch.Groups[1].Value
$authHeader = "Authorization: Bearer $token"
Write-Host "=== 1. LOGIN OK ==="

# === 2. Check current deployment replicas ===
Write-Host "`n=== 2. Check current demo-nginx deployment (cluster_id=2) ==="
$depRes = curl.exe -s "http://localhost:8080/api/v1/deployments?namespace=default" -H $authHeader -H "X-Cluster-ID: 2"
# Extract demo-nginx info
if ($depRes -match '"demo-nginx"') {
    Write-Host "  demo-nginx found in deployment list"
} else {
    Write-Host "  WARNING: demo-nginx not found in deployment list"
    Write-Host "  Response (first 500 chars): $($depRes.Substring(0, [Math]::Min(500, $depRes.Length)))"
}

# === 3. Insert test approval via MySQL ===
Write-Host "`n=== 3. Creating test approval record via MySQL ==="
$expireAt = [int][double]::Parse((Get-Date -UFormat %s)) + 86400
$sql = @"
INSERT INTO ai_approval_requests (conversation_id, request_user_id, intent, resource, resource_name, namespace, cluster_id, risk_level, operation_json, tool_name, tool_args_json, tool_call_id, execute_result, executed, summary, status, approve_comment, expire_at, created_at, modified_at)
VALUES (0, 1, 'scale_deployment', 'Deployment扩缩容', 'demo-nginx', 'default', 2, 'write', '{"cluster_id": 2, "name": "demo-nginx", "namespace": "default", "replicas": 3}', 'scale_deployment', '{"cluster_id": 2, "name": "demo-nginx", "namespace": "default", "replicas": 3}', 'e2e-test-001', '', 0, 'E2E测试: scale demo-nginx to 3 replicas', 1, '', $expireAt, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
"@
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\test_insert.sql", $sql, [System.Text.Encoding]::UTF8)
$mysqlResult = mysql -u root -p123456 -h localhost k8s-platform -e "source D:\k8s-go\k8s_operation\test_insert.sql" 2>&1
Write-Host "  MySQL result: $mysqlResult"

# Get the new approval ID
$idResult = mysql -u root -p123456 -h localhost k8s-platform -N -e "SELECT MAX(id) FROM ai_approval_requests" 2>&1
$newId = $idResult.Trim()
Write-Host "  New approval ID: $newId"

# === 4. Verify it appears in API ===
Write-Host "`n=== 4. Verify new approval in API ==="
$detailRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/$newId" -H $authHeader
if ($detailRes -match '"status":1') {
    Write-Host "  Approval #$newId status=pending (OK)"
} else {
    Write-Host "  Response: $($detailRes.Substring(0, [Math]::Min(300, $detailRes.Length)))"
}

# === 5. Approve it ===
Write-Host "`n=== 5. Approving #$newId (scale demo-nginx to 3 replicas) ==="
$approveBody = "{`"comment`":`"E2E验证: 扩缩容demo-nginx至3副本`",`"admin_override`":true}"
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $approveBody)
$approveRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/$newId/approve" -X POST -H "Content-Type: application/json" -H $authHeader -d "@D:\k8s-go\k8s_operation\tmp_body.json"
Write-Host "  Approve response: $approveRes"

# === 6. Wait for async execution ===
Write-Host "`n=== 6. Waiting 5s for async tool execution... ==="
Start-Sleep -Seconds 5

# === 7. Check execution result ===
Write-Host "`n=== 7. Check approval execution result ==="
$afterRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/$newId" -H $authHeader
# Extract key fields
if ($afterRes -match '"executed":true') {
    Write-Host "  EXECUTED: true"
} else {
    Write-Host "  EXECUTED: false"
}
if ($afterRes -match '"execute_result":"([^"]*)"') {
    $result = $Matches[1] -replace '\\\"', '"' -replace '\\\\', '\'
    Write-Host "  RESULT: $result"
}
if ($afterRes -match '"status":2') {
    Write-Host "  STATUS: approved (OK)"
}

# === 8. Check backend logs ===
Write-Host "`n=== 8. Backend logs (last 8 lines) ==="
Get-Content D:\k8s-go\k8s_operation\storage\logs\app.log -Tail 8 | ForEach-Object {
    if ($_ -match 'scale_deployment|demo-nginx|approval_id') {
        Write-Host "  $_"
    }
}

Write-Host "`n=== E2E TEST COMPLETE ==="
