# E2E: Approve #7 and verify scale_deployment execution
$loginBody = '{"username":"admin","password":"123456"}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $loginBody)
$loginRes = curl.exe -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
$tokenMatch = [regex]::Match($loginRes, '"token":"([^"]+)"')
$token = $tokenMatch.Groups[1].Value
Write-Host "=== LOGIN OK ==="

# Approve #7
Write-Host "`n=== APPROVING #7: scale demo-nginx to 3 replicas ==="
$body = '{"comment":"E2E verify scale","admin_override":true}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $body)
$res = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/7/approve" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
Write-Host "  Response: $res"

# Wait
Write-Host "`n=== WAITING 5s... ==="
Start-Sleep -Seconds 5

# Check result
Write-Host "`n=== CHECK RESULT ==="
mysql -u root -p123456 -h localhost k8s-platform -e "SELECT id,status,executed,execute_result FROM ai_approval_requests WHERE id=7" 2>$null

# Check logs
Write-Host "`n=== BACKEND LOGS ==="
Get-Content D:\k8s-go\k8s_operation\storage\logs\app.log -Tail 6
