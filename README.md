# CICD系统 - 统一精简版

一个现代化的CI/CD持续集成部署系统，支持简化模式和完整功能模式。

## ✨ 特性

### 🎯 双模式支持
- **简化模式** (`simple`): 基础用户管理、项目管理、API接口
- **完整模式** (`full`): 工作空间、构建管理、资源管理、系统监控

### 🚀 快速部署
- **原生安装**: 自动检测系统环境，安装依赖
- **Docker部署**: 一键容器化部署
- **多平台支持**: Ubuntu、CentOS、OpenCloudOS等

## 📦 快速开始

### 方式一：原生安装

```bash
# 下载代码
git clone https://your-repo.git
cd CICD-pate

# 自动安装并启动
chmod +x install.sh
./install.sh

# 手动启动
./cicd-start.sh
# 或者直接
ruby app.rb
```

### 方式二：Docker部署

```bash
# 简化模式（默认）
export CICD_MODE=simple
docker-compose up -d

# 完整功能模式
export CICD_MODE=full
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 🔧 环境要求

- **Ruby**: 3.0+ 
- **SQLite**: 数据库存储
- **系统**: Linux (Ubuntu/CentOS/OpenCloudOS等)

## 🌐 访问系统

- **Web界面**: http://localhost:4567
- **默认账户**: admin / admin123

## 📊 API接口

### 基础API
- `GET /api/health` - 系统健康检查
- `GET /api/version` - 版本信息
- `GET /api/user` - 用户信息 
- `GET /api/projects` - 项目列表

### 完整模式API (CICD_MODE=full)
- `GET /api/workspaces` - 工作空间管理
- `GET /api/builds` - 构建历史
- `GET /api/resources` - 资源管理

## ⚙️ 模式切换

### 设置环境变量

```bash
# 简化模式
export CICD_MODE=simple

# 完整功能模式  
export CICD_MODE=full
```

### Docker模式切换

```bash
# 停止当前容器
docker-compose down

# 设置模式
export CICD_MODE=full  # 或 simple

# 重新启动
docker-compose up -d
```

## 🗂️ 项目结构

```
CICD-pate/
├── app.rb              # 统一主应用（整合所有功能）
├── install.sh          # 原生安装脚本
├── Dockerfile          # Docker镜像构建
├── docker-compose.yml  # Docker编排配置
└── README.md           # 说明文档
```

## 🔍 功能对比

| 功能 | 简化模式 | 完整模式 |
|------|----------|----------|
| 用户登录认证 | ✅ | ✅ |
| 项目管理 | ✅ | ✅ |
| API接口 | ✅ | ✅ |
| 工作空间管理 | ❌ | ✅ |
| 构建管理 | ❌ | ✅ |
| 资源管理 | ❌ | ✅ |
| 系统监控 | ❌ | ✅ |
| 高级UI | ❌ | ✅ |

## 🔧 开发说明

### 依赖管理

**必需依赖**:
- sinatra - Web框架
- sequel - 数据库ORM  
- sqlite3 - 数据库
- bcrypt - 密码加密
- json - JSON处理

**可选依赖**:
- sinatra-flash - 消息提示
- haml - 模板引擎
- sass - 样式处理

### 数据库

系统自动创建SQLite数据库，根据模式创建相应的表结构：

**简化模式**: users, projects, logs
**完整模式**: users, workspaces, projects, builds, resources, logs

## 🆘 故障排除

### 常见问题

1. **Ruby版本过低**
   ```bash
   # 检查版本
   ruby -v
   # 升级Ruby（推荐使用RVM）
   ```

2. **Gem安装失败**
   ```bash
   # 配置国内镜像源
   gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
   ```

3. **数据库权限问题**
   ```bash
   # 确保目录权限
   chmod 755 /app
   ```

4. **Docker启动失败**
   ```bash
   # 查看日志
   docker-compose logs
   # 重建镜像
   docker-compose build --no-cache
   ```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交Issue和Pull Request！

---

**CICD系统** - 让持续集成部署更简单！ 🚀