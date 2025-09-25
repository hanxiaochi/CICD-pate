# 权限设计（Pundit）

角色
- admin：全部资源
- maintainer：创建构建、部署、回滚，编辑项目/目标
- viewer：只读

策略
- ProjectPolicy：index/show（viewer 以上），create/update/delete（maintainer 以上）
- TargetPolicy：同上；测试连接仅 maintainer 以上
- DeploymentPolicy：create/rollback 需 maintainer 以上；history viewer 可见
- ControlPolicy：start/stop/restart 需 maintainer 以上

审计（AuditLog）
- 记录 action、resource、user_id、payload（关键参数）、时间
- 对构建/部署/回滚/控制等高危操作全部落审计