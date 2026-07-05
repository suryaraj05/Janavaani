# Pre-flight check before Render deploy (does not print secrets)
# Usage: powershell -File scripts/check-render-env.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host ""
Write-Host "Render deploy pre-flight" -ForegroundColor Cyan
Write-Host ""

$ok = $true

function Test-Var($name, $value) {
    if ($value -and $value.Trim().Length -gt 0) {
        Write-Host "  OK  $name is set" -ForegroundColor Green
        return $true
    }
    Write-Host "  MISSING  $name" -ForegroundColor Red
    return $false
}

# Load .env if present
$envFile = Join-Path $root ".env"
$envMap = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $envMap[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

$projectId = $envMap['FIREBASE_PROJECT_ID']
$email = $envMap['FIREBASE_CLIENT_EMAIL']
$key = $envMap['FIREBASE_PRIVATE_KEY']
$saPath = $envMap['FIREBASE_SERVICE_ACCOUNT_PATH']

if ((-not $email -or -not $key) -and $saPath) {
    $resolved = Join-Path $root $saPath
    if (-not (Test-Path $resolved)) { $resolved = $saPath }
    if (Test-Path $resolved) {
        $sa = Get-Content $resolved -Raw | ConvertFrom-Json
        if (-not $email) { $email = $sa.client_email }
        if (-not $key) { $key = $sa.private_key }
        if (-not $projectId) { $projectId = $sa.project_id }
        Write-Host "  OK  Firebase credentials loaded from service account file" -ForegroundColor Green
    }
}

if (-not (Test-Var "FIREBASE_PROJECT_ID" $projectId)) { $ok = $false }
if (-not (Test-Var "FIREBASE_CLIENT_EMAIL" $email)) { $ok = $false }
if (-not (Test-Var "FIREBASE_PRIVATE_KEY" $key)) { $ok = $false }
if (-not (Test-Var "PEPPER" $envMap['PEPPER'])) { $ok = $false }
if (-not (Test-Var "CONNECTOR_TOKEN" $envMap['CONNECTOR_TOKEN'])) { $ok = $false }

if ($envMap['GEMINI_API_KEY']) {
    Write-Host "  OK  GEMINI_API_KEY is set (optional but recommended)" -ForegroundColor Green
} else {
    Write-Host "  WARN GEMINI_API_KEY empty - offline mocks will be used" -ForegroundColor Yellow
}

Write-Host ""
if ($ok) {
    Write-Host "Ready for Render env vars." -ForegroundColor Green
    Write-Host ""
    Write-Host "Copy these into Render (Dashboard -> Environment):" -ForegroundColor Cyan
    Write-Host "  FIREBASE_PROJECT_ID = $projectId"
    Write-Host "  FIREBASE_CLIENT_EMAIL = $email"
    Write-Host "  FIREBASE_PRIVATE_KEY = (paste full key from service account JSON)"
    Write-Host "  PEPPER = (from your .env)"
    Write-Host "  CONNECTOR_TOKEN = (from your .env)"
    Write-Host "  GEMINI_API_KEY = (from your .env, optional)"
    Write-Host ""
    Write-Host 'For FIREBASE_PRIVATE_KEY on Render: paste the key with real newlines,'
    Write-Host 'or use escaped \n between lines.'
    exit 0
}

Write-Host "Fix missing values before deploying." -ForegroundColor Red
exit 1
