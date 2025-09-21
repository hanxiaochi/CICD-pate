# CICD系统 - 云服务器快速测试指南

## 🚀 一键操作脚本

### 核心脚本说明

| 脚本名称 | 功能描述 | 使用场景 |
|---------|---------|---------|
| `cloud_cleanup.sh` | 一键清理环境 | 重置环境、清理旧部署 |
| `cloud_deploy.sh` | 一键部署系统 | 全新部署、环境搭建 |
| `cloud_verify.sh` | 一键验证测试 | 功能测试、状态检查 |
| `cloud_test_workflow.sh` | 完整测试流程 | 自动化测试、批量操作 |

## 🔧 快速使用方法

### 方式1：直接下载执行（推荐）
```bash
# 一键清理
curl -fsSL https://raw.xget.xi-xu.me/gh/hanxiaochi/CICD-pate/master/cloud_cleanup.sh | bash

# 一键部署  
curl -fsSL https://raw.xget.xi-xu.me/gh/hanxiaochi/CICD-pate/master/cloud_deploy.sh | bash

# 一键验证
curl -fsSL https://raw.xget.xi-xu.me/gh/hanxiaochi/CICD-pate/master/cloud_verify.sh | bash
```

### 方式2：克隆后使用
```bash
# 克隆项目
git clone https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git
cd CICD-pate

# 给脚本执行权限
chmod +x *.sh

# 执行操作
./cloud_cleanup.sh        # 清理环境
./cloud_deploy.sh          # 部署系统
./cloud_verify.sh          # 验证测试
./cloud_test_workflow.sh   # 完整流程
```

## 🎯 常用测试场景

### 场景1：全新部署测试
```bash
# 直接部署（适合干净环境）
./cloud_deploy.sh

# 验证部署结果
./cloud_verify.sh
```

### 场景2：重新部署测试
```bash
# 清理旧环境
./cloud_cleanup.sh

# 重新部署
./cloud_deploy.sh

# 验证新部署
./cloud_verify.sh
```

### 场景3：快速重置测试
```bash
# 使用完整工作流（推荐）
./cloud_test_workflow.sh full

# 或分步执行
./cloud_test_workflow.sh cleanup
./cloud_test_workflow.sh deploy
./cloud_test_workflow.sh verify
```

### 场景4：问题修复测试
```bash
# 强制清理并重新部署
./cloud_cleanup.sh --force
./cloud_deploy.sh

# 或使用快速修复
./cloud_test_workflow.sh fix
```

## 📋 详细操作说明

### 清理脚本 (cloud_cleanup.sh)
**功能：** 完全清理CICD系统相关的所有内容
- 停止并删除所有CICD相关Docker容器
- 删除所有CICD相关Docker镜像
- 清理Docker系统缓存和未使用资源
- 删除项目目录 (`~/CICD-pate`, `~/cicd-system` 等)
- 清理相关配置文件和防火墙规则

**使用方法：**
```bash
./cloud_cleanup.sh          # 交互式清理（需确认）
./cloud_cleanup.sh --force  # 强制清理（跳过确认）
./cloud_cleanup.sh --help   # 显示帮助
```

### 部署脚本 (cloud_deploy.sh)
**功能：** 全自动部署CICD系统
- 自动检测系统类型（CentOS/Ubuntu/OpenCloudOS）
- 自动安装Docker和Docker Compose
- 自动配置防火墙规则
- 自动克隆代码并启动服务
- 自动验证部署结果

**特点：**
- 支持多操作系统
- 容错机制完善
- 自动重试网络操作
- 详细的日志输出

### 验证脚本 (cloud_verify.sh)
**功能：** 全面验证系统状态和功能
- Docker状态检查
- 容器运行状态检查
- 端口监听检查
- API接口功能测试
- 登录功能验证
- 数据库状态检查
- 系统资源监控

**输出信息：**
- 访问地址和登录信息
- 管理命令参考
- 故障排除建议

### 工作流脚本 (cloud_test_workflow.sh)
**功能：** 自动化测试工作流管理
- 交互式菜单操作
- 完整流程自动化
- 环境状态检查
- 批量操作支持

**菜单选项：**
1. 🧹 仅清理环境
2. 🚀 仅重新部署  
3. 🔍 仅验证测试
4. 🔄 完整流程：清理 → 部署 → 验证
5. 🆘 快速修复：强制清理 → 重新部署
6. 📊 环境状态检查

## 🌐 系统访问信息

部署成功后：
- **访问地址**: `http://服务器IP:4567`
- **默认账户**: `admin`
- **默认密码**: `admin123`

### API端点测试
```bash
# 健康检查
curl http://localhost:4567/api/health

# 版本信息
curl http://localhost:4567/api/version

# 登录测试
curl -X POST http://localhost:4567/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

## 🛠️ 故障排除

### 常见问题

#### 1. Docker未启动
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### 2. 端口被占用
```bash
sudo netstat -tlnp | grep 4567
sudo kill -9 <PID>
```

#### 3. 网络连接问题
```bash
ping github.com
curl -I https://github.com
```

#### 4. 权限问题
```bash
sudo chmod +x *.sh
sudo chown -R $USER:$USER ~/CICD-pate
```

#### 5. 内存不足
```bash
free -h
docker system prune -f
```

### 日志查看
```bash
# 查看容器日志
sudo docker-compose logs -f

# 查看系统日志
journalctl -f -u docker

# 查看脚本执行日志
tail -f /var/log/messages
```

## 📈 性能优化建议

### 服务器配置
- **最小配置**: 2GB RAM, 10GB 存储
- **推荐配置**: 4GB RAM, 20GB 存储
- **网络要求**: 确保4567端口开放

### 加速部署
```bash
# 使用国内镜像源
export DOCKER_REGISTRY_MIRROR="https://registry.docker-cn.com"

# 并行下载
git clone --depth 1 https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git
```

## 🎉 成功验证标志

部署成功的标志：
- ✅ Docker容器状态为 "Up"
- ✅ 端口4567正在监听
- ✅ API健康检查返回 `{"status":"ok"}`
- ✅ 网页可以正常访问和登录
- ✅ 数据库状态为 "healthy"

---

**快速开始命令：**
```bash
# 一步完成所有操作
curl -fsSL https://raw.xget.xi-xu.me/gh/hanxiaochi/CICD-pate/master/cloud_test_workflow.sh | bash -s full
```