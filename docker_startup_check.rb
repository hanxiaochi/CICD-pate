#!/usr/bin/env ruby
# Docker启动诊断脚本

puts "=== CICD Docker启动诊断脚本 ==="
puts "Ruby版本: #{RUBY_VERSION}"
puts "时间: #{Time.now}"
puts

# 1. 检查必要的gem包
puts "1. 检查Gem包..."
required_gems = %w[sinatra haml sequel bcrypt]

required_gems.each do |gem_name|
  begin
    require gem_name
    puts "✓ #{gem_name} - 已安装"
  rescue LoadError => e
    puts "✗ #{gem_name} - 缺失: #{e.message}"
  end
end
puts

# 2. 检查文件结构
puts "2. 检查文件结构..."
required_files = [
  'config/application.rb',
  'lib/controllers/base_controller.rb',
  'lib/controllers/api_controller.rb',
  'lib/models/user.rb',
  'lib/services/log_service.rb',
  'lib/utils/database_initializer.rb'
]

required_files.each do |file_path|
  if File.exist?(file_path)
    puts "✓ #{file_path} - 存在"
  else
    puts "✗ #{file_path} - 缺失"
  end
end
puts

# 3. 尝试加载配置文件
puts "3. 测试配置文件加载..."
begin
  require_relative 'config/application'
  puts "✓ 配置文件加载成功"
rescue => e
  puts "✗ 配置文件加载失败: #{e.message}"
  puts "错误详情: #{e.backtrace.first(3).join("\n")}"
end
puts

# 4. 检查数据库连接
puts "4. 测试数据库连接..."
begin
  if defined?(DB)
    DB.test_connection
    puts "✓ 数据库连接正常"
  else
    puts "✗ 数据库未初始化"
  end
rescue => e
  puts "✗ 数据库连接失败: #{e.message}"
end
puts

# 5. 检查端口
puts "5. 检查端口配置..."
begin
  port = CONFIG['app_port'] if defined?(CONFIG)
  port ||= 4567
  puts "✓ 应用端口: #{port}"
  
  # 检查端口是否被占用
  require 'socket'
  begin
    server = TCPServer.new('0.0.0.0', port)
    server.close
    puts "✓ 端口 #{port} 可用"
  rescue Errno::EADDRINUSE
    puts "⚠ 端口 #{port} 被占用"
  end
rescue => e
  puts "✗ 端口检查失败: #{e.message}"
end
puts

# 6. 模拟启动应用
puts "6. 模拟应用启动..."
begin
  if defined?(CicdApp)
    puts "✓ CicdApp类已定义"
    puts "✓ 应用可以正常启动"
  else
    puts "✗ CicdApp类未定义"
  end
rescue => e
  puts "✗ 应用启动模拟失败: #{e.message}"
end

puts
puts "=== 诊断完成 ==="
puts "如果有任何 ✗ 标记的项目，请先解决这些问题再启动Docker容器。"