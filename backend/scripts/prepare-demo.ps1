# Prepare People's Priorities for live demo testing (Windows)
# Usage: npm run prepare:demo

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host ""
Write-Host "People's Priorities - prepare demo" -ForegroundColor Cyan
Write-Host ""

function Test-Port($port) {
    return (Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
}

function Wait-Port($port, $label, $maxSec = 60) {
    $i = 0
    while (-not (Test-Port $port) -and $i -lt $maxSec) {
        Start-Sleep -Seconds 2
        $i += 2
    }
    if (-not (Test-Port $port)) {
        Write-Host "  $label not listening on port $port - run npm run dev:local first" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Checking services..." -ForegroundColor Yellow
Wait-Port 8092 "intake-api"
Wait-Port 8083 "score-runner"

try {
    $health = Invoke-RestMethod -Uri "http://localhost:8092/health" -TimeoutSec 10
    Write-Host "  intake-api: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "  intake-api health failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Seeding Firestore..." -ForegroundColor Yellow
npm run seed
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Scoring clusters..." -ForegroundColor Yellow
$score = Invoke-RestMethod -Uri "http://localhost:8083/run" -Method POST -TimeoutSec 120
Write-Host "  scored $($score.clustersScored) clusters" -ForegroundColor Green

Write-Host ""
Write-Host "Running E2E verify..." -ForegroundColor Yellow
npm run e2e
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "--- Ready to test ---" -ForegroundColor Green
Write-Host "  App:   http://localhost:5050"
Write-Host "  Debug: http://localhost:5050/#/debug"
Write-Host "  API:   http://localhost:8092/health"
Write-Host ""
Write-Host "Test flow:"
Write-Host "  1. Register (or log in) at http://localhost:5050"
Write-Host "  2. Priorities tab - 12 ranked clusters with scores"
Write-Host "  3. Voice FAB - submit text (web) or voice (mobile)"
Write-Host "  4. Map tab - hotspot view"
Write-Host ""

$flutterUp = Test-Port 5050
if (-not $flutterUp) {
    Write-Host "Flutter not on port 5050 - run: npm run dev:app" -ForegroundColor Yellow
} else {
    Write-Host "Flutter web server is up on port 5050" -ForegroundColor Green
}

Write-Host ""
