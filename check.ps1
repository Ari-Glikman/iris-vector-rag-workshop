# Workshop readiness check - run once after "git clone", before the workshop day:
#     powershell -ExecutionPolicy Bypass -File .\check.ps1
# Checks your laptop (Docker, git, VS Code extensions, ports), starts the workshop container, then checks
# IRIS, the notebook kernel and the internet connections the exercises need. Ends with READY or what to fix.
# The container keeps running afterwards; stop it with: docker compose down
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$script:problems = @()

function Ok([string]$what) { Write-Host "OK   $what" -ForegroundColor Green }
function Fail([string]$what, [string]$fix) { Write-Host "FAIL $what - $fix" -ForegroundColor Red; $script:problems += "$what - $fix" }
function Warn([string]$what) { Write-Host "WARN $what" -ForegroundColor Yellow }
function Have([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "== Your laptop" -ForegroundColor Cyan
if (Have git) { Ok "git $((git --version) -replace 'git version ', '')" } else { Fail "git" "install Git for Windows (https://git-scm.com)" }

$dockerOk = $false
if (-not (Have docker)) {
    Fail "Docker" "install Docker Desktop (https://www.docker.com/products/docker-desktop)"
} else {
    $info = docker info --format "{{.OSType}}|{{.MemTotal}}|{{.NCPU}}" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $info) {
        Fail "Docker" "Docker Desktop is not running - start it, wait until it says 'Engine running', run check.ps1 again"
    } else {
        $os, $mem, $cpu = $info -split "\|"
        $gb = [math]::Round([double]$mem / 1GB, 1)
        if ($os -ne "linux") { Fail "Docker" "switch Docker Desktop to Linux containers" }
        elseif ($gb -lt 6) { Fail "Docker memory ($gb GB)" "give Docker at least 8 GB (Docker Desktop > Settings > Resources, or .wslconfig)" }
        else { Ok "Docker running (Linux containers, $gb GB memory, $cpu CPUs)"; $dockerOk = $true }
    }
}

if (Have code) {
    $ext = (code --list-extensions 2>$null) -join " "
    if ($ext -match "(?i)intersystems-community\.vscode-objectscript") { Ok "VS Code: InterSystems ObjectScript extension" }
    else { Fail "VS Code: InterSystems ObjectScript extension" "install the 'InterSystems ObjectScript Extension Pack' in VS Code" }
    if ($ext -match "(?i)ms-toolsai\.jupyter") { Ok "VS Code: Jupyter extension" }
    else { Fail "VS Code: Jupyter extension" "install the 'Jupyter' extension (Microsoft) in VS Code" }
} else {
    Warn "VS Code: 'code' is not on the PATH, so the extensions could not be checked - make sure VS Code has the 'InterSystems ObjectScript Extension Pack' and 'Jupyter'"
}

if ($dockerOk) {
    $ours = (docker ps --filter "name=^vecworkshop-iris$" --format "{{.Names}}" 2>$null)
    foreach ($port in 42773, 48888, 41972) {
        $busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($busy -and -not $ours) { Fail "port $port" "another program uses it - close it (or ask the instructor)" }
    }

    Write-Host "== The workshop container (the first time this downloads the image, several GB - be patient)" -ForegroundColor Cyan
    $up = docker compose up -d 2>&1 | ForEach-Object { "$_" }
    $up | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        if (($up -join " ") -match "(?i)denied|unauthorized|403") {
            Fail "downloading the workshop image" "the image is private for now: run  docker login ghcr.io  (user = your GitHub name, password = a GitHub token with read:packages) and run check.ps1 again"
        } else {
            Fail "docker compose up -d" "see the message above"
        }
    } else {
        $healthy = $false
        for ($i = 0; $i -lt 60; $i++) {
            if ((docker inspect -f "{{.State.Health.Status}}" vecworkshop-iris 2>$null) -eq "healthy") { $healthy = $true; break }
            Start-Sleep -Seconds 5
        }
        if (-not $healthy) {
            Fail "container" "not healthy after 5 minutes - run 'docker compose logs iris' and show it to the instructor"
        } else {
            Ok "container vecworkshop-iris is healthy"
            try { $null = Invoke-WebRequest "http://127.0.0.1:42773/csp/sys/UtilHome.csp" -UseBasicParsing -TimeoutSec 15; Ok "Management Portal http://127.0.0.1:42773" }
            catch { Fail "Management Portal" "http://127.0.0.1:42773 does not answer ($($_.Exception.Message))" }
            try { $null = Invoke-WebRequest "http://127.0.0.1:48888/api/status?token=workshop" -UseBasicParsing -TimeoutSec 15; Ok "Jupyter server http://127.0.0.1:48888" }
            catch { Fail "Jupyter server" "http://127.0.0.1:48888 does not answer ($($_.Exception.Message))" }

            Write-Host "== Inside the container" -ForegroundColor Cyan
            docker exec vecworkshop-iris /usr/irissys/bin/irispython /workshop/setup/selfcheck.py 2>$null | ForEach-Object {
                if ($_ -match "^OK ") { Write-Host $_ -ForegroundColor Green }
                else { Write-Host $_ -ForegroundColor Red; $script:problems += ($_ -replace "^FAIL ", "") }
            }
            if ($LASTEXITCODE -ne 0 -and $script:problems.Count -eq 0) { $script:problems += "the check inside the container failed" }
        }
    }
}

Write-Host ""
if ($script:problems.Count -eq 0) {
    Write-Host "READY - everything works. See you at the workshop! (Stop the container for now with: docker compose down)" -ForegroundColor Green
    exit 0
}
Write-Host "NOT READY - fix these, then run check.ps1 again:" -ForegroundColor Red
$script:problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
exit 1
