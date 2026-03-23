#Requires -RunAsAdministrator
# Solimar Home Server Setup
# Run in PowerShell as Administrator

param(
    [string]$StaticIP    = "",
    [string]$Gateway     = "",
    [string]$DNS         = "8.8.8.8,8.8.4.4"
)

$ErrorActionPreference = "Stop"
$TailscaleIP = "100.89.104.20"
$AuthorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINa3YMZrlVaFDAbbscQgH+Bc7ADwoXeFfxM7g7t8p4r5 franciscohermosilloiii@MacBookPro.lan"

function Step  { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok    { param([string]$m) Write-Host "    OK  $m" -ForegroundColor Green }
function Warn  { param([string]$m) Write-Host "    !!  $m" -ForegroundColor Yellow }

# ── 1. Static local IP ────────────────────────────────────────────────────────
Step "Configuring static local IP..."

$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Wireless LAN" } | Select-Object -First 1
if (-not $adapter) {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
}

$currentIP  = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 |
              Where-Object { $_.PrefixOrigin -ne "WellKnown" } |
              Select-Object -First 1
$currentGW  = (Get-NetRoute -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 |
               Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" }).NextHop

if (-not $StaticIP) { $StaticIP = $currentIP.IPAddress }
if (-not $Gateway)  { $Gateway  = $currentGW }
$prefix = $currentIP.PrefixLength

Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $StaticIP -PrefixLength $prefix -DefaultGateway $Gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ($DNS -split ",")

Ok "Static IP: $StaticIP / $prefix  gateway: $Gateway  adapter: $($adapter.Name)"
Warn "Also reserve $StaticIP in your router's DHCP table to avoid conflicts."

# ── 2. OpenSSH Server ─────────────────────────────────────────────────────────
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

# ── 3. Firewall ───────────────────────────────────────────────────────────────
Step "Opening firewall port 22..."

if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}
Ok "Firewall rule active"

# ── 4. Authorized key ─────────────────────────────────────────────────────────
Step "Installing SSH authorized key..."

$sshDir = "C:\ProgramData\ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

$keysFile = "$sshDir\administrators_authorized_keys"
Set-Content -Path $keysFile -Value $AuthorizedKey -Encoding UTF8

# Required permissions: only SYSTEM + Administrators, no inheritance
icacls $keysFile /inheritance:r /grant "SYSTEM:(F)" /grant "Administrators:(F)" | Out-Null
Ok "Key written to $keysFile with correct permissions"

# ── 5. SSH config: key-only auth ──────────────────────────────────────────────
Step "Hardening sshd_config..."

$configPath = "$sshDir\sshd_config"
$config = Get-Content $configPath -Raw

# Ensure PubkeyAuthentication yes
if ($config -match "#?PubkeyAuthentication") {
    $config = $config -replace "#?PubkeyAuthentication\s+\w+", "PubkeyAuthentication yes"
} else {
    $config += "`nPubkeyAuthentication yes"
}

# Disable password auth
if ($config -match "#?PasswordAuthentication") {
    $config = $config -replace "#?PasswordAuthentication\s+\w+", "PasswordAuthentication no"
} else {
    $config += "`nPasswordAuthentication no"
}

Set-Content -Path $configPath -Value $config -Encoding UTF8
Restart-Service sshd
Ok "Key-only auth enforced, sshd restarted"

# ── 6. Node.js ────────────────────────────────────────────────────────────────
Step "Installing Node.js..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    winget install --id OpenJS.NodeJS --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    Ok "Node.js installed"
} else {
    Ok "Node.js already installed: $(node --version)"
}

# ── 7. Claude Code ────────────────────────────────────────────────────────────
Step "Installing Claude Code..."

npm install -g @anthropic-ai/claude-code
Ok "Claude Code installed"

# ── Summary ───────────────────────────────────────────────────────────────────
$bar = "=" * 58
Write-Host "`n$bar" -ForegroundColor Yellow
Write-Host "  Solimar setup complete!" -ForegroundColor Yellow
Write-Host $bar -ForegroundColor Yellow
Write-Host ""
Write-Host "  Local IP   $StaticIP (static, /$prefix)"
Write-Host "  Tailscale  $TailscaleIP"
Write-Host "  SSH auth   key-only (password disabled)"
Write-Host ""
Write-Host "  Connect from MBP:" -ForegroundColor Cyan
Write-Host "    ssh $env:USERNAME@$TailscaleIP" -ForegroundColor White
Write-Host "    ssh $env:USERNAME@$StaticIP     (local network only)" -ForegroundColor White
Write-Host ""
Write-Host "  Next: reserve $StaticIP in your router DHCP settings." -ForegroundColor Yellow
Write-Host $bar -ForegroundColor Yellow
