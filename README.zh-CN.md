# Deployer

一个用 Racket 编写的轻量级、高性能 CI/CD Webhook 服务器。专为 **Obsidian Digital Garden** 用户设计，帮助你从 Vercel 迁移到自己的 VPS 上自主部署。

![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

[English](README.md) · **中文**

## 功能特性

- **完全自主托管** —— 完整掌控部署流程，不受平台限制
- **专为 Obsidian Digital Garden 设计** —— 针对插件的发布流程优化
- **异步构建** —— 立即响应 GitHub，后台执行构建任务
- **并发安全** —— 基于信号量的锁机制防止并发构建；构建期间有新推送时自动排队重建
- **HMAC-SHA256 签名验证** —— 校验 GitHub Webhook 签名，防止伪造请求
- **灵活部署** —— 支持 HTTP 直连，也支持 Nginx 反向代理（HTTPS）
- **rsync 远程部署** —— 可选将构建产物同步到独立的 Web 服务器
- **健康检查接口** —— `/health` 返回当前构建状态和距上次构建的时间
- **自动重试** —— `git pull` 失败时自动重试

## 环境要求

| 工具 | 用途 |
|------|------|
| Racket 8.0+ | 运行时 |
| Node.js & npm | 构建站点 |
| Git | 版本控制 |
| OpenSSL | 签名验证 |
| rsync | 远程部署（可选） |
| Nginx | HTTPS 反向代理（可选） |

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/turinglambdaai/deployer.git
cd deployer
```

### 2. 配置

```bash
cp config.example.json config.json
```

最小配置（HTTP 直连）：

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

生产环境配置（Nginx + 远程部署）：

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

### 3. 准备博客仓库

```bash
sudo mkdir -p /var/www/blog
sudo chown -R $USER:$USER /var/www/blog
git clone https://github.com/username/your-blog.git /var/www/blog
cd /var/www/blog && npm install && npm run build
```

### 4. 启动服务

```bash
cd deployer
racket main.rkt
```

### 5. 配置 GitHub Webhook

在仓库设置中添加 Webhook：

| 字段 | HTTP 直连 | Nginx HTTPS |
|------|-----------|-------------|
| Payload URL | `http://your-server:8080/` | `https://webhook.example.com:8443/` |
| Content type | `application/json` | `application/json` |
| Secret | 你的 `github-secret` | 你的 `github-secret` |
| SSL 验证 | 禁用 | 启用 |

## 项目结构

```
deployer/
├── main.rkt              入口，启动 HTTP 服务器
├── config.example.json   示例配置文件
└── src/
    ├── config.rkt        JSON 配置加载器
    ├── webhook.rkt       Webhook 处理、签名验证、异步构建
    ├── build.rkt         npm 安装与构建编排
    ├── deploy.rkt        基于 rsync 的远程部署
    └── git.rkt           Git 克隆与拉取（含重试）
```

## 配置说明

| 选项 | 说明 | 默认值 | 必填 |
|------|------|--------|------|
| `github-secret` | GitHub Webhook 密钥 | -- | 是 |
| `port` | HTTP 服务端口 | `8080` | 是 |
| `listen-ip` | `0.0.0.0`（所有接口）或 `127.0.0.1`（仅本地） | `127.0.0.1` | 是 |
| `repo-path` | 本地仓库路径 | -- | 是 |
| `repo-url` | GitHub 仓库地址 | -- | 是 |
| `build-output` | 构建输出目录 | -- | 是 |
| `deploy.enabled` | 启用远程部署 | `false` | 否 |
| `deploy.remote-host` | 远程服务器（`user@host`） | -- | 启用部署时必填 |
| `deploy.remote-path` | 远程目录路径 | -- | 启用部署时必填 |
| `deploy.ssh-key` | SSH 私钥路径 | -- | 启用部署时必填 |
| `deploy.rsync-options` | rsync 参数 | `-avz --delete` | 否 |

## API 接口

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 服务状态 |
| `/health` | GET | 构建状态及距上次构建的秒数 |
| `/` | POST | GitHub Webhook 接收器 |

```bash
# 状态查询
curl http://localhost:8080

# 健康检查
curl http://localhost:8080/health
```

## 以 systemd 服务运行

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

## 许可证

基于 [Apache License 2.0](LICENSE) 开源。
