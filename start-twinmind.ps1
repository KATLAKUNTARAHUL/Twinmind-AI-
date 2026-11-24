$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $projectRoot "backend"
$frontendPath = Join-Path $projectRoot "frontend"
$backendPython = Join-Path $backendPath ".venv\Scripts\python.exe"
$llmEnvFile = Join-Path $backendPath ".env"

if (-not (Test-Path $backendPython)) {
    throw "Backend environment not found. Run the project setup before starting TwinMind."
}

if (-not (Test-Path $llmEnvFile) -and -not $env:OPENAI_API_KEY) {
    Write-Host "TwinMind is starting in Career Coach mode. To enable general AI answers, copy backend\.env.example to backend\.env and add OPENAI_API_KEY." -ForegroundColor Yellow
}

function Test-PortListening([int]$Port) {
    return $null -ne (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

if (-not (Test-PortListening 8000)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoExit",
        "-Command",
        "Set-Location '$backendPath'; & '$backendPython' -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload"
    )
}

if (-not (Test-PortListening 3000)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoExit",
        "-Command",
        "Set-Location '$frontendPath'; npm run dev"
    )
}

$frontendReady = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if (Test-PortListening 3000 -and Test-PortListening 8000) {
        $frontendReady = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not $frontendReady) {
    throw "TwinMind did not start correctly. Check the backend and frontend PowerShell windows for errors."
}

Start-Process "http://localhost:3000"
Write-Host "TwinMind AI is ready at http://localhost:3000" -ForegroundColor Cyan
