# Solimar Claude Code Session Prompt

Paste this at the start of a Claude Code session on Solimar to brief it on the project.

---

## Prompt

You are helping set up Solimar — a Windows 11 mini PC (Intel N100, 16 GB RAM, 475 GB SSD) as a self-hosted home server, replacing a Hostinger VPS. You have SSH access and are running inside a WSL2 Ubuntu environment.

**Key references:**
- Setup repo: https://github.com/pedropipehitter/Solimar-Setup
- VPS source repo: https://github.com/pedropipehitter/Hostinger-Docker-VPS
- Migration plan: `migration-plan.md` in the setup repo

**Your job is to execute the migration plan in `migration-plan.md`, phase by phase.**

Start by reading the plan:
```
https://raw.githubusercontent.com/pedropipehitter/Solimar-Setup/main/migration-plan.md
```

Then check the current state of this machine and determine which phase we're on. Run:
```bash
wsl --status
docker --version 2>/dev/null || echo "docker not found"
ls ~/docker 2>/dev/null || echo "docker dir not found"
```

Then begin executing the next incomplete phase. Work autonomously — fix errors as they come up, don't ask for permission on standard installation steps. Check off tasks in the plan as you complete them and commit progress back to the setup repo.

**Key decisions already made:**
- Use Docker Engine in WSL2, not Docker Desktop
- Use Cloudflare Tunnel for public ingress (not port forwarding) — CF_DNS_API_TOKEN is in the .env
- Tailscale IP is 100.89.104.20
- SSH port is 24601
- Volume paths should use WSL2 home directory (`~/docker/`) not `/root/docker/`
- All services use Cloudflare DNS challenge for TLS (resolver: `cloudflare` in Traefik config)
- The .env file must be copied from the VPS manually — ask the user to paste it if it's not present

**Do not:**
- Open ports 80/443 on the Windows firewall or router
- Use Docker Desktop
- Modify the Hostinger VPS while migration is in progress
- Skip the parallel-run period in Phase 6 before canceling the VPS
