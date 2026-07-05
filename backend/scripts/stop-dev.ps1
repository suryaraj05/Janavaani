# Stop all People's Priorities local dev processes (Windows)
# Usage: npm run stop:dev

$ErrorActionPreference = "SilentlyContinue"
$ports = @(5050, 8081, 8092, 8082, 8083)

Write-Host ""
Write-Host "Stopping dev services..." -ForegroundColor Yellow

foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $conns) {
        $procId = $conn.OwningProcess
        if ($procId -and $procId -ne 0) {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "  Stopped port $port (PID $procId)" -ForegroundColor Gray
        }
    }
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Port status:" -ForegroundColor Cyan
foreach ($port in $ports) {
    $up = (Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
    $status = if ($up) { "still in use" } else { "free" }
    $color = if ($up) { "Red" } else { "Green" }
    Write-Host "  :$port $status" -ForegroundColor $color
}
Write-Host ""
