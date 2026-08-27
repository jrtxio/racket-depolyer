# Deployer

A minimal CI/CD webhook server in ~540 lines of Racket — small enough to read in one sitting, complete enough to have run a real site. Built as a self-hosted alternative for **Obsidian Digital Garden** users who want to move off Vercel and deploy on their own VPS.

![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**English** · [中文](README.zh-CN.md)

> **⚠️ Maintenance mode.** This project is feature-complete and works as documented, but is no longer actively maintained. It was built to self-host my Obsidian Digital Garden; the site it served has since been retired, and the code now lives on as a compact, readable reference implementation. Bug reports are welcome; new features are unlikely. For general-purpose CI/CD needs, see [When to use something else](#when-to-use-something-else).

## Why this code is worth reading

The whole server is ~540 lines of Racket with no framework beyond the standard library — a CI/CD pipeline reduced to its essentials, where every design decision is visible:

- **A build queue in ~30 lines** — `src/webhook.rkt` uses a semaphore as a build lock (`semaphore-try-wait?`) plus a pending-rebuild flag, so concurrent pushes queue up and coalesce into one rebuild instead of racing each other. The entire mechanism fits on one screen.
- **Webhook security** — HMAC-SHA256 verification against GitHub's `X-Hub-Signature-256`; unverified requests get a 401 before anything touches the filesystem.
- **Failure handling without a framework** — `src/git.rkt` implements pull-with-retry in ~40 lines; `src/build.rkt` and `src/deploy.rkt` orchestrate npm/rsync subprocesses with error propagation.
- **Fast webhook acknowledgment** — GitHub receives its 200 immediately while the build runs in a background thread, so a slow `npm install` never triggers GitHub's webhook timeout retry.

## When to use something else

Deployer deliberately does one thing: rebuild a static site on push. If you need build matrices, container isolation, a UI, or arbitrary pipelines, use a real CI system — [Woodpecker CI](https://woodpecker-ci.org/), [Drone](https://www.drone.io/), or [Gitea Actions](https://docs.gitea.com/usage/actions/overview). If you only need generic webhook plumbing, [adnanh/webhook](https://github.com/adnanh/webhook) is the standard tool.

## Features

- **Self-hosted** — full control over your deployment pipeline, no vendor lock-in
- **Built for Obsidian Digital Garden** — optimized for the plugin's publish workflow
- **Asynchronous builds** — responds to GitHub immediately while processing builds in the background
- **Concurrency safety** — semaphore-based locking prevents simultaneous builds; rebuilds are queued if a new push arrives mid-build
- **HMAC-SHA256 verification** — validates GitHub webhook signatures
- **Flexible deployment** — serve directly over HTTP, or place behind an Nginx reverse proxy for HTTPS
- **Remote deploy via rsync** — optionally sync build output to a separate web server
- **Health endpoint** — `/health` returns current build status and time since last build
- **Retry logic** — automatic `git pull` retry with configurable attempts

## Requirements

| Tool | Purpose |
|------|---------|
| Racket 8.0+ | Runtime |
| Node.js & npm | Building the site |
| Git | Source control |
| OpenSSL | Signature verification |
| rsync | Remote deploy (optional) |
| Nginx | HTTPS reverse proxy (optional) |

## Quick Start

### 1. Clone

```bash
git clone https://github.com/turinglambdaai/deployer.git
cd deployer
```

### 2. Configure

```bash
cp config.example.json config.json
```

Minimal configuration (direct HTTP):

```json
{
  "github-secret": "your-webhook-secret",
  "port": 8080,
  "listen-ip": "0.0.0.0",
  "repo-path": "/var/www/blog",
  "repo-url": "https://github.com/username/repo.git",
  "build-output": "/var/www/blog/dist"
}
```

Production configuration (Nginx + remote deploy):

```json
{
  "github-secret": "your-webhook-secret",
  "port": 8080,
  "listen-ip": "127.0.0.1",
  "repo-path": "/var/www/blog",
  "repo-url": "https://github.com/username/repo.git",
  "build-output": "/var/www/blog/dist",
  "deploy": {
    "enabled": true,
    "remote-host": "user@web-server-ip",
    "remote-path": "/var/www/blog/dist",
    "ssh-key": "/home/user/.ssh/id_rsa",
    "rsync-options": "-avz --delete"
  }
}
```

### 3. Prepare the Blog Repository

```bash
sudo mkdir -p /var/www/blog
sudo chown -R $USER:$USER /var/www/blog
git clone https://github.com/username/your-blog.git /var/www/blog
cd /var/www/blog && npm install && npm run build
```

### 4. Run

```bash
cd deployer
racket main.rkt
```

### 5. Configure the GitHub Webhook

In your repository settings, add a webhook:

| Field | Direct HTTP | Nginx HTTPS |
|-------|-------------|-------------|
| Payload URL | `http://your-server:8080/` | `https://webhook.example.com:8443/` |
| Content type | `application/json` | `application/json` |
| Secret | your `github-secret` | your `github-secret` |
| SSL verification | Disabled | Enabled |

## Project Structure

```
deployer/
├── main.rkt              Entry point, starts the HTTP server
├── config.example.json   Sample configuration
└── src/
    ├── config.rkt        JSON config loader and accessors
    ├── webhook.rkt       Webhook handler, signature verification, async build
    ├── build.rkt         npm install and build orchestration
    ├── deploy.rkt        rsync-based remote deployment
    └── git.rkt           Git clone and pull with retry
```

## Configuration Reference

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `github-secret` | GitHub webhook secret | -- | Yes |
| `port` | HTTP server port | `8080` | Yes |
| `listen-ip` | `0.0.0.0` (all interfaces) or `127.0.0.1` (localhost) | `127.0.0.1` | Yes |
| `repo-path` | Local repository path | -- | Yes |
| `repo-url` | GitHub repository URL | -- | Yes |
| `build-output` | Build output directory | -- | Yes |
| `deploy.enabled` | Enable remote deployment | `false` | No |
| `deploy.remote-host` | Remote server (`user@host`) | -- | If deploy enabled |
| `deploy.remote-path` | Remote directory | -- | If deploy enabled |
| `deploy.ssh-key` | SSH private key path | -- | If deploy enabled |
| `deploy.rsync-options` | rsync flags | `-avz --delete` | No |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Service status |
| `/health` | GET | Build status and seconds since last build |
| `/` | POST | GitHub webhook receiver |

```bash
# Status check
curl http://localhost:8080

# Health check
curl http://localhost:8080/health
```

## Running as a systemd Service

```ini
[Unit]
Description=Deployer Webhook Server
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/deployer
ExecStart=/usr/bin/racket /home/youruser/deployer/main.rkt
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable deployer
sudo systemctl start deployer
```

## License

Licensed under the [Apache License 2.0](LICENSE).
