#Requires -RunAsAdministrator
# Solimar Home Server Setup
# Run in PowerShell as Administrator

$ErrorActionPreference = "Stop"
$TailscaleIP = "100.89.104.20"
$AuthorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa3YMZrlVaFDAbbscQgH+Bc7ADwoXeFfxM7g7t8p4r5 franciscohermosilloiii@MacBookPro.lan"

function Step  { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok    { param([string]$m) Write-Host "    OK  $m" -ForegroundColor Green }

# ── 1. OpenSSH Server ─────────────────────────────────────────────────────────
Step "Installing OpenSSH Server..."

$cap = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Server*"
if ($cap.State -ne "Installed") {
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
    Ok "OpenSSH Server installed"
} else {
    Ok "OpenSSH Server already present"
}

Set-Service -Name sshd -StartupType Automatic
Start-Service sshd -ErrorAction SilentlyContinue
Ok "sshd auto-start enabled and running"

# ── 2. Firewall ───────────────────────────────────────────────────────────────
Step "Opening firewall port 24601..."

if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 24601 | Out-Null
} else {
    Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -LocalPort 24601
}
Ok "Firewall rule active on port 24601"

# ── 3. Authorized key ─────────────────────────────────────────────────────────
Step "Installing SSH authorized key..."

$sshDir = "C:\ProgramData\ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

$keysFile = "$sshDir\administrators_authorized_keys"
Set-Content -Path $keysFile -Value $AuthorizedKey -Encoding UTF8

# Required permissions: only SYSTEM + Administrators, no inheritance
icacls $keysFile /inheritance:r /grant "SYSTEM:(F)" /grant "Administrators:(F)" | Out-Null
Ok "Key written to $keysFile with correct permissions"

# ── 4. SSH config: key-only auth ──────────────────────────────────────────────
Step "Hardening sshd_config..."

$configPath = "$sshDir\sshd_config"
$config = Get-Content $configPath -Raw

if ($config -match "#?Port\s+\d+") {
    $config = $config -replace "#?Port\s+\d+", "Port 24601"
} else {
    $config = "Port 24601`n" + $config
}

if ($config -match "#?PubkeyAuthentication") {
    $config = $config -replace "#?PubkeyAuthentication\s+\w+", "PubkeyAuthentication yes"
} else {
    $config += "`nPubkeyAuthentication yes"
}

if ($config -match "#?PasswordAuthentication") {
    $config = $config -replace "#?PasswordAuthentication\s+\w+", "PasswordAuthentication no"
} else {
    $config += "`nPasswordAuthentication no"
}

Set-Content -Path $configPath -Value $config -Encoding UTF8
Restart-Service sshd
Ok "Key-only auth enforced, sshd restarted"

# ── 5. Node.js ────────────────────────────────────────────────────────────────
Step "Installing Node.js..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    winget install --id OpenJS.NodeJS --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    Ok "Node.js installed"
} else {
    Ok "Node.js already installed: $(node --version)"
}

# ── 6. Claude Code ────────────────────────────────────────────────────────────
Step "Installing Claude Code..."

npm install -g @anthropic-ai/claude-code
Ok "Claude Code installed"

# ── Summary ───────────────────────────────────────────────────────────────────
$bar = "=" * 58
Write-Host "`n$bar" -ForegroundColor Yellow
Write-Host "  Solimar setup complete!" -ForegroundColor Yellow
Write-Host $bar -ForegroundColor Yellow
Write-Host ""
Write-Host "  Tailscale  $TailscaleIP"
Write-Host "  SSH auth   key-only (password disabled)"
Write-Host ""
Write-Host "  Connect from MBP:" -ForegroundColor Cyan
Write-Host "    ssh $env:USERNAME@$TailscaleIP" -ForegroundColor White
Write-Host ""
Write-Host "  Next: set your API key:" -ForegroundColor Yellow
Write-Host '    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","sk-ant-...","Machine")' -ForegroundColor White
Write-Host $bar -ForegroundColor Yellow
