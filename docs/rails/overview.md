# 项目概览（Rails 版本）

本项目目标：提供一个更轻量的自建 CI/CD 工具，支持 Git/SVN 拉取、构建打包、SSH 部署、服务器目录与进程读取，以及通过 Web 界面基于 nohup 启停 Java 应用，具备用户/角色/策略权限管控，中文界面。

- 技术栈：Rails 7.1、Ruby 3.3、SQLite3（可切换 Postgres）、Tailwind、Devise + devise-jwt、Pundit、Net::SSH/Net::SCP、ActiveJob（GoodJob/Sidekiq 可选）
- 兼容 API：尽量与现有前端的 REST 路由保持一致，便于前端（Next.js）直连或渐进替换

核心模块
- 系统/项目管理：配置仓库（Git/SVN）、分支、构建脚本与产物路径
- 构建与产物：拉取、构建、打包，产物版本管理
- 目标服务器：SSH 可达性、凭据管理、环境标签（dev/staging/prod）
- 部署与回滚：上传产物、部署、软链切换、进程重启、历史记录和回滚
- 目录与进程：远程文件目录浏览、进程列表与端口检测
- 应用控制：基于 nohup 的 start/stop/restart、日志读取
- 权限与审计：角色（admin/maintainer/viewer）、策略与审计日志

运行形态
- 开发：SQLite + async job，快速起步
- 生产：可升级为 Postgres + GoodJob/Sidekiq，反向代理 Nginx，Puma + systemd