# CICD系统 - 云服务器部署指南

## 🚀 部署概览

本指南适用于在云服务器（腾讯云、阿里云、AWS等）上部署CICD系统。

## 📋 部署前准备

### 服务器要求
- **操作系统**: Linux (Ubuntu 20.04+, CentOS 7+, OpenCloudOS等)
- **内存**: 最少 2GB RAM
- **存储**: 最少 10GB 可用空间
- **网络**: 需要开放 4567 端口

### 需要的软件
- Docker & Docker Compose
- Git
- Ruby 3.0+ (备用方案)

## 🔧 快速部署步骤

### 1. 服务器准备
```bash
# 更新系统
sudo yum update -y  # CentOS/OpenCloudOS
# 或
sudo apt update && sudo apt upgrade -y  # Ubuntu

# 安装基础工具
sudo yum install -y git curl wget  # CentOS/OpenCloudOS
# 或
sudo apt install -y git curl wget  # Ubuntu
```

### 2. 安装Docker
```bash
# 快速安装Docker脚本
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

### 3. 克隆项目代码
```bash
# 克隆项目
git clone https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git
cd CICD-pate

# 检查最新代码
git pull origin master
```

### 4. 启动系统
```bash
# 使用Docker启动
sudo docker-compose down  # 停止现有容器
sudo docker-compose up --build -d  # 后台启动

# 查看运行状态
sudo docker-compose ps
sudo docker-compose logs -f  # 查看日志
```

### 5. 防火墙配置
```bash
# CentOS/OpenCloudOS - firewalld
sudo firewall-cmd --permanent --add-port=4567/tcp
sudo firewall-cmd --reload

# Ubuntu - ufw
sudo ufw allow 4567/tcp
sudo ufw reload

# 腾讯云/阿里云控制台
# 还需要在云服务器控制台的安全组中开放4567端口
```

## 🔍 部署验证

### 1. 检查服务状态
```bash
# 检查容器运行状态
sudo docker-compose ps

# 查看应用日志
sudo docker-compose logs web

# 检查端口监听
sudo netstat -tlnp | grep 4567
# 或
sudo ss -tlnp | grep 4567
```

### 2. 测试API端点
```bash
# 健康检查
curl http://localhost:4567/api/health

# 版本信息
curl http://localhost:4567/api/version

# 测试登录API
curl -X POST http://localhost:4567/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 3. 网页访问测试
- 访问地址：`http://您的服务器IP:4567`
- 默认账户：`admin` / `admin123`

## 🛠️ 故障排除

### 常见问题

#### 1. 容器启动失败
```bash
# 查看详细错误日志
sudo docker-compose logs web

# 重新构建镜像
sudo docker-compose build --no-cache web
sudo docker-compose up -d
```

#### 2. 端口访问被拒绝
```bash
# 检查防火墙状态
sudo firewall-cmd --list-all  # CentOS/OpenCloudOS
sudo ufw status  # Ubuntu

# 检查Docker容器端口映射
sudo docker port cicd-pate-web
```

#### 3. 数据库初始化失败
```bash
# 删除数据库文件重新初始化
sudo docker-compose down
sudo docker volume rm cicd-pate_db_data  # 如果有数据卷
sudo docker-compose up --build -d
```

#### 4. 内存不足
```bash
# 检查系统资源
free -h
df -h

# 清理Docker缓存
sudo docker system prune -f
```

## 📊 监控与维护

### 1. 查看系统资源
```bash
# 查看容器资源使用
sudo docker stats

# 查看系统负载
htop
# 或
top
```

### 2. 日志管理
```bash
# 实时查看日志
sudo docker-compose logs -f web

# 查看最近100行日志
sudo docker-compose logs --tail=100 web

# 日志文件位置（如果映射到主机）
tail -f /var/log/cicd/app.log
```

### 3. 数据备份
```bash
# 备份数据库
sudo docker exec cicd-pate-web cp /app/cicd.db /tmp/
sudo docker cp cicd-pate-web:/tmp/cicd.db ./backup_$(date +%Y%m%d_%H%M%S).db

# 定期备份脚本
echo "0 2 * * * /path/to/backup_script.sh" | sudo crontab -
```

## 🔄 更新部署

### 更新代码
```bash
cd CICD-pate
git pull origin master
sudo docker-compose down
sudo docker-compose up --build -d
```

### 回滚版本
```bash
git checkout <previous-commit-hash>
sudo docker-compose down
sudo docker-compose up --build -d
```

## 🌐 生产环境建议

### 1. 使用反向代理
```nginx
# Nginx配置示例
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:4567;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 2. 启用HTTPS
```bash
# 使用Let's Encrypt
sudo yum install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 3. 配置自动重启
```bash
# 设置Docker自动重启
sudo docker-compose down
# 编辑docker-compose.yml，添加 restart: always
sudo docker-compose up -d
```

## 📞 技术支持

如果部署过程中遇到问题：

1. 首先查看日志：`sudo docker-compose logs web`
2. 检查系统资源：`free -h`, `df -h`
3. 验证网络连通性：`curl http://localhost:4567/api/health`
4. 检查防火墙和安全组配置

---

**部署完成后，访问 http://您的服务器IP:4567 开始使用CICD系统！**

默认登录账户：`admin` / `admin123`