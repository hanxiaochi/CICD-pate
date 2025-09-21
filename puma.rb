# Puma配置文件

# 获取当前工作目录
app_root = Dir.pwd

# 配置Rack应用文件
rackup File.join(app_root, "config.ru")

# 设置最小和最大线程数
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# 指定Puma使用的端口
port ENV.fetch("PORT") { 4567 }

# 指定环境
environment ENV.fetch("RACK_ENV") { "development" }

# 工作目录设置为当前目录
directory app_root

# 指定PID文件位置（使用绝对路径）
pidfile File.join(app_root, "tmp", "puma.pid")

# 指定状态文件位置
state_path File.join(app_root, "tmp", "puma.state")

# 指定日志文件
stdout_redirect File.join(app_root, "logs", "puma.log"), File.join(app_root, "logs", "puma_error.log"), true

# 根据环境配置worker模式
if ENV["RACK_ENV"] == "production"
  # 生产环境：启用集群模式
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  
  # 在fork worker进程之前运行的代码
  preload_app!
  
  # 允许puma在重启时不丢失连接
  plugin :tmp_restart
  
  # 在生产环境中后台运行
  daemonize true
  
  # 在worker boot时执行的代码（仅集群模式）
  on_worker_boot do
    # Worker特定的初始化代码
    puts "Worker #{Process.pid} booted"
  end

  # 在worker shutdown时执行的代码（仅集群模式）
  on_worker_shutdown do
    # 清理工作
    puts "Worker #{Process.pid} shutting down"
  end
else
  # 开发环境：单进程模式
  workers 0  # 禁用worker模式
end

# 绑定到Unix socket (可选)
# bind "unix://#{app_root}/tmp/puma.sock"

# 设置最大payload大小 (默认是无限制)
# max_request_size 16777216

# SSL配置 (如果需要HTTPS)
# ssl_bind "0.0.0.0", "8443", {
#   key: "path/to/server.key",
#   cert: "path/to/server.crt"
# }

# 优雅关闭的超时时间
worker_timeout 30

# 在重启时执行的代码
on_restart do
  puts "Puma is restarting..."
end

# 在启动时执行的代码
on_booted do
  puts "Puma is booted and ready to serve requests at #{ENV.fetch('PORT') { 4567 }}"
  puts "Environment: #{ENV.fetch('RACK_ENV') { 'development' }}"
  puts "Working directory: #{app_root}"
end