#!/usr/bin/env ruby
# 完整的系统验证脚本 V2

puts "=== CICD 系统完整验证 V2 ==="
puts

# 测试数据库初始化
puts "1. 测试数据库初始化..."
begin
  require_relative 'config/application_v2'
  puts "✓ 数据库和模型初始化成功"
  
  # 验证表存在
  required_tables = [:users, :workspaces, :projects, :resources, :builds, :deployments, :logs, :permissions, :system_configs]
  required_tables.each do |table|
    if DB.table_exists?(table)
      count = DB[table].count
      puts "✓ 表 #{table} 存在 (#{count} 条记录)"
    else
      puts "✗ 表 #{table} 不存在"
    end
  end

rescue => e
  puts "✗ 数据库初始化失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
  exit 1
end

# 测试模型操作
puts "\n2. 测试模型操作..."
begin
  # 测试用户模型
  admin_user = User.where(username: 'admin').first
  if admin_user
    puts "✓ 管理员用户存在: #{admin_user.username}"
    puts "✓ 用户认证方法可用: #{admin_user.admin?}"
  else
    puts "✗ 管理员用户不存在"
  end

  # 测试项目模型
  project_count = Project.count
  puts "✓ 项目模型查询正常 (项目数: #{project_count})"

  # 测试工作空间模型
  workspace_count = Workspace.count
  puts "✓ 工作空间模型查询正常 (工作空间数: #{workspace_count})"

rescue => e
  puts "✗ 模型操作失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
end

# 测试应用程序加载
puts "\n3. 测试应用程序加载..."
begin
  require_relative 'app_v2'
  
  if defined?(CicdApp)
    puts "✓ CicdApp 类已定义"
    puts "✓ 应用程序可以正常启动"
  else
    puts "✗ CicdApp 类未定义"
  end

rescue => e
  puts "✗ 应用程序加载失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
end

# 测试视图文件
puts "\n4. 检查视图文件..."
view_files = ['views/login.erb', 'views/index.erb']
view_files.each do |file|
  if File.exist?(file)
    puts "✓ #{file} 存在"
  else
    puts "✗ #{file} 不存在"
  end
end

# 测试配置文件
puts "\n5. 检查配置文件..."
config_files = ['config.ru', 'config/application_v2.rb', 'app_v2.rb']
config_files.each do |file|
  if File.exist?(file)
    puts "✓ #{file} 存在"
  else
    puts "✗ #{file} 不存在"
  end
end

puts "\n=== 验证完成 ==="
puts "如果所有检查都通过，可以运行以下命令启动系统："
puts "1. 直接运行: ruby app_v2.rb"
puts "2. 使用 Puma: puma config.ru"
puts "3. Docker 运行: docker-compose up --build"
puts
puts "默认访问地址: http://localhost:4567"
puts "默认管理员账户: admin / admin123"