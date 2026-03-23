# Solimar Home Server Setup

Scripts to turn Solimar (Windows 11 mini PC) into a home server accessible via SSH + Tailscale.

**Tailscale IP:** `100.89.104.20`

## What `setup.ps1` does

1. Locks current DHCP-assigned IP as static
2. Installs and auto-starts OpenSSH Server
3. Opens firewall port 22
4. Installs MBP public key to `administrators_authorized_keys`
5. Disables password auth (key-only)
6. Installs Node.js via winget
7. Installs Claude Code globally

## Running the script on Solimar

**Option A — one-liner (no git needed):**

Push this repo to GitHub first (public or with a PAT), then in PowerShell as Administrator:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://github.com/pedropipehitter/Solimar-Setup/raw/main/setup.ps1 | iex
```

**Option B — clone and run:**

```powershell
# In PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
git clone https://github.com/pedropipehitter/Solimar-Setup.git
cd solimar-setup
.\setup.ps1
```

**Override IP if needed** (skip to use current DHCP address):

```powershell
.\setup.ps1 -StaticIP 192.168.1.50 -Gateway 192.168.1.1
```

## After setup: connect from MBP

Add the block in `ssh-config-snippet.txt` to `~/.ssh/config` (replace `<YOUR_WINDOWS_USERNAME>`), then:

```bash
ssh solimar
```

## Post-setup checklist

- [ ] Reserve the static IP in your router's DHCP table
- [ ] Add `ssh-config-snippet.txt` block to `~/.ssh/config` on MBP
- [ ] Test connection: `ssh solimar`
- [ ] Set `ANTHROPIC_API_KEY` on Solimar: `[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","sk-...", "Machine")`

## Planned: VPS migration

Services to move from Hostinger VPS to Solimar (via Tailscale, no public ports needed):

- [ ] n8n (currently at `docker-compose.yml` in Hostinger-Docker-VPS)
- [ ] Traefik (may be replaced by Tailscale + Caddy for local routing)


------------
here's the error from the first run: irm : 404: Not Found
At line:2 char:1
+ irm https://raw.githubusercontent.com/pedropipehitter/solimar-setup/m ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-RestMethod], WebExc
   eption
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRestMethodCommand


  ------ 3rd try
  New-NetIPAddress : Invalid parameter DefaultGateway
At line:40 char:1
+ New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (MSFT_NetIPAddress:ROOT/StandardCimv2/MSFT_NetIPAddress) [New-NetIPAddr
   ess], CimException
    + FullyQualifiedErrorId : Windows System Error 87,New-NetIPAddress
