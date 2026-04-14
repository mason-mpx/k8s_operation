# Direct API test - approve #4 (scale_deployment, expired)
$loginBody = '{"username":"admin","password":"123456"}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $loginBody)
$loginRes = curl.exe -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
# Extract token manually
$tokenMatch = [regex]::Match($loginRes, '"token":"([^"]+)"')
$token = $tokenMatch.Groups[1].Value
Write-Host "=== Token: $($token.Substring(0,30))... ==="

# Approve #4 with admin_override
Write-Host "`n=== Step 1: Approving #4 (scale_deployment default/nginx replicas=5) ==="
$approveBody = '{"comment":"E2E test - scale nginx to 5","admin_override":true}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $approveBody)
$approveRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/4/approve" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
Write-Host "Approve response: $approveRes"

# Wait for async execution
Write-Host "`n=== Step 2: Waiting 5s for async tool execution... ==="
Start-Sleep -Seconds 5

# Check detail
Write-Host "`n=== Step 3: Checking approval #4 detail ==="
$detailRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/4" -H "Authorization: Bearer $token"
Write-Host "Detail response: $detailRes"

# Check logs
Write-Host "`n=== Step 4: Check backend logs ==="
Get-Content D:\k8s-go\k8s_operation\storage\logs\app.log -Tail 10
