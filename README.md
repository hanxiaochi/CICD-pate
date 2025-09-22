# CICD-pate

一个基于Ruby Sinatra框架的持续集成/持续部署(CI/CD)系统示例项目。

## 项目简介

CICD-pate是一个功能完整的CI/CD平台，提供了项目管理、构建管理、资源管理、脚本管理等核心功能。该项目旨在演示如何使用Ruby Sinatra框架构建一个现代化的Web应用程序。

## 功能特性

### 1. 项目管理
- 创建和管理项目
- 项目详情查看
- 项目列表展示
- 项目搜索功能

### 2. 构建管理
- 创建构建任务
- 查看构建历史
- 构建状态跟踪
- 重新构建功能

### 3. 资源管理
- 管理服务器资源（SSH、Docker、Kubernetes、Windows等）
- 资源连接测试
- 终端连接功能
- 资源状态监控

### 4. 脚本管理
- 创建和管理自动化脚本
- 脚本分类管理
- 脚本执行历史

### 5. 插件管理
- 插件安装和卸载
- 插件状态管理

### 6. 工作空间
- 工作空间管理
- 环境隔离

### 7. 系统管理
- 系统配置
- 用户管理
- 权限控制

## 技术栈

- **后端框架**: Ruby Sinatra
- **数据库**: SQLite (开发环境)
- **模板引擎**: Haml
- **前端框架**: Bootstrap 5
- **图标库**: Bootstrap Icons
- **构建工具**: Maven (Java项目示例)

## 安装和运行

### 环境要求
- Ruby 2.7+
- Bundler
- SQLite3

### 安装步骤

1. 克隆项目代码:
   ```
   git clone https://github.com/hanxiaochi/CICD-pate.git
   cd CICD-pate
   ```

2. 安装依赖:
   ```
   bundle install
   ```

3. 初始化数据库:
   ```
   ruby app.rb
   ```

4. 启动应用:
   ```
   ruby app.rb
   ```

5. 访问应用:
   打开浏览器访问 `http://localhost:4567`

## 使用说明

1. 首次访问需要注册用户账户
2. 登录后可以创建和管理项目
3. 配置服务器资源用于部署
4. 创建构建任务进行持续集成
5. 使用脚本和插件扩展功能

## 项目结构

```
CICD-pate/
├── app.rb                 # 主应用文件
├── config.ru              # Rack配置文件
├── Gemfile                # Ruby依赖声明
├── Gemfile.lock           # Ruby依赖锁定文件
├── lib/                   # 库文件
│   ├── models/            # 数据模型
│   └── tasks/             # 任务脚本
├── views/                 # 视图模板
├── public/                # 静态资源
├── db/                    # 数据库文件
└── test-java-project/     # Java测试项目示例
```

## 开发说明

### 数据模型

- User: 用户模型
- Project: 项目模型
- Build: 构建模型
- Resource: 资源模型
- Script: 脚本模型
- Plugin: 插件模型
- Workspace: 工作空间模型

### 路由结构

应用采用RESTful路由设计，主要路由包括：
- `/` - 仪表板
- `/projects` - 项目管理
- `/builds` - 构建管理
- `/resources` - 资源管理
- `/scripts` - 脚本管理
- `/plugins` - 插件管理
- `/workspaces` - 工作空间管理
- `/system` - 系统管理

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 许可证

本项目采用MIT许可证，详情请见[LICENSE](LICENSE)文件。