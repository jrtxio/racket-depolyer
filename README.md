# racket-deployer

A lightweight, high-performance CI/CD webhook server written in **Racket**.

This project provides a professional self-hosting alternative for **Obsidian Digital Garden** users. It allows you to transition from Vercel to your own VPS, automating the deployment of your notes while keeping your infrastructure private and efficient.

## ✨ Features

- 🚀 **Self-Hosted Freedom**: Full control over your deployment pipeline
- 📝 **Designed for Obsidian**: Optimized for the "Obsidian Digital Garden" plugin workflow
- ⚡ **Asynchronous Builds**: Responds to GitHub immediately while processing builds in background
- 🔒 **Concurrency Safety**: Semaphore-based locking prevents simultaneous builds
- 🔐 **Security**: HMAC-SHA256 signature verification for GitHub webhooks
- 🌐 **Flexible Deployment**: Direct HTTP or Nginx reverse proxy modes
- 📦 **Remote Deploy**: Optional rsync-based deployment to separate web servers
- 💚 **Health Monitoring**: Built-in `/health` endpoint for status checks
- 🎓 **Educational**: A practical example of Racket's multithreading capabilities

## 📐 Architecture Options

### Option 1: Direct HTTP Mode (Simple)

```
GitHub → HTTP Webhook → Racket (0.0.0.0:8080) → Build → Deploy
```

**Pros**: Simple setup, no Nginx required  
**Cons**: No HTTPS, must disable SSL verification in GitHub

### Option 2: Nginx Proxy Mode (Recommended)

```
GitHub → HTTPS Webhook → Nginx (443/8443) → Racket (127.0.0.1:8080) → Build → Deploy
```

**Pros**: Secure HTTPS, SSL verification enabled  
**Cons**: Requires Nginx and SSL certificate setup

### Option 3: Separated Build & Deploy (Production)

```
Build Server:
  GitHub → Webhook → Racket → Build → rsync

Web Server:
  Nginx → Static Files (synced via rsync)
```

**Pros**: Separation of concerns, scalable, secure  
**Cons**: Requires two servers and SSH key setup

## 🛠 Prerequisites

### Build Server
- **Racket** (v8.0+)
- **Node.js & npm** (v22+ recommended)
- **OpenSSL**
- **Git**
- **rsync** (if using remote deploy)
- **Nginx** (optional, for HTTPS)

### Web Server (if separated)
- **Nginx**
- **rsync**

## 📦 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/racket-deployer.git
cd racket-deployer
```

### 2. Configure

```bash
cp config.example.json config.json
nano config.json
```

**Minimal Configuration (Direct HTTP):**
```json
{
  "github-secret": "your-strong-secret",
  "port": 8080,
  "listen-ip": "0.0.0.0",
  "repo-path": "/var/www/blog",
  "repo-url": "https://github.com/username/repo.git",
  "build-output": "/var/www/blog/dist"
}
```

**Production Configuration (Nginx + Remote Deploy):**
```json
{
  "github-secret": "your-strong-secret",
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

### 3. Clone Your Blog Repository

```bash
sudo mkdir -p /var/www/blog
sudo chown -R $USER:$USER /var/www/blog
git clone https://github.com/username/your-blog.git /var/www/blog
cd /var/www/blog
npm install
npm run build  # Test build
```

### 4. Run

```bash
cd racket-deployer
racket main.rkt
```

### 5. Setup GitHub Webhook

**For Direct HTTP Mode:**
- Payload URL: `http://your-server-ip:8080/`
- Content type: `application/json`
- Secret: Your `github-secret`
- SSL verification: ❌ **Disable**

**For Nginx HTTPS Mode:**
- Payload URL: `https://webhook.your-domain.com:8443/`
- Content type: `application/json`
- Secret: Your `github-secret`
- SSL verification: ✅ **Enable**

## 📋 Configuration Reference

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `github-secret` | GitHub webhook secret | - | Yes |
| `port` | Server port | 8080 | Yes |
| `listen-ip` | Listen address (`0.0.0.0` or `127.0.0.1`) | `127.0.0.1` | Yes |
| `repo-path` | Local repository path | - | Yes |
| `repo-url` | GitHub repository URL | - | Yes |
| `build-output` | Build output directory | - | Yes |
| `deploy.enabled` | Enable remote deployment | `false` | No |
| `deploy.remote-host` | Remote server (user@host) | - | If deploy enabled |
| `deploy.remote-path` | Remote directory path | - | If deploy enabled |
| `deploy.ssh-key` | SSH private key path | - | If deploy enabled |
| `deploy.rsync-options` | rsync command options | `-avz --delete` | No |

### Listen IP Options

| Value | Description | Use Case |
|-------|-------------|----------|
| `0.0.0.0` | Listen on all interfaces | Direct HTTP access, testing, internal networks |
| `127.0.0.1` | Listen on localhost only | Production with Nginx reverse proxy |

## 🌐 Nginx Setup (Optional)

### For Non-Standard Port (e.g., 8443)

```nginx
server {
    listen 8443 ssl http2;
    server_name webhook.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/webhook.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webhook.your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

Enable and test:

```bash
sudo ln -s /etc/nginx/sites-available/webhook /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL Certificate

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot certonly --nginx -d webhook.your-domain.com
```

## 🔐 Remote Deployment Setup

### 1. Generate SSH Key (Build Server)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub
```

### 2. Add Public Key (Web Server)

```bash
# On web server
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste the public key, save
chmod 600 ~/.ssh/authorized_keys
```

### 3. Test Connection

```bash
# On build server
ssh -i ~/.ssh/id_rsa user@web-server-ip "echo 'SSH OK'"
```

### 4. Test rsync

```bash
rsync -avz --delete -e 'ssh -i ~/.ssh/id_rsa' \
  /var/www/blog/dist/ \
  user@web-server-ip:/var/www/blog/dist \
  --dry-run
```

## 🔧 Systemd Service

```bash
sudo nano /etc/systemd/system/blog-deploy.service
```

```ini
[Unit]
Description=Blog Deploy Webhook Server
After=network.target

[Service]
Type=simple
User=youruser
Group=youruser
WorkingDirectory=/home/youruser/racket-deployer
Environment="PATH=/usr/bin:/bin:/usr/local/bin"
ExecStart=/usr/bin/racket /home/youruser/racket-deployer/main.rkt
Restart=always
RestartSec=10
StandardOutput=append:/var/log/blog-deploy.log
StandardError=append:/var/log/blog-deploy-error.log

[Install]
WantedBy=multi-user.target
```

Start service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable blog-deploy
sudo systemctl start blog-deploy
sudo systemctl status blog-deploy
```

## 📡 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Service status |
| `/health` | GET | Build status and last build time |
| `/` | POST | GitHub webhook receiver |

### Examples

```bash
# Basic status
curl http://localhost:8080
# Response:
# Blog Deploy Webhook
# Status: Running

# Health check
curl http://localhost:8080/health
# Response:
# Status: idle
# (or: Status: building / success / failed)
# Last build: 120 seconds ago
```

## 🔍 Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u blog-deploy -n 50

# Test manually
cd ~/racket-deployer
racket main.rkt
```

### Webhook not triggered

```bash
# Check GitHub webhook deliveries
# Repository → Settings → Webhooks → Recent Deliveries

# Check signature
sudo journalctl -u blog-deploy -f
# Look for: ✓ Signature verified
```

### Build fails

```bash
# Manual build
cd /var/www/blog
npm run build

# Check disk space
df -h

# Check Node.js version
node --version
```

### Remote deploy fails

```bash
# Test SSH
ssh -i ~/.ssh/id_rsa user@web-server "echo OK"

# Test rsync manually
rsync -avz -e 'ssh -i ~/.ssh/id_rsa' \
  /var/www/blog/dist/ \
  user@web-server:/var/www/blog/dist

# Check SSH key permissions
ls -la ~/.ssh/id_rsa  # Should be -rw-------
chmod 600 ~/.ssh/id_rsa
```

### Proxy issues

If using HTTP proxy, disable it for localhost:

```bash
export no_proxy="localhost,127.0.0.1"
```

## 🔐 Security Best Practices

1. **Strong Secrets**: Generate with `openssl rand -hex 32`
2. **SSH Keys**: Use dedicated keys with proper permissions (600)
3. **Firewall**: Only open necessary ports
4. **Nginx**: Use HTTPS in production
5. **Updates**: Keep dependencies updated

### Recommended Port Configuration

**Direct HTTP Mode:**
- Open: 8080 (webhook), 22 (SSH)

**Nginx Proxy Mode:**
- Open: 8443 (webhook HTTPS), 22 (SSH)
- Closed: 8080 (Racket, local only)

## 📊 Deployment Comparison

| Feature | Direct HTTP | Nginx Proxy | Separated Deploy |
|---------|-------------|-------------|------------------|
| Setup Complexity | ⭐ Simple | ⭐⭐ Medium | ⭐⭐⭐ Complex |
| HTTPS Support | ❌ | ✅ | ✅ |
| Security | ⚠️ Basic | ✅ Good | ✅ Excellent |
| SSL Verification | ❌ | ✅ | ✅ |
| Scalability | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| Recommended For | Testing | Small sites | Production |

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT License - free to use for personal or commercial purposes.

## 🙏 Acknowledgments

- Built with [Racket](https://racket-lang.org/)
- Inspired by [Obsidian Digital Garden](https://github.com/oleeskild/obsidian-digital-garden)
- Designed as a Vercel alternative for self-hosting enthusiasts

## 📮 Support

- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/racket-deployer/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/racket-deployer/discussions)

---

**Happy deploying! 🚀**