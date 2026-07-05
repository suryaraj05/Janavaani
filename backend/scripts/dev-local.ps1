# Start People's Priorities locally in ONE terminal (Windows PowerShell)
# Usage: npm run dev:local
# App UI:  http://localhost:5050
# API:     http://localhost:8092/health
#
# Press Ctrl+C to stop all services.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host ""
Write-Host "People's Priorities - local dev (single terminal)" -ForegroundColor Cyan
Write-Host "  App:  http://localhost:5050"
Write-Host "  API:  http://localhost:8092/health"
Write-Host ""
Write-Host "Press Ctrl+C to stop all services." -ForegroundColor Gray
Write-Host ""

function Test-Port($port) {
    return (Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
}

$busy = @(5050, 8081, 8092, 8082, 8083) | Where-Object { Test-Port $_ }
if ($busy.Count -gt 0) {
    Write-Host "Ports already in use: $($busy -join ', ')" -ForegroundColor Yellow
    Write-Host "Run npm run stop:dev first, then npm run dev:local" -ForegroundColor Yellow
    exit 1
}

npm run dev:stack
