$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Join-Path $appRoot 'backend'
$docker = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
$logRoot = Join-Path $appRoot '.local-logs'
$apiReadyUrl = 'http://127.0.0.1:8080/v1/health/ready'
$appPort = 8780
$appUrl = "http://127.0.0.1:$appPort/"
$existingListener = Get-NetTCPConnection -LocalPort $appPort -State Listen -ErrorAction SilentlyContinue
if ($existingListener) {
  # Keep the demo preview intact and use a separate port for connected mode.
  $appPort = 8781
  $appUrl = "http://127.0.0.1:$appPort/"
  if (Get-NetTCPConnection -LocalPort $appPort -State Listen -ErrorAction SilentlyContinue) {
    throw 'Ports 8780 and 8781 are occupied. Stop the existing preview or choose a free port.'
  }
}

if (-not (Test-Path -LiteralPath $docker)) {
  throw 'Docker Desktop is not installed in the expected per-user location.'
}

New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

# Existing .env files may predate the second local preview port. Override only the
# local browser-origin setting for this process and its API child, leaving secrets untouched.
$originLine = Get-Content -LiteralPath (Join-Path $backendRoot '.env') -ErrorAction SilentlyContinue |
  Where-Object { $_ -match '^PUBLIC_APP_ORIGINS=' } | Select-Object -First 1
if ($originLine) {
  $origins = $originLine.Substring('PUBLIC_APP_ORIGINS='.Length).Trim()
  if ($origins -notmatch '(^|,)http://127\.0\.0\.1:8781(,|$)') {
    $env:PUBLIC_APP_ORIGINS = "$origins,http://127.0.0.1:8781"
  }
}

Write-Host 'Starting PostgreSQL, Redis, and MinIO...'
& $docker compose --project-directory $backendRoot -f (Join-Path $backendRoot 'docker-compose.yml') up -d
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed.' }

Write-Host 'Waiting for PostgreSQL...'
$ready = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
  & $docker compose --project-directory $backendRoot -f (Join-Path $backendRoot 'docker-compose.yml') exec -T postgres pg_isready -U vakilsetu *> $null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $ready) { throw 'PostgreSQL did not become ready.' }

Push-Location $backendRoot
try {
  if (-not (Test-Path -LiteralPath 'node_modules')) { npm ci }
  Write-Host 'Applying database migrations...'
  npm run migrate
  if ($LASTEXITCODE -ne 0) { throw 'Database migration failed.' }

  $apiAlreadyReady = $false
  try {
    $apiStatus = Invoke-RestMethod -Uri $apiReadyUrl -TimeoutSec 2
    $apiAlreadyReady = $apiStatus.status -eq 'ready' -and $apiStatus.dependencies.postgres -eq 'up'
  }
  catch {}

  if ($apiAlreadyReady) {
    Write-Host 'The VakilSetu API is already running.'
  }
  else {
    if (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue) {
      throw 'Port 8080 is occupied by a service that did not pass the VakilSetu readiness check.'
    }
    $backendLog = Join-Path $logRoot 'backend.log'
    Write-Host 'Starting the API on http://127.0.0.1:8080/v1 ...'
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'npm run start:dev') -WorkingDirectory $backendRoot -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError (Join-Path $logRoot 'backend-error.log')
  }
}
finally {
  Pop-Location
}

$healthy = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
  try {
    $response = Invoke-RestMethod -Uri $apiReadyUrl -TimeoutSec 2
    if ($response.status -eq 'ready' -and $response.dependencies.postgres -eq 'up') {
      $healthy = $true
      break
    }
  }
  catch {
    Start-Sleep -Seconds 2
  }
}
if (-not $healthy) { throw "Backend failed its readiness check. Review $logRoot" }

$appOrigin = "http://127.0.0.1:$appPort"
try {
  $corsResponse = Invoke-WebRequest -UseBasicParsing -Method Options -Uri $apiReadyUrl -Headers @{
    Origin = $appOrigin
    'Access-Control-Request-Method' = 'GET'
  } -TimeoutSec 3
  if ($corsResponse.Headers['Access-Control-Allow-Origin'] -ne $appOrigin) {
    throw "The running API does not allow $appOrigin. Restart the API with this launcher."
  }
}
catch {
  throw "Connected preview CORS check failed: $($_.Exception.Message)"
}

$flutterLog = Join-Path $logRoot 'flutter.log'
Write-Host "Starting connected Flutter web app on $appUrl ..."
Start-Process -FilePath 'C:\flutter\bin\flutter.bat' -ArgumentList @(
  'run', '-d', 'web-server',
  '--web-hostname', '127.0.0.1',
  '--web-port', "$appPort",
  '--dart-define=API_ENABLED=true',
  '--dart-define=API_BASE_URL=http://127.0.0.1:8080/v1'
) -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput $flutterLog -RedirectStandardError (Join-Path $logRoot 'flutter-error.log')

$flutterReady = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
  try {
    $appResponse = Invoke-WebRequest -UseBasicParsing -Uri $appUrl -TimeoutSec 2
    if ($appResponse.StatusCode -eq 200 -and $appResponse.Content -match 'VakilSetu') {
      $flutterReady = $true
      break
    }
  }
  catch {}
  Start-Sleep -Seconds 2
}
if (-not $flutterReady) { throw "Flutter preview did not become ready. Review $logRoot" }

Write-Host ''
Write-Host 'VakilSetu local services started successfully.' -ForegroundColor Green
Write-Host "App:     $appUrl"
Write-Host 'API:     http://127.0.0.1:8080/v1'
Write-Host 'OTP:     123456'
Write-Host "Logs:    $logRoot"
