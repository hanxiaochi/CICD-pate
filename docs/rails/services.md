# 服务层设计

SSHService
- connect(target, credentials) -> Net::SSH session
- exec(cmd, timeout:) -> stdout, stderr, exit_status
- upload(local_path, remote_path) via Net::SCP

RepoService
- Git: clone/pull 指定 branch
- SVN: checkout/update

BuildService
- 在 tmp/builds/<project>/<timestamp> 中执行 build_script（bash）
- 将产物移动至 storage/artifacts/<project>/<version>
- 计算 checksum，写入 packages

ArtifactService
- 命名规则、校验、保留策略（可配置）

DeployService
- 预检 SSH -> 上传产物 -> 解压/软链 current -> 重启进程（可调用 AppControlService）
- 记录 steps/logs/status

RollbackService
- 查找上一次成功版本 -> 切换软链 -> 重启 -> 记录

ProcessService
- 远程解析 ps/ss/lsof，提取 pid/cmd/port/started

AppControlService（nohup）
- start: cd workdir && nohup <start_cmd> > nohup.out 2>&1 &
- stop: 基于 pattern/port 查 PID，优雅退出 -> 超时强杀
- restart: stop -> start
- logs: tail -n N nohup.out