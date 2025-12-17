# racket-deployer

A lightweight, high-performance CI/CD webhook server written in **Racket**.

This project provides a professional self-hosting alternative for **Obsidian Digital Garden** users. It allows you to transition from Vercel to your own VPS, automating the deployment of your notes while keeping your infrastructure private and efficient.

## 📐 Architecture

### Option 1: Single Server (Build + Host)

```
┌─────────────────────────────────────────┐
│           Obsidian (Local)              │
│                  ↓                      │
│        Digital Garden Plugin            │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│           GitHub Repository             │
│        (Your Private/Public Repo)       │
└──────────────┬──────────────────────────┘
               ↓ Webhook (HTTPS)
        https://webhook.your-domain.com:8443
               ↓
┌─────────────────────────────────────────┐
│          Your Server (All-in-One)       │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │     Nginx (8443 - HTTPS)        │   │
│  │   SSL Termination + Proxy       │   │
│  └────────────┬────────────────────┘   │
│               ↓                        │
│  ┌─────────────────────────────────┐   │
│  │     Racket (8080 - HTTP)        │   │
│  │   Webhook Logic + Automation    │   │
│  │   ├─ git pull                   │   │
│  │   ├─ npm install (if needed)    │   │
│  │   └─ npm run build              │   │
│  └────────────┬────────────────────┘   │
│               ↓                        │
│  ┌─────────────────────────────────┐   │
│  │     Static Files (dist/)        │   │
│  │   /var/www/blog/dist/           │   │
│  └────────────┬────────────────────┘   │
│               ↓                        │
│  ┌─────────────────────────────────┐   │
│  │     Nginx (80 / 443)            │   │
│  │   Serving your-blog.com         │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
               ↓
       Visit your-blog.com
```

### Option 2: Separated Build & Deploy (Recommended)

```
┌──────────────────────────────────────────┐
│        Build Server                       │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ GitHub Webhook                     │ │
│  │   ↓                                │ │
│  │ Racket Service (8080)              │ │
│  │   ├─ git pull                      │ │
│  │   ├─ npm install (if needed)       │ │
│  │   ├─ npm run build                 │ │
│  │   │   └─→ /var/www/blog/dist/      │ │
│  │   └─ rsync (deploy to web server) │ │
│  └────────┬───────────────────────────┘ │
└───────────┼──────────────────────────────┘
            │ SSH + rsync
            │ (auto-sync dist/)
            ↓
┌──────────────────────────────────────────┐
│        Web Server                         │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ /var/www/blog/dist/  (synced)      │ │
│  │   ↓                                │ │
│  │ Nginx                              │ │
│  │   └─→ https://your-blog.com        │ │
│  └────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

## ✨ Features

- **Self-Hosted Freedom**: Full control over your deployment pipeline
- **Designed for Obsidian**: Optimized for the "Obsidian Digital Garden" plugin workflow
- **Asynchronous Builds**: Responds to GitHub immediately while processing the build in the background
- **Concurrency Safety**: Uses a global semaphore lock to prevent multiple simultaneous builds
- **Remote Deploy**: Optional rsync-based deployment to separate web servers
- **Security**: Verifies GitHub webhook signatures using HMAC-SHA256
- **Health Monitoring**: Built-in `/health` endpoint for status checks
- **Educational**: A practical example of Racket's strengths in multithreading and system subprocess management

## 🛠 Prerequisites

### Build Server
- **Racket** (v8.0 or higher)
- **Node.js & npm** (v22+ recommended)
- **OpenSSL**
- **Git**
- **rsync** (if using remote deploy)

### Web Server (if separated)
- **Nginx**
- **rsync**

## 📦 Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/racket-deployer.git
cd racket-deployer
```

### 2. Project Structure

```
racket-deployer/
├── config.json              # Your configuration (do not commit!)
├── config.example.json      # Configuration template
├── main.rkt                 # Main entry point
├── README.md                # This file
└── src/
    ├── config.rkt           # Configuration management
    ├── git.rkt              # Git operations
    ├── build.rkt            # Build operations
    ├── deploy.rkt           # Remote deployment (rsync)
    └── webhook.rkt          # Webhook handling
```

### 3. Configuration

Create `config.json` from the template:

```bash
cp config.example.json config.json
```

Edit `config.json`:

#### Basic Configuration (Single Server)

```json
{
  "github-secret": "your-strong-secret-here",
  "port": 8080,
  "repo-path": "/var/www/blog",
  "repo-url": "https://github.com/username/your-repo.git",
  "build-output": "/var/www/blog/dist"
}
```

#### Advanced Configuration (Separated Build & Deploy)

```json
{
  "github-secret": "your-strong-secret-here",
  "port": 8080,
  "repo-path": "/var/www/blog",
  "repo-url": "https://github.com/username/your-repo.git",
  "build-output": "/var/www/blog/dist",
  "deploy": {
    "enabled": true,
    "remote-host": "user@web-server-ip",
    "remote-path": "/var/www/blog/dist",
    "ssh-key": "/root/.ssh/id_rsa",
    "rsync-options": "-avz --delete"
  }
}
```

**Configuration Options:**

| Option | Description | Required |
|--------|-------------|----------|
| `github-secret` | GitHub webhook secret | Yes |
| `port` | Racket server port (default: 8080) | Yes |
| `repo-path` | Local repository path | Yes |
| `repo-url` | GitHub repository URL | Yes |
| `build-output` | Build output directory | Yes |
| `deploy.enabled` | Enable remote deployment | No |
| `deploy.remote-host` | Remote server (user@host) | If deploy enabled |
| `deploy.remote-path` | Remote directory path | If deploy enabled |
| `deploy.ssh-key` | SSH private key path | If deploy enabled |
| `deploy.rsync-options` | rsync command options | No (default: `-avz --delete`) |

### 4. Setup Remote Deploy (Optional)

If you're using separate build and web servers:

#### On Build Server

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# View public key
cat ~/.ssh/id_rsa.pub
```

#### On Web Server

```bash
# Add build server's public key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "paste-public-key-here" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### Test Connection

```bash
# On build server
ssh -i ~/.ssh/id_rsa user@web-server-ip "echo 'Connection successful'"
```

### 5. Clone Your Blog Repository

```bash
# Create directory
sudo mkdir -p /var/www/blog
sudo chown -R $USER:$USER /var/www/blog

# Clone repository
git clone https://github.com/username/your-repo.git /var/www/blog

# Install dependencies
cd /var/www/blog
npm install

# Test build
npm run build
```

### 6. Run the Server

#### Manual Start

```bash
racket main.rkt
```

#### As a systemd Service

Create `/etc/systemd/system/blog-deploy.service`:

```ini
[Unit]
Description=Blog Deploy Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/racket-deployer
ExecStart=/usr/bin/racket /root/racket-deployer/main.rkt
Restart=always
RestartSec=10
StandardOutput=append:/var/log/blog-deploy.log
StandardError=append:/var/log/blog-deploy-error.log

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable blog-deploy
sudo systemctl start blog-deploy
sudo systemctl status blog-deploy
```

## 🌐 Nginx Configuration

### Webhook Proxy (Port 8443)

Create `/etc/nginx/sites-available/webhook`:

```nginx
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name webhook.your-domain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS webhook endpoint
server {
    listen 8443 ssl http2;
    server_name webhook.your-domain.com;
    
    # SSL Configuration (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/webhook.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webhook.your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Logs
    access_log /var/log/nginx/webhook-access.log;
    error_log /var/log/nginx/webhook-error.log;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Build tasks may take time
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### Blog Site (Port 443)

Create `/etc/nginx/sites-available/blog`:

```nginx
# HTTP redirect
server {
    listen 80;
    server_name your-blog.com www.your-blog.com;
    return 301 https://your-blog.com$request_uri;
}

# HTTPS blog site
server {
    listen 443 ssl http2;
    server_name your-blog.com www.your-blog.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-blog.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-blog.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Website root
    root /var/www/blog/dist;
    index index.html;
    charset utf-8;
    
    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Static asset caching
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/x-javascript application/xml+rss
               application/json application/javascript
               image/svg+xml;
}
```

Enable configurations:

```bash
sudo ln -s /etc/nginx/sites-available/webhook /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/blog /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL Certificates

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificates
sudo certbot certonly --nginx -d webhook.your-domain.com
sudo certbot certonly --nginx -d your-blog.com -d www.your-blog.com
```

## 🔗 GitHub Webhook Setup

1. Go to your repository **Settings** → **Webhooks** → **Add webhook**
2. Configure:
   - **Payload URL**: `https://webhook.your-domain.com:8443/`
   - **Content type**: `application/json`
   - **Secret**: Your `github-secret` from `config.json`
   - **SSL verification**: ✅ Enable SSL verification
   - **Events**: Just the `push` event
3. **Add webhook**

## 📡 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Basic service status |
| `/health` | GET | Build status and last build time |
| `/` | POST | GitHub webhook receiver |

### Health Check Example

```bash
curl https://webhook.your-domain.com:8443/health

# Response:
# Status: success
# Last build: 120 seconds ago
```

## 🛡️ Security Best Practices

1. **Protect your Secrets**: 
   - Add `config.json` to `.gitignore`
   - Use a strong, randomly generated webhook secret:
     ```bash
     openssl rand -hex 32
     ```

2. **Network Security**:
   - Racket listens on `127.0.0.1` only (not exposed to public)
   - Always use Nginx as reverse proxy
   - Enable SSL verification in GitHub webhook settings

3. **SSH Keys** (for remote deploy):
   - Use dedicated SSH keys with limited permissions
   - Consider using `authorized_keys` restrictions:
     ```
     command="rsync --server ..." ssh-rsa AAAA...
     ```

4. **Firewall**:
   - Open only necessary ports (80, 443, 8443)
   - Close port 8080 (Racket) to public access

## 🔍 Troubleshooting

### Check Service Status

```bash
sudo systemctl status blog-deploy
sudo journalctl -u blog-deploy -f
```

### Test Components

```bash
# Test Racket service
curl http://127.0.0.1:8080

# Test webhook endpoint
curl https://webhook.your-domain.com:8443

# Test health endpoint
curl https://webhook.your-domain.com:8443/health

# Manual build
cd /var/www/blog
git pull
npm run build

# Test rsync (if using remote deploy)
rsync -avz --delete -e 'ssh -i ~/.ssh/id_rsa' \
  /var/www/blog/dist/ \
  user@web-server:/var/www/blog/dist
```

### Common Issues

**Build fails:**
- Check Node.js and npm versions
- Verify `package.json` exists
- Check disk space: `df -h`

**Webhook not triggered:**
- Verify GitHub webhook delivery in repository settings
- Check signature in logs
- Ensure port 8443 is open in firewall

**Deploy fails:**
- Test SSH connection manually
- Check SSH key permissions (should be 600)
- Verify rsync is installed on both servers

## 📊 Performance Notes

- **Concurrency**: Only one build runs at a time (semaphore-protected)
- **Background Processing**: Webhook responds immediately, build runs async
- **Resource Usage**: Typical build consumes 200-500MB RAM, 1-2 CPU minutes

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT License - feel free to use this project for personal or commercial purposes.

## 🙏 Acknowledgments

- Built with [Racket](https://racket-lang.org/)
- Inspired by the [Obsidian Digital Garden](https://github.com/oleeskild/obsidian-digital-garden) plugin
- Designed as a Vercel alternative for self-hosting enthusiasts

## 📮 Support

- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/racket-deployer/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/racket-deployer/discussions)

---

**Happy deploying! 🚀**