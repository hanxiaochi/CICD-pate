# API 设计（与现有前端对齐）

认证
- POST /api/login => { token }

系统/项目/成品包
- GET /api/systems
- GET /api/projects
- GET /api/projects/:id/packages

目标服务器
- GET /api/targets?page=&pageSize=&q=
- POST /api/targets
- PUT /api/targets/:id
- DELETE /api/targets/:id
- POST /api/targets/test-connection { id, timeoutMs }
- POST /api/targets/test-ssh（单个或批量）
- GET /api/targets/:id/fs?path=
- GET /api/targets/:id/processes

部署
- POST /api/deployments { systemId, projectId, packageId, targetId }
- GET /api/deployments/history
- POST /api/deployments/:id/rollback

应用控制（nohup）
- POST /api/control/start|stop|restart { targetId, profileId }
- GET /api/control/logs?targetId=&profileId=&lines=

通用返回格式
- { ok: boolean, data?, error?, steps?, summary?, deploymentId? }

认证与鉴权
- Header: Authorization: Bearer <JWT>
- 控制器中使用 Pundit 授权，未授权返回 403