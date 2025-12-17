# racket-deployer

A lightweight, high-performance CI/CD webhook server written in **Racket**.

This project provides a professional self-hosting alternative for **Obsidian Digital Garden** users. It allows you to transition from Vercel to your own VPS, automating the deployment of your notes while keeping your infrastructure private and efficient.

## 📐 Architecture

Plaintext

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
               ↓ https://webhook.your-domain.com:8443
               ↓
┌─────────────────────────────────────────┐
│             Your Server                 │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │     Nginx (8443 - HTTPS)        │    │
│  │   SSL Termination + Proxy       │    │
│  └────────────┬────────────────────┘    │
│               ↓                         │
│  ┌─────────────────────────────────┐    │
│  │     Racket (8080 - HTTP)        │    │
│  │   Webhook Logic + Automation     │    │
│  │   ├─ git pull                   │    │
│  │   ├─ npm install (if needed)    │    │
│  │   └─ npm run build              │    │
│  └────────────┬────────────────────┘    │
│               ↓                         │
│  ┌─────────────────────────────────┐    │
│  │     Static Files (dist/)        │    │
│  │   /path/to/your/web-root/       │    │
│  └────────────┬────────────────────┘    │
│               ↓                         │
│  ┌─────────────────────────────────┐    │
│  │     Nginx (80 / 443)            │    │
│  │   Serving your-blog-site.com    │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
               ↓
       Visit your-blog-site.com
```

## ✨ Why This Project?

- **Self-Hosted Freedom**: Full control over your deployment pipeline.
- **Designed for Obsidian**: Optimized for the "Obsidian Digital Garden" plugin workflow.
- **Asynchronous Builds**: Responds to GitHub immediately while processing the build in the background.
- **Concurrency Safety**: Uses a global semaphore lock to prevent multiple simultaneous builds from overloading your CPU.
- **Security**: Verifies GitHub webhook signatures using HMAC-SHA256 via OpenSSL.
- **Educational**: A practical example of Racket's strengths in multithreading and system subprocess management.

## 🛠 Prerequisites

- **Racket** (v8.0 or higher)
- **Node.js & npm**
- **OpenSSL**
- **Git**

## 📦 Installation & Setup

1. Clone the repository
```bash
git clone https://github.com/yourusername/racket-deployer.git
cd racket-deployer
```

2. Configuration
Create config.json from the template (ensure this file is never committed to Git):
```bash
cp config.example.json config.json
```
Edit `config.json` with your GitHub Secret, local repository path, and build command.

3. Run the server
```bash
racket main.rkt
```

## 🌐 Nginx Configuration Template

Use Nginx as a reverse proxy to handle SSL and forward traffic to the Racket server.

Nginx

```
server {
    listen 8443 ssl http2;
    server_name webhook.your-domain.com; # Replace with your domain
    
    # SSL Configuration (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
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

## 📡 API Endpoints

- **`POST /`**: GitHub Webhook receiver.
- **`GET /health`**: Returns build status (`idle`, `building`, `success`, `failed`) and last build timestamp.
- **`GET /`**: Basic service status page.

## 🛡️ Security Best Practices

1. **Protect your Secrets**: Add `config.json` to your `.gitignore` immediately.
2. **Dedicated Port**: This server listens on `127.0.0.1` by default. Do not expose the Racket port (8080) directly to the public internet; always use a reverse proxy like Nginx.
3. **Webhook Secret**: Always use a strong, randomly generated string for your GitHub Webhook secret.