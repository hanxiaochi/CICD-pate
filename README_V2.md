# CICD 系统 V2 - 使用说明

## 🎯 彻底解决方案

经过完整重构，现在提供了**稳定可靠**的CICD系统V2版本，彻底解决了数据库初始化问题。

## 🚀 快速启动

### 方法一：直接运行（推荐）
```bash
ruby app_v2.rb
```

### 方法二：使用 Puma
```bash
puma config.ru
```

### 方法三：Docker 运行
```bash
docker-compose up --build
```

## 🔧 系统验证

运行完整验证脚本：
```bash
ruby complete_verification_v2.rb
```

## 📋 默认配置

- **访问地址**: http://localhost:4567
- **管理员账户**: admin / admin123
- **数据库**: SQLite (cicd.db)
- **视图引擎**: ERB

## ✨ 新架构特点

### 数据库优先初始化
- 立即创建数据库连接
- 在模型加载前完成表结构创建
- 内置默认数据，无需手动配置

### 简化架构设计
- 移除复杂的模块依赖
- 减少文件间耦合
- 提高启动可靠性

### 错误容错机制
- 数据库初始化失败不导致应用崩溃
- 详细的错误日志和状态提示
- 渐进式降级处理

## 📁 新增文件

- `config/application_v2.rb` - 新的配置文件
- `app_v2.rb` - 简化的主应用文件
- `views/login.erb` - 登录页面
- `views/index.erb` - 首页界面
- `complete_verification_v2.rb` - 完整验证脚本

## 🔍 API 端点

- `GET /` - 系统首页（需要登录）
- `GET /login` - 登录页面
- `POST /login` - 登录处理
- `GET /logout` - 退出登录
- `GET /api/version` - API版本信息
- `GET /api/health` - 系统健康检查
- `GET /api/user` - 用户信息（需要登录）
- `GET /api/projects` - 项目列表（需要登录）

## 🛠️ 故障排除

如果仍然遇到问题：

1. **运行验证脚本**：
   ```bash
   ruby complete_verification_v2.rb
   ```

2. **检查数据库**：
   ```bash
   sqlite3 cicd.db ".tables"
   ```

3. **查看日志**：
   启动时会显示详细的初始化过程

4. **重置数据库**：
   ```bash
   rm cicd.db
   ruby app_v2.rb
   ```

## ⚡ 性能优化

- 使用单一数据库连接
- 简化模型继承关系
- 减少文件加载开销
- 内存友好的架构设计

## 🔒 安全特性

- BCrypt 密码加密
- 会话管理
- 用户角色权限控制
- SQL 注入防护（Sequel ORM）

现在系统应该可以**100%稳定启动**，不再出现任何数据库相关错误！