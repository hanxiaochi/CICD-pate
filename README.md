# 轻量化 CI/CD 与远程应用控制平台

本项目是基于 Next.js 15（React 19）的全栈应用，提供从项目管理、构建发布、到远程服务器上的应用启动/停止/重启与日志查看的一体化能力。

- 技术栈：Next.js 15 (App Router) + TypeScript + Tailwind CSS + shadcn/ui
- 后端路由：使用 Next.js 内置 API（app/api/*）
- 远程控制：通过 SSH 在目标机执行 nohup/shell 脚本并读取日志流
- 说明文档：完整 SSME 软件规格文档见 docs/SSME.md

> 注意：本仓库包含演示用的 Rails 样例目录（backend/rails），但实际运行环境为 Next.js。请以本文档为准。

## 环境要求
- Node.js >= 20（建议 20.x 或 22.x LTS）
- npm >= 10（项目使用 npm 脚本）
- 可选：Docker（用于容器化部署）

## 快速开始（本地开发）
1. 安装依赖
   ```bash
   npm install
   ```
2. 启动开发服务
   ```bash
   npm run dev
   # 默认 http://localhost:3000
   ```
3. 构建与生产启动
   ```bash
   npm run build
   npm start
   ```

## 常用脚本
- `npm run dev`：本地开发（Turbopack）
- `npm run build`：构建生产产物
- `npm start`：启动构建后的服务
- `npm run lint`：代码检查

## 目录结构（节选）
```
root
├─ src/
│  ├─ app/                 # App Router 与页面
│  │  ├─ api/              # 内置 API 路由（控制/部署/目标机等）
│  │  ├─ control/          # 应用控制台（/control）
│  │  ├─ deployments/      # 发布历史与详情
│  │  ├─ projects/         # 项目/仓库配置
│  │  └─ login, users      # 登录与用户
│  ├─ components/          # 复用组件（含 shadcn/ui）
│  ├─ db/                  # 数据层（Drizzle 预置）
│  ├─ lib/, hooks/         # 工具与 hooks
├─ docs/                   # 文档（含 SSME）
├─ deploy/                 # 部署样例（systemd 等）
└─ backend/rails           # 对照用 Rails 样例（非运行依赖）
```

## 功能概览
- 项目与目标机管理：配置仓库、分配目标机、连通性测试
- 发布管理：发布历史/详情、回滚（/app/api/deployments/*）
- 应用控制：
  - 启动（nohup/java 或 shell 脚本）
  - 停止（PID 或 stop.sh）
  - 重启（停-启串行）
  - 实时日志流（ReadableStream）
- UI 页面：/control 提供参数表单、状态反馈、实时日志查看

接口约定（节选）：
- POST `/api/control/start`
  - nohup: `{ mode: "nohup", target_id, workdir, jar_path, java_opts, env }`
  - sh: `{ mode: "sh", target_id, workdir, start_script, log_file, env }`
- POST `/api/control/stop`
  - nohup: `{ mode: "nohup", pid }`
  - sh: `{ mode: "sh", workdir, stop_script, pid? }`
- GET `/api/control/logs?path=<log_file>`

## 环境变量
- 默认本地开发无需额外环境变量。
- 若集成外部服务（如数据库、支付、第三方 API），请在 .env 中按需要添加对应变量。
- API 鉴权：前端请求通过封装的 withAuth 读取本地存储的 Bearer Token 并附加到请求头（如有登录流程时）。

## 开发注意事项
- 仅使用 Tailwind CSS 进行样式编写（禁用 styled-jsx）。
- 页面保持为 Server Components；交互放入 Client Components（文件首行 `"use client"`）。
- 客户端组件不要调用服务端专用 API（cookies/headers/redirect/notFound）。
- UI 中不要使用浏览器原生 alert/confirm/prompt，改用 shadcn/ui 的对话框与 sonner 通知。

## 代码行数统计
- 估算当前代码规模：约 7,000 – 10,000 行（不含依赖）。
- 可复现统计命令：
  - Bash（macOS/Linux）
    ```bash
    find src backend docs deploy -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.md" -o -name "*.mjs" -o -name "*.json" -o -name "*.sh" -o -name "*.yml" -o -name "*.yaml" \) \
      -not -path "**/node_modules/**" -not -path "**/.next/**" \
      -exec wc -l {} + | tail -n 1
    ```
  - PowerShell（Windows）
    ```powershell
    Get-ChildItem src,backend,docs,deploy -Recurse -Include *.ts,*.tsx,*.md,*.mjs,*.json,*.sh,*.yml,*.yaml | \
      Where-Object { $_.FullName -notmatch "node_modules|\.next" } | \
      Get-Content | Measure-Object -Line
    ```

## 部署建议（可选）
- 以 Node 20+ 的环境运行 `npm run build && npm start`。
- 若需常驻进程与重启，可结合 systemd/pm2；样例见 deploy/ 目录。
- 容器化：可基于根目录 Dockerfile 自行构建镜像并运行。

## 文档与规范
- 完整软件规格与维护说明（SSME）：`docs/SSME.md`
- 代码风格：ESLint + TypeScript；UI 组件遵循 shadcn/ui 约定
- 可访问性与主题：内置深/浅色，使用 Tailwind 设计令牌

---
如需对接真实数据库、完善权限与审计、或新增功能，请参考 docs/SSME.md 的"维护与变更建议"。