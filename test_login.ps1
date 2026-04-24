$body = @{username="admin";password="123456"} | ConvertTo-Json
$resp = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/login" -Method POST -Body $body -ContentType "application/json; charset=utf-8"
Write-Host "Code: $($resp.code)"
Write-Host "Token: $($resp.data.token)"
