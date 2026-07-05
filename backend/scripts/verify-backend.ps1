# Verify all backend services are up (local or Railway)
# Usage: .\scripts\verify-backend.ps1
#        $env:INTAKE_API_URL='https://your-app.up.railway.app'; .\scripts\verify-backend.ps1

param(
    [string]$IntakeUrl = $env:INTAKE_API_URL
)

if (-not $IntakeUrl) { $IntakeUrl = "http://localhost:8092" }
$IntakeUrl = $IntakeUrl.TrimEnd('/')

Write-Host ""
Write-Host "Backend verification" -ForegroundColor Cyan
Write-Host "  intake-api: $IntakeUrl"
Write-Host ""

$failed = $false

function Test-Health($name, $url) {
    try {
        $r = Invoke-RestMethod -Uri "$url/health" -TimeoutSec 15
        if ($r.status -eq 'ok') {
            Write-Host "  OK  $name ($($r.service))" -ForegroundColor Green
            return $true
        }
        Write-Host "  FAIL $name unhealthy: $($r | ConvertTo-Json -Compress)" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "  FAIL $name - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

if (-not (Test-Health "intake-api" $IntakeUrl)) { $failed = $true }

try {
    $root = Invoke-RestMethod -Uri $IntakeUrl -TimeoutSec 10
    Write-Host "  OK  GET / -> $($root.service)" -ForegroundColor Green
} catch {
    Write-Host "  FAIL GET / - $($_.Exception.Message)" -ForegroundColor Red
    $failed = $true
}

try {
    $cfg = Invoke-RestMethod -Uri "$IntakeUrl/api/v1/config" -TimeoutSec 10
    if ($cfg.success) {
        Write-Host "  OK  GET /api/v1/config" -ForegroundColor Green
    }
} catch {
    Write-Host "  WARN GET /api/v1/config - $($_.Exception.Message)" -ForegroundColor Yellow
}

# Optional local-only checks for worker services
if ($IntakeUrl -match 'localhost') {
    foreach ($svc in @(
        @{ Name = 'enrich-worker'; Port = 8081 },
        @{ Name = 'score-runner'; Port = 8083 },
        @{ Name = 'connectors'; Port = 8082 }
    )) {
        if (-not (Test-Health $svc.Name "http://localhost:$($svc.Port)")) { $failed = $true }
    }
}

Write-Host ""
if ($failed) {
    Write-Host "Some checks failed." -ForegroundColor Red
    exit 1
}
Write-Host "All checks passed." -ForegroundColor Green
Write-Host ""
