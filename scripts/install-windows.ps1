#Requires -Version 5.0
<#
.SYNOPSIS
  Installs Homebridge on Windows by cloning the homebridge-config-ui-x repository
  and setting it up as a Windows service.

.DESCRIPTION
  This script clones the homebridge-config-ui-x repository, installs Homebridge
  and Homebridge UI globally via npm, and registers Homebridge as a Windows service.
  Designed for Windows 10/11 devices including Microsoft Surface Pro 7.

.PARAMETER Port
  The port Homebridge UI will listen on. Defaults to 8581.

.PARAMETER StoragePath
  The path where Homebridge will store its configuration. Defaults to C:\homebridge.

.PARAMETER ServiceName
  The name of the Windows service. Defaults to Homebridge.

.EXAMPLE
  .\install-windows.ps1

.EXAMPLE
  .\install-windows.ps1 -Port 8582 -StoragePath "C:\Users\Me\homebridge" -ServiceName MyHomebridge

.NOTES
  Must be run as Administrator.
  Requires Node.js 18+ and Git to be installed.
#>

param(
  [int]$Port = 8581,
  [string]$StoragePath = "C:\homebridge",
  [string]$ServiceName = "Homebridge"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host ">>> $Message" -ForegroundColor Cyan
}

function Write-Success {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
  param([string]$Message)
  Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# ── Admin Check ───────────────────────────────────────────────────────────────

Write-Step "Checking Administrator privileges"

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Fail "This script must be run as Administrator."
  Write-Host "  Right-click PowerShell and select 'Run as Administrator', then re-run this script." -ForegroundColor Yellow
  exit 1
}

Write-Success "Running as Administrator"

# ── Node.js Check ─────────────────────────────────────────────────────────────

Write-Step "Checking for Node.js (18+)"

try {
  $nodeVersion = (node --version 2>&1).ToString().TrimStart('v')
  $nodeMajor = [int]($nodeVersion.Split('.')[0])
  if ($nodeMajor -lt 18) {
    Write-Fail "Node.js v$nodeVersion is installed but version 18 or higher is required."
    Write-Host "  Download the latest LTS from: https://nodejs.org/en/download/" -ForegroundColor Yellow
    exit 1
  }
  Write-Success "Node.js v$nodeVersion found"
} catch {
  Write-Fail "Node.js is not installed or not in PATH."
  Write-Host "  Download the latest LTS from: https://nodejs.org/en/download/" -ForegroundColor Yellow
  exit 1
}

# ── Git Check ─────────────────────────────────────────────────────────────────

Write-Step "Checking for Git"

try {
  $gitVersion = (git --version 2>&1).ToString()
  Write-Success "$gitVersion found"
} catch {
  Write-Fail "Git is not installed or not in PATH."
  Write-Host "  Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
  exit 1
}

# ── Clone Repository ──────────────────────────────────────────────────────────

Write-Step "Cloning homebridge-config-ui-x repository"

$cloneDir = Join-Path $env:TEMP "homebridge-config-ui-x-install"

if (Test-Path $cloneDir) {
  Write-Warn "Removing previous clone at $cloneDir"
  Remove-Item -Recurse -Force $cloneDir
}

try {
  git clone --depth 1 https://github.com/homebridge/homebridge-config-ui-x.git $cloneDir
  Write-Success "Repository cloned to $cloneDir"
} catch {
  Write-Fail "Failed to clone repository: $_"
  exit 1
}

# ── Install Homebridge and UI via npm ─────────────────────────────────────────

Write-Step "Installing Homebridge and Homebridge UI globally via npm"

$env:npm_config_global_style = "true"
$env:npm_config_unsafe_perm = "true"
$env:npm_config_update_notifier = "false"
$env:npm_config_prefer_online = "true"
$env:npm_config_foreground_scripts = "true"
$env:npm_config_loglevel = "error"

try {
  npm install -g --omit=dev homebridge homebridge-config-ui-x
  Write-Success "Homebridge and Homebridge UI installed"
} catch {
  Write-Fail "npm install failed: $_"
  exit 1
}

# ── Create Storage Directory ──────────────────────────────────────────────────

Write-Step "Creating Homebridge storage directory at $StoragePath"

if (-not (Test-Path $StoragePath)) {
  New-Item -ItemType Directory -Force -Path $StoragePath | Out-Null
  Write-Success "Directory created: $StoragePath"
} else {
  Write-Success "Directory already exists: $StoragePath"
}

# ── Register Windows Service via hb-service ───────────────────────────────────

Write-Step "Registering Homebridge as a Windows service ($ServiceName)"

try {
  hb-service install --service-name $ServiceName --user-storage-path $StoragePath --port $Port
  Write-Success "Windows service '$ServiceName' created and started"
} catch {
  Write-Warn "hb-service install reported an issue: $_"
  Write-Warn "You may need to start the service manually with: sc start $ServiceName"
}

# ── Configure Firewall ────────────────────────────────────────────────────────

Write-Step "Configuring Windows Firewall for Homebridge (port $Port)"

try {
  netsh advfirewall firewall Delete rule name="Homebridge" 2>$null | Out-Null
} catch {
  # Rule may not exist yet, that's fine
}

try {
  $nodePath = (Get-Command node).Source
  netsh advfirewall firewall add rule name="Homebridge" dir=in action=allow program="$nodePath" | Out-Null
  Write-Success "Firewall rule added for Node.js"
} catch {
  Write-Warn "Failed to configure firewall rule. You may need to add it manually."
}

# ── Cleanup ───────────────────────────────────────────────────────────────────

Write-Step "Cleaning up temporary files"

try {
  Remove-Item -Recurse -Force $cloneDir
  Write-Success "Temporary clone removed"
} catch {
  Write-Warn "Could not remove temp directory $cloneDir — you can delete it manually"
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Homebridge installation complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Service name : $ServiceName"
Write-Host "  Storage path : $StoragePath"
Write-Host "  UI URL       : http://localhost:$Port"
Write-Host ""
Write-Host "  Default credentials: admin / admin"
Write-Host ""
Write-Host "  To manage the service:"
Write-Host "    Start  : sc start $ServiceName"
Write-Host "    Stop   : sc stop $ServiceName"
Write-Host "    Status : sc query $ServiceName"
Write-Host ""
