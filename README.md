# 轻量级 CI/CD 平台（Next.js 15 + Shadcn/UI）

一个用于演示与验证的前端与 Mock API 实现，覆盖以下核心能力：
- 拉取 Git / SVN 项目，配置构建流水线（演示）
- 部署管理：浏览服务器目录、查看应用进程（演示）
- 应用控制台：基于 nohup 的 Java 启动/停止/重启（演示）
- 用户与权限界面（演示）

本项目可单独部署用于前端演示；当你准备好真实后端（Ruby on Rails + SQLite）后，只需保持相同的 API 契约并切换到 Rails 服务即可。

---

## 技术栈
- 前端：Next.js 15（App Router）+ TypeScript
- UI：shadcn/ui + Tailwind CSS v4
- 图标：lucide-react
- Mock API：Next.js API Routes（可替换为 Rails）

---

## 目录结构（关键）
```
src/
  app/
    page.tsx                 # 首页
    dashboard/               # 项目总览
    projects/                # 项目与仓库（Git/SVN 配置、流水线）
    deployments/             # 部署与监控（目录/进程）
    control/                 # 应用控制台（nohup 启停/重启、日志）
    users/                   # 用户与权限（演示）
    api/                     # Mock API（可替换为 Rails）
```

---

## 环境要求
- Node.js 18+（建议 20+）
- npm / pnpm / bun 任一包管理器

可选环境变量（用于对接 Rails 或外部 API 网关）：
- NEXT_PUBLIC_API_BASE=http://localhost:3000
  - 留空或不设：使用内置的 Mock API（src/app/api/*）
  - 指向你的 Rails 服务后：前端会请求 Rails 的同名接口

---

## 本地运行（开发）
```
npm install
npm run dev
# 打开 http://localhost:3000
```

演示登录：访问 /login，任意邮箱/密码可通过（仅演示用途，无持久化）。

---

## 生产构建与启动
```
npm run build
npm run start
# 默认端口 3000
```

常见部署方式：
- Node 进程 + 反向代理（Nginx/Caddy）
- Docker（见下文）
- Vercel（仅前端 + 静态/边缘函数；若使用 Rails 后端，请将 API 指向你的 Rails 域名）

---

## Docker 示例
Dockerfile（示例）：
```
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "run", "start"]
```
构建与运行：
```
docker build -t cicd-ui .
docker run -p 3000:3000 --env NEXT_PUBLIC_API_BASE=http://your-rails-host cicd-ui
```

---

## 路由一览
- /dashboard 项目总览
- /projects 项目与仓库（Git/SVN 配置、构建流水线）
- /deployments 部署与监控（目录浏览、进程查看）
- /control 应用控制台（nohup 启停/重启、日志）
- /users 用户与权限（演示）
- /login 演示登录

---

## Mock API（内置，支持 UI 演示）
这些路由在 Next.js 中已实现，仅用于演示与前端验证：

Projects
- GET /api/projects → 列表
- POST /api/projects → 创建
  - Body: { name, repo_type, repo_url, branch?, credentials_json?, pipeline? }
- POST /api/projects/test-connection → 测试仓库连通性
  - Body: { repo_url }

Targets
- GET /api/targets → 服务器目标列表（演示）
- GET /api/targets/[id]/fs?path=/opt/apps → 目录浏览
- GET /api/targets/[id]/processes → 进程列表

Control
- POST /api/control/start → 启动应用（返回 pid/log_path，演示）
  - Body: { target_id, workdir, jar_path, java_opts?, env? }
- POST /api/control/stop → 停止应用（演示）
  - Body: { pid }
- GET /api/control/logs?path=/var/log/app.log → 文本流日志（演示）

说明：以上全部为内存 Mock，服务重启后数据清空。

---

## 接入真实后端（Ruby on Rails + SQLite）
当你准备接入 Rails 后端，请在 Rails 中暴露相同的 REST 契约：

Projects
- GET /api/projects
- POST /api/projects
- POST /api/projects/test-connection
  - 控制器建议：使用 `git ls-remote` 或 `svn info` 验证连通性

Targets
- GET /api/targets
- GET /api/targets/:id/fs?path=...  → 返回 [{ name, type:"file"|"dir", size, mtime }]
- GET /api/targets/:id/processes     → 返回 [{ pid, name, cpu, mem, started_at }]

Control
- POST /api/control/start → 生成 nohup 命令并启动，返回 { pid, log_path }
- POST /api/control/stop  → 安全终止进程，返回 { ok: true }
- GET  /api/control/logs?path=... → 持续文本流（建议 ActionController::Live 或 Rack hijack）

前端切换步骤：
1) 部署 Rails 并实现上述接口（JSON 响应字段与示例保持一致）
2) 在前端设置环境变量：`NEXT_PUBLIC_API_BASE=https://api.yourdomain.com`
3) 确认 CORS/网关已放行前端域名
4) 验证各页面：
   - /projects 创建/测试连通性
   - /deployments 目录与进程
   - /control 启动/停止与日志流
5) 稳定后可删除本仓库中的 `src/app/api/*` Mock 路由

---

## 生产运维建议
- 身份与权限：请在 Rails 中实现用户、角色（管理员/开发者/访客）、资源（项目/流水线/部署/控制）的读/写/执行授权
- 敏感信息：仓库凭证、部署密钥等仅保存在服务端，前端不回显
- 审计与日志：记录启停、部署、配置变更
- 稳定性：nohup 进程管理、PID 持久化、异常恢复
- 安全：所有变更类接口需鉴权（POST/PUT/DELETE），并开启 CSRF/CORS 防护

---

## 常见问题
- 首次运行空白？请确认已执行 `npm install`，且 Node 版本满足要求
- 日志流没有输出？Mock 路由会定时返回演示内容；接入 Rails 后请确认服务端日志路径与权限
- 切到 Rails 后 404？确认 `NEXT_PUBLIC_API_BASE` 指向正确，且接口路径与本文档一致

---

## 许可证
未附带开源许可证。若需对外开源，请添加合适的 LICENSE 文件。