# 搭建与部署

开发环境
1. 安装 Ruby 3.3、Node 20+、Yarn、SQLite3、Git、SVN（可选）
2. bundle install && yarn install（如需要）
3. bin/rails db:setup
4. bin/dev 启动（或 rails s）

环境变量
- JWT_SECRET：JWT 签名
- RAILS_MASTER_KEY：生产环境
- ARTIFACTS_DIR（默认 storage/artifacts）
- BUILD_WORK_DIR（默认 tmp/builds）

生产部署
- Puma + systemd，Nginx 反代
- 数据库可选升级为 Postgres
- ActiveJob 使用 GoodJob/Sidekiq
- 权限：storage 与 tmp 可写

备份
- SQLite 文件/数据库备份
- storage/artifacts 产物与日志