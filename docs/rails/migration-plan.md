# 迁移方案（从现有 Next.js 原型）

目标：Rails 后端逐步接管 API，前端保持 UI，不中断现有使用。

阶段 1：基础资源
- 实现 /api/targets, /api/targets/test-ssh, /api/targets/:id/fs, /api/targets/:id/processes
- 验证与当前前端页面（/deployments）联通

阶段 2：项目与产物
- 实现 /api/systems, /api/projects, /api/projects/:id/packages
- 构建流水线与 packages 记录

阶段 3：部署与回滚
- 实现 /api/deployments, /api/deployments/history, /api/deployments/:id/rollback
- 引入 DeployJob/RollbackJob

阶段 4：应用控制与审计
- /api/control/* 与审计日志覆盖
- 权限细化与策略完善

切换策略
- 接口幂等与可回退
- 日志对齐与监控