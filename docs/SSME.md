# SSME（软件规格与维护说明）

> 文档目的：面向干系人（产品/研发/测试/运维），完整描述本系统的开发语言与框架、系统组成、设计、功能规格、开发与测试情况、使用方法，以及代码规模统计与复现方式。

## 1. 基本信息
- 项目名称：轻量化 CI/CD 与远程应用控制平台
- 主要语言：TypeScript（前端/服务端同构，Next.js App Router）
- 前端框架：Next.js 15（React 19）+ Tailwind CSS + shadcn/ui
- 运行环境：Node.js ≥ 20
- 构建与打包：Next build / Next start
- UI 组件：shadcn/ui（Radix primitives）
- 其它：Drizzle ORM（已准备）、SSH2（远程执行/文件）、Sonner（通知）

辅助目录（非前端运行时必须）：
- backend/rails：用于对照的 Rails 方案样例（非运行态依赖）
- docs/：文档与设计资料
- deploy/：系统服务/部署样例

## 2. 项目结构与组成
```
root
├─ src/                    # Next.js 15 应用（App Router）
│  ├─ app/                 # 路由与页面（大多为 Server Components）
│  │  ├─ api/              # Next.js 内置 API 路由（控制/部署/目标机等）
│  │  ├─ control/          # 应用控制台（/control）
│  │  ├─ deployments/      # 发布历史与详情
│  │  ├─ projects/         # 项目/仓库配置
│  │  ├─ users/, login/    # 用户与登录
│  ├─ components/          # UI 组件与复用模块（含 shadcn/ui）
│  ├─ db/                  # 数据层（Drizzle，已准备）
│  ├─ lib/                 # 通用工具（鉴权请求封装等）
│  └─ hooks/               # React hooks
├─ public/                 # 静态资源
├─ docs/                   # 文档
├─ deploy/                 # 部署样例（systemd 等）
└─ ...
```

## 3. 设计与架构
- 前后端一体：使用 Next.js App Router，将页面（Server Components）与 API route 放在同一代码树下。
- 远程控制：通过 `/api/control/*` 路由封装 SSH 操作（启动/停止/日志流读取等）。
- 安全：API 请求统一通过 `withAuth` 封装追加鉴权（Bearer Token），错误明确反馈。
- UI/UX：Tailwind CSS 与 shadcn/ui，保留响应式与深浅色主题能力。
- 数据：已具备 Drizzle ORM 与表结构准备，后续可平滑切换真实数据库存储。

### 3.1 简化逻辑架构图（ASCII）
```
[Browser UI]
   |  (Button/Forms: Start/Stop/Restart/Logs, Deployments, Projects)
   v
[Next.js App Router]
   ├─ app/(pages)
   └─ app/api/*  <-- JSON API
         ├─ /control/start      (POST)
         ├─ /control/stop       (POST)
         ├─ /control/logs       (GET stream)
         ├─ /deployments/*      (CRUD/回滚)
         └─ /targets/*          (进程/目录/SSH 测试)
   |
   v
[SSH/OS Commands]
   └─ 目标主机（启动脚本、JAR、nohup、日志文件）
```

## 4. 功能规格（当前版本）
- 项目/仓库：配置项目、测试连接、分配目标机（API 已具备）。
- 部署管理：发布历史、发布详情、回滚接口（API 已具备；UI 已新增详情页入口与交互）。
- 目标机：SSH 连接测试、进程/目录读取（API 已具备）。
- 应用控制：
  - 启动：支持两种模式
    - nohup 模式：`java -jar` 启动，支持 `JAVA_OPTS`、`--server.port`、日志重定向
    - shell 模式：调用 `start.sh`，并可指定 `workdir`与 `log_file`
  - 停止：
    - nohup 模式：通过 PID 终止
    - shell 模式：调用 `stop.sh`
  - 日志：通过 `/api/control/logs` 以流式（ReadableStream）推送到前端实时展示
  - UI：`/control` 页面提供启动参数表单、状态反馈、实时日志查看（自动滚动、清空、停止）

接口调用约定（节选）：
- POST /api/control/start
  - nohup: `{ mode: "nohup", target_id, workdir, jar_path, java_opts, env }`
  - sh: `{ mode: "sh", target_id, workdir, start_script, log_file, env }`
- POST /api/control/stop
  - nohup: `{ mode: "nohup", pid }`
  - sh: `{ mode: "sh", workdir, stop_script, pid? }`
- GET /api/control/logs?path=<log_file>

## 5. 开发情况与进度
- 已完成
  - 控制类 API：start/stop/logs
  - 目标机 API：目录/进程、SSH 测试
  - 部署 API：创建、历史、回滚
  - UI：控制台 `/control`、发布历史“详情”入口、发布详情页交互（start/stop/restart/logs/回滚）
- 进行中 / 可选
  - 更细致的权限管理与审计
  - 部署流水线可视化与可配置
  - 数据库存储全面接入与鉴权集成

## 6. 测试结果（当前迭代）
- API 联调：
  - /api/control/start：传入 nohup 与 sh 两种模式参数，返回 PID 与日志文件路径（OK）
  - /api/control/stop：基于 PID（nohup）或 stop.sh（sh）停止（OK）
  - /api/control/logs：可稳定建立 ReadableStream，实时追加日志（OK）
- UI 交互：
  - 启动/停止/重启按钮：具备加载态、错误提示；重启为“停-启”串行（OK）
  - 实时日志：支持开始/停止、自动滚动、清空（OK）
  - 详情页：支持回滚触发、状态展示（OK）

注：受限于目标机实际环境差异（JDK、目录权限、脚本兼容性），建议联调前确保路径与权限已配置正确。

## 7. 使用方法（操作手册）
1) 开发运行
- Node.js ≥ 20
- 安装依赖：`npm install`
- 启动开发：`npm run dev`（默认 http://localhost:3000）

2) 生产构建
- 构建：`npm run build`
- 启动：`npm start`

3) 应用控制台（/control）
- 启动方式：选择 `Java JAR (nohup)` 或 `Shell 脚本`
- 填写：工作目录、JAR 路径（或 start.sh）、日志文件、JVM 参数、环境变量（每行 KEY=VALUE）
- 点击启动/停止/重启；右侧查看实时日志

4) 发布与回滚
- 在“发布历史”页点击“详情”进入详情页
- 详情页可触发回滚与查看控制操作与日志

## 8. 代码规模与统计
- 近似代码总行数（含 `src/` 与 API、UI、hooks、lib 等；不含依赖）：约 7,000 – 10,000 行
- 精确统计（推荐在项目根目录执行）：
  - Bash（类 Unix）：
    ```bash
    find src backend docs deploy -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.md" -o -name "*.mjs" -o -name "*.json" -o -name "*.sh" -o -name "*.yml" -o -name "*.yaml" \) \
      -not -path "**/node_modules/**" -not -path "**/.next/**" \
      -exec wc -l {} + | tail -n 1
    ```
  - PowerShell（Windows）：
    ```powershell
    Get-ChildItem src,backend,docs,deploy -Recurse -Include *.ts,*.tsx,*.md,*.mjs,*.json,*.sh,*.yml,*.yaml | \
      Where-Object { $_.FullName -notmatch "node_modules|\\.next" } | \
      Get-Content | Measure-Object -Line
    ```

说明：上述近似值基于当前提交文件规模估算，建议使用脚本获取精确行数。

## 9. 约束与非功能需求
- 禁用 styled-jsx；仅使用 Tailwind CSS、CSS Modules 或内联类名
- 客户端组件不调用服务端专用 API（如 cookies/headers/redirect/notFound）
- API 调用统一通过 `withAuth` 添加鉴权头；Bearer Token 存于 localStorage
- 浏览器内禁用 alert/confirm/prompt；统一使用 UI 组件 Dialog/Toast
- 保持深浅色主题一致性与可访问性

## 10. 维护与变更建议
- 新增页面：保持 Server Component，交互封装在 Client Component
- 新增 API：在 app/api 下实现，并补充 UI 的加载/错误态
- 与数据库集成：优先通过 Drizzle 与既有模式（由数据库代理工具统一管理迁移/Seeder）

---
版本：v0.1（生成于当前代码基）