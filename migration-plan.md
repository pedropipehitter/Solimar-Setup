# Solimar VPS Migration Plan

Migrate Docker services from Hostinger VPS to Solimar (Windows 11 mini PC, Tailscale IP: 100.89.104.20).

## Context

- Source: `github.com/pedropipehitter/Hostinger-Docker-VPS`
- Current stack: Traefik, n8n, Portainer, Open WebUI, Paperless-ngx, AFFiNE, Shlink, Homepage, and supporting services
- Cloudflare DNS challenge already configured (CF_DNS_API_TOKEN in .env) — works without open inbound ports
- Public services (n8n webhooks) will use Cloudflare Tunnel instead of direct port exposure

---

## Phase 1: WSL2 + Docker Engine

Docker Desktop on Windows adds unnecessary overhead and path friction. Run Docker Engine natively inside WSL2 instead.

- [ ] Enable WSL2 and install Ubuntu 24.04 from Microsoft Store
- [ ] Install Docker Engine inside WSL2 (not Docker Desktop)
  - Follow: https://docs.docker.com/engine/install/ubuntu/
  - Add user to docker group: `sudo usermod -aG docker $USER`
- [ ] Configure WSL2 to auto-start Docker on boot
  - Add to `/etc/wsl.conf`: `[boot] command="service docker start"`
- [ ] Configure WSL2 memory/CPU limits in `%USERPROFILE%\.wslconfig`
  - Suggested: `memory=12GB`, `processors=3` (leave 1 core + 4GB for Windows)
- [ ] Verify: `docker run hello-world` from WSL2

---

## Phase 2: Repo + Config Setup

- [ ] Clone Hostinger-Docker-VPS into WSL2 home directory
  ```bash
  git clone git@github.com:pedropipehitter/Hostinger-Docker-VPS.git ~/docker
  ```
- [ ] Copy `.env` from VPS to `~/docker/.env` (scp or manual paste)
- [ ] Update volume mount paths in `docker-compose.yml`
  - Replace `/root/docker/...` with `~/docker/...` (or absolute WSL2 path `/home/solimar/docker/...`)
  - Replace `/root/...` with WSL2 equivalent
  - Replace `/var/run/docker.sock` — works the same in WSL2
- [ ] Create required host directories (homepage config, n8n scripts, postgres init, mcpo config)
- [ ] Create external Docker volumes: `traefik_data`, `n8n_data`

---

## Phase 3: Cloudflare Tunnel (replaces open ports)

Traefik's TLS challenge requires ports 80/443 reachable from the internet. Use Cloudflare Tunnel instead of port forwarding.

- [ ] Install `cloudflared` in WSL2
- [ ] Authenticate: `cloudflared tunnel login`
- [ ] Create tunnel: `cloudflared tunnel create solimar`
- [ ] Add tunnel ingress rules mapping hostnames to local Traefik (localhost:80)
- [ ] Add tunnel as a service in `docker-compose.yml`
- [ ] Point DNS records to tunnel (cloudflared does this automatically)
- [ ] Remove ports 80/443 from Traefik in compose (Cloudflare Tunnel handles ingress)

---

## Phase 4: Service Bring-Up

Bring up in dependency order, verify each before proceeding.

- [ ] `docker compose up -d traefik postgres redis`
- [ ] Verify Postgres is healthy: `docker compose exec postgres pg_isready`
- [ ] `docker compose up -d n8n`
- [ ] Test n8n webhook via Tailscale IP
- [ ] `docker compose up -d portainer watchtower uptime-kuma dozzle`
- [ ] `docker compose up -d paperless-ngx gotenberg tika`
- [ ] `docker compose up -d homepage open-webui shlink affine`
- [ ] `docker compose up -d stirling-pdf it-tools excalidraw code-server mcpo`
- [ ] Verify Cloudflare Tunnel is routing correctly to each subdomain

---

## Phase 5: Data Migration from VPS

- [ ] Export n8n workflows: Settings > Export all workflows (JSON)
- [ ] Export n8n credentials (manual re-entry recommended — n8n credential export is encrypted)
- [ ] Dump Postgres from VPS: `pg_dumpall -U admin > vps_backup.sql`
- [ ] Restore into Solimar Postgres: `psql -U admin < vps_backup.sql`
- [ ] Rsync Paperless media/data volumes from VPS
- [ ] Import n8n workflows into Solimar n8n instance

---

## Phase 6: Cutover + Cleanup

- [ ] Point DNS records to Cloudflare Tunnel (if not already done in Phase 3)
- [ ] Run Uptime Kuma on Solimar monitoring the VPS services — verify all green
- [ ] Run both in parallel for 48 hours
- [ ] Cancel Hostinger VPS subscription

---

## Architecture Notes

- **Public access**: Cloudflare Tunnel -> Traefik -> containers (no router port forwarding needed)
- **Private access**: Tailscale -> direct to container ports or Traefik
- **TLS**: Cloudflare Tunnel handles edge TLS; Traefik handles internal routing
- **Wired ethernet**: Strongly recommended before Phase 4. USB-A or USB-C ethernet adapter if no built-in port.
- **Windows auto-restart**: Set Solimar to auto-login and WSL2 to auto-start on boot for resilience after power outages

---

## Service Tiers (migrate in this order)

| Priority | Service | Notes |
|---|---|---|
| 1 | Traefik + Cloudflare Tunnel | Foundation |
| 1 | Postgres + Redis | Dependencies |
| 1 | n8n | Most critical — automation hub |
| 2 | Portainer, Dozzle, Uptime Kuma | Ops visibility |
| 2 | Paperless-ngx | Document management |
| 3 | Homepage, Open WebUI, AFFiNE | Nice to have |
| 3 | Shlink, Stirling PDF, IT Tools, Excalidraw | Low stakes |
| 4 | Postiz + Temporal | Currently commented out, migrate last |
