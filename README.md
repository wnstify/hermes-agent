<p align="center">
  <img src="https://mintcdn.com/minimax-cac98058/GOJmMenSBGK8R2VS/images/hermes-agent-banner.png?w=1100&fit=max&auto=format&n=GOJmMenSBGK8R2VS&q=85&s=f0183fe4510f6e99a4158628af7fd666" alt="Hermes Agent" width="1100">
</p>

# Hermes Agent — secure self-hosted reference patterns

Hardening patterns for running an AI agent stack ([Hermes Agent](https://github.com/NousResearch/hermes-agent) + [Honcho](https://github.com/plastic-labs/honcho)) on company servers without exposing production.

Code companion to **[Secure AI Agent Infrastructure for Companies](https://webnestify.cloud/insights/cybersecurity-hardening/secure-ai-agent-infrastructure-companies/)** — the blog post walks through the *why* behind every choice in these files. The files are *what* it looks like once applied.

## What's in here

| File | What it shows |
|---|---|
| [`sandbox/compose.yml`](sandbox/compose.yml) | Hardened single-purpose execution container — rootless Docker, `cap_drop:[ALL]` with narrow add-backs, `no-new-privileges`, `pids_limit`, `mem_limit`, `cpus`, tmpfs for `/tmp` and `/run`, bind-mounted `/workspace`. Plus a headless Chrome over CDP bound to a private interface only (CDP has zero authentication — network layer is the only gate). |
| [`sandbox/sandbox-entry.sh`](sandbox/sandbox-entry.sh) | SSH `ForceCommand` target that pipes the gateway → sandbox session into `docker exec`, with **explicit env var allowlisting**. No full env forwarding; only vars listed in `PASSTHROUGH_VARS` *and* `AcceptEnv` (sshd) get through. |
| [`gateway/honcho-stack/compose.yml`](gateway/honcho-stack/compose.yml) | Hardened Honcho self-hosted stack (API + Postgres/pgvector + Redis + deriver worker). Internal-only networks, bind-mounted data dirs with explicit UID ownership, strict per-service resource and capability limits. |

> [!TIP]
> <a href="https://webnestify.cloud"><img src="https://webnestify.cloud/_astro/logo-footer.DEOoY9tu_1CtmJ9.svg" alt="Webnestify" height="50"></a>
>
> ### Need help deploying this in your company?
>
> Webnestify designs, deploys, hardens, and monitors private AI agent infrastructure on your own servers — gateway/sandbox split, rootless Docker, Docker Hardened Images, scoped tokens, tested backups, off-site encrypted snapshots.
>
> **→ [webnestify.cloud](https://webnestify.cloud)**

## How to read these files

Read them alongside the blog post. Each file is heavily commented, and every hardening choice is there for a reason that maps back to a specific threat the post discusses:

- **`cap_drop:[ALL]` + narrow `cap_add`** → blast-radius reduction if the container is compromised
- **`no-new-privileges:true`** → blocks SUID escalation paths
- **`pids_limit`, `mem_limit`, `cpus`** → resource exhaustion containment
- **`tmpfs` for `/tmp` and `/run`** → no on-disk persistence of agent scratch state; survives a `--force-recreate`
- **Internal-only network for the database** → DB never reachable from outside the compose stack, even if a host port leaks
- **Bind mounts with explicit chown/chmod** → no Docker-managed named volumes (auditable on the host filesystem)
- **CDP bound to a private interface only** → Chrome DevTools Protocol is unauthenticated by design; network restriction is the *only* control
- **SSH `ForceCommand` + env allowlist** → the gateway can run agent commands in the sandbox but cannot exfiltrate arbitrary env to the host

## What's intentionally not in this repo

- **Real values.** Compose files reference `POSTGRES_PASSWORD`, LLM API keys, JWT secrets, etc. via env. Supply them from a secrets manager (Bitwarden, 1Password, Doppler, Vault) — never commit them.
- **The agent itself.** Install Hermes and Honcho from upstream:
  - <https://github.com/NousResearch/hermes-agent>
  - <https://github.com/plastic-labs/honcho>
- **The rest of the architecture.** Tailscale ACLs, sshd hardening, sysctl tuning, restic backup machinery, n8n heartbeat/failure webhooks. The blog post covers them at the design level; the implementation specifics are deployment-dependent.
## Optional: upgrade to Docker Hardened Images

The Honcho stack ships with public images by default (`pgvector/pgvector:0.8.2-pg18`, `redis:8.6.1-alpine`). If you have a paid Docker subscription with [Docker Hardened Images](https://www.docker.com/products/hardened-images/) access, swap them for the DHI equivalents — same hardening pattern around them, just with provenance-signed, SLSA-attested, minimally-built base images:

```yaml
# database service
image: dhi.io/pgvector:0.8.2-pg18

# redis service
image: dhi.io/redis:8.6.1
```

Run `docker login dhi.io` first (with a Docker Personal Access Token scoped to public-repo-read). DHI buys you a smaller attack surface in the base layer; everything else in this compose stays the same.

## Adapting these files

Two placeholders to replace before bringing the sandbox stack up:

1. **`sandbox/compose.yml`** — the CDP port binding (`127.0.0.1:9222:9222`) and DNS resolver IP (`10.0.0.53`) are placeholders. Replace with your tailnet/WireGuard interface IP and your internal DNS resolver respectively.
2. **`sandbox/sandbox-entry.sh`** — assumes rootless Docker is installed at `~/bin/docker` (the default for `dockerd-rootless-setuptool.sh install`). Adjust if your install path differs.

## License

No license file shipped. Treat these patterns as reference material for the blog post — copy, adapt, and harden for your environment. If you publish derivative work, a link back to the blog post or this repo is appreciated but not required.
