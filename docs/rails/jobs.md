# 任务队列（ActiveJob）

- BuildJob: 执行 RepoService + BuildService，产出 packages 记录
- DeployJob: 调用 DeployService，更新 deployments 状态
- RollbackJob: 调用 RollbackService，更新状态
- FsScanJob: 远程目录扫描，缓存或直接透传
- ProcessScanJob: 远程进程扫描

适配器
- 开发默认 async
- 生产建议 GoodJob（Postgres）或 Sidekiq（Redis）

重试与幂等
- 使用 job_id 作为幂等键记录，避免重复执行
- 失败重试次数与退避可配置