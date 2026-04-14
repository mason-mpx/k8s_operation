# 1. Login
$loginBody = '{"username":"admin","password":"123456"}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $loginBody)
$loginRes = curl.exe -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "@D:\k8s-go\k8s_operation\tmp_body.json"
$loginObj = $loginRes | ConvertFrom-Json
$token = $loginObj.data.token
Write-Host "=== LOGIN OK, token prefix: $($token.Substring(0,20))... ==="

# 2. List approvals
$headers = @("Authorization: Bearer $token")
$listRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals?view=all&page_size=20" -H $headers[0]
$listObj = $listRes | ConvertFrom-Json
Write-Host "`n=== APPROVAL LIST (total: $($listObj.data.total)) ==="
foreach ($item in $listObj.data.list) {
    $statusMap = @{1="pending";2="approved";3="rejected";4="expired";5="canceled"}
    $st = $statusMap[[int]$item.status]
    Write-Host "  #$($item.id) status=$st intent=$($item.intent) resource=$($item.namespace)/$($item.resource_name)"
}

# 3. Find a pending/expired scale_deployment approval to test
$target = $null
foreach ($item in $listObj.data.list) {
    if (($item.status -eq 1 -or $item.status -eq 4) -and $item.intent -eq "scale_deployment") {
        $target = $item
        break
    }
}

if ($null -eq $target) {
    Write-Host "`n=== No pending/expired scale_deployment approval found ==="
    # Try any pending/expired
    foreach ($item in $listObj.data.list) {
        if ($item.status -eq 1 -or $item.status -eq 4) {
            $target = $item
            break
        }
    }
}

if ($null -eq $target) {
    Write-Host "No actionable approval found. Exiting."
    exit
}

Write-Host "`n=== TARGET: #$($target.id) intent=$($target.intent) status=$($target.status) ==="
Write-Host "  tool_name=$($target.tool_name)"
Write-Host "  tool_args=$($target.tool_args_json)"

# 4. Approve it with admin_override
$approveBody = '{"comment":"API test approval","admin_override":true}'
[System.IO.File]::WriteAllText("D:\k8s-go\k8s_operation\tmp_body.json", $approveBody)
$approveRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/$($target.id)/approve" -X POST -H "Content-Type: application/json" -H $headers[0] -d "@D:\k8s-go\k8s_operation\tmp_body.json"
Write-Host "`n=== APPROVE RESULT ==="
Write-Host $approveRes

# 5. Wait a bit for async execution
Start-Sleep -Seconds 3

# 6. Check detail to see execute result
$detailRes = curl.exe -s "http://localhost:8080/api/v1/ai/approvals/$($target.id)" -H $headers[0]
$detailObj = $detailRes | ConvertFrom-Json
Write-Host "`n=== DETAIL AFTER APPROVE ==="
$statusMap2 = @{1="pending";2="approved";3="rejected";4="expired";5="canceled"}
Write-Host "  status: $($statusMap2[[int]$detailObj.data.approval.status])"
Write-Host "  executed: $($detailObj.data.approval.executed)"
Write-Host "  execute_result: $($detailObj.data.approval.execute_result)"
Write-Host "`n=== LOGS ==="
foreach ($log in $detailObj.data.logs) {
    Write-Host "  [$($log.action)] $($log.comment)"
}
