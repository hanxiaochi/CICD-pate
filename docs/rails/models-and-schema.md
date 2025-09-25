# 数据模型与数据库设计（整型主键）

用户与权限
- users: id, email, encrypted_password, name, role(admin/maintainer/viewer), created_at

业务域
- systems: id, name, description
- projects: id, system_id, name, repo_type(git/svn), repo_url, repo_branch, build_script(text), artifact_path, created_at

目标服务器与凭据
- targets: id, name, host, ssh_user, ssh_port, root_path, env(dev/staging/prod), has_password:boolean, has_private_key:boolean
- credentials: id, target_id, auth_type(password/key), password_digest/encrypted, private_key_encrypted(text), passphrase_encrypted

构建与产物
- packages: id, project_id, name, file_path, checksum, version, created_at, created_by

部署与控制
- deployments: id, project_id, package_id, target_id, status(pending/running/success/failed/rolled_back), steps(json), logs(text), started_at, finished_at, triggered_by
- process_profiles: id, project_id, name, start_cmd, stop_cmd, workdir, port, pattern

审计
- audit_logs: id, user_id, action, resource_type, resource_id, payload(json), created_at

索引建议
- projects(system_id), packages(project_id), deployments(project_id, target_id, status)
- targets(host, env), audit_logs(user_id, created_at)