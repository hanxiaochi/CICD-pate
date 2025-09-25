# 系统架构

分层结构
- Web 层（Rails MVC + REST API）
  - 页面：系统/项目/成品包/目标服务器/部署/历史/进程/目录/权限管理
  - API：供前端 AJAX 与三方系统调用
- 服务层（app/services）
  - RepoService（Git/SVN）、BuildService、ArtifactService
  - SSHService、DeployService、RollbackService
  - ProcessService、AppControlService（nohup）
- 任务层（ActiveJob）
  - BuildJob、DeployJob、RollbackJob、ProcessScanJob、FsScanJob
- 安全层
  - Devise + devise-jwt（认证）、Pundit（授权）、审计日志

目录建议
- app/models, app/controllers, app/policies, app/services, app/jobs
- config/locales/zh-CN.yml（中文），config/initializers/*（JWT/SSH 配置）
- storage/artifacts（产物），tmp/builds（构建工作区）

数据流（部署示例）
1. 前端发起 POST /api/deployments，参数包含 projectId、packageId、targetId
2. 控制器授权后入队 DeployJob
3. DeployService 预检 SSH，上传产物至 root_path/<project>/<version>
4. 执行部署脚本：解压/软链 current/重启进程
5. 记录 steps/logs/status 并写入审计