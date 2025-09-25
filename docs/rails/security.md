# 安全要点

- 凭据加密存储（Lockbox/AttrEncrypted 或 Rails credentials）
- 严禁在页面回显密码/私钥；仅暴露 has_password/has_private_key 标记
- 远程命令白名单与模板化（避免任意命令注入）
- SSH known_hosts 校验建议开启（测试环境谨慎关闭）
- JWT 签名密钥 JWT_SECRET；生产使用 RAILS_MASTER_KEY
- 审计日志覆盖高危操作，保留期与脱敏策略