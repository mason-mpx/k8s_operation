$base = "http://localhost:8080/api/v1"

# Login
$loginBody = @{username="admin";password="123456"} | ConvertTo-Json
$loginResp = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $loginBody -ContentType "application/json; charset=utf-8"
$token = $loginResp.data.token
Write-Host "Token OK"

$headers = @{ "Authorization" = "Bearer $token" }

# Get clusters
$clusterResp = Invoke-RestMethod -Uri "$base/k8s/cluster/list?page=1&limit=10" -Headers $headers
$clusterId = $clusterResp.data.list[0].id
Write-Host "Cluster ID: $clusterId"

# Get pods
$podResp = Invoke-RestMethod -Uri "$base/k8s/pod/list?cluster_id=$clusterId&namespace=kube-system&page=1&limit=50" -Headers $headers
$pods = $podResp.data.list
Write-Host "Total pods: $($pods.Count)"
Write-Host ""

foreach ($p in $pods) {
    $name = $p.name
    $status = $p.status
    $cname = if ($p.containers -and $p.containers.Count -gt 0) { $p.containers[0].name } else { "unknown" }
    
    if ($status -ne "Running") {
        Write-Host "[SKIP] $name (status=$status)"
        continue
    }
    
    $wsUri = "ws://localhost:8080/api/v1/k8s/pod/terminal?namespace=kube-system&name=$name&container=$cname&token=$token&cluster_id=$clusterId"
    
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter(15000)
        $ws.ConnectAsync([Uri]$wsUri, $cts.Token).Wait()
        
        $allMessages = @()
        $readCts = New-Object System.Threading.CancellationTokenSource
        $readCts.CancelAfter(12000)
        $buf = New-Object byte[] 4096
        $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buf)
        
        $canEnter = $false
        $noShell = $false
        
        while (-not $readCts.Token.IsCancellationRequested) {
            try {
                $result = $ws.ReceiveAsync($segment, $readCts.Token)
                $result.Wait()
                if ($result.Result.Count -eq 0) { break }
                $msg = [System.Text.Encoding]::UTF8.GetString($buf, 0, $result.Result.Count)
                $allMessages += $msg
                
                if ($msg -match "Connected to") { $canEnter = $true; break }
                if ($msg -match "distroless" -or $msg -match "scratch" -or $msg -match "static") { $noShell = $true; break }
            } catch {
                break
            }
        }
        
        if ($canEnter) {
            Write-Host "[OK]   $name ($cname) - CAN ENTER terminal"
        } elseif ($noShell) {
            Write-Host "[FAIL] $name ($cname) - No shell (distroless/scratch)"
        } else {
            $preview = ($allMessages -join " ").Substring(0, [Math]::Min(100, ($allMessages -join " ").Length))
            Write-Host "[????] $name ($cname) - Timeout. Last msgs: $preview"
        }
        
        try { $ws.Dispose() } catch {}
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg.Length -gt 80) { $errMsg = $errMsg.Substring(0,80) }
        Write-Host "[ERR]  $name ($cname) - $errMsg"
    }
}

Write-Host ""
Write-Host "=== Test Complete ==="
