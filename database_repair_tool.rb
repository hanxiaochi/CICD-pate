#!/usr/bin/env ruby
# 数据库修复工具 - 系统化解决数据库初始化问题

puts "=== CICD 数据库修复工具 ==="
puts "用于修复Docker启动时的数据库表缺失问题"
puts

# 强制加载必要的依赖
require 'sequel'
require 'bcrypt'

begin
  puts "1. 初始化数据库连接..."
  
  # 创建或连接数据库
  database = Sequel.sqlite('cicd.db')
  Object.const_set('DB', database) unless defined?(DB)
  Sequel::Model.db = database
  
  database.test_connection
  puts "✓ 数据库连接成功"

rescue => e
  puts "✗ 数据库连接失败: #{e.message}"
  exit 1
end

begin
  puts "2. 检查数据库表状态..."
  
  required_tables = [
    :users, :workspaces, :projects, :resources, :docker_resources,
    :services, :nodes, :builds, :deployments, :scripts, 
    :script_executions, :logs, :permissions, :system_configs
  ]
  
  missing_tables = []
  existing_tables = []
  
  required_tables.each do |table|
    if DB.table_exists?(table)
      count = DB[table].count
      existing_tables << "#{table} (#{count} 记录)"
    else
      missing_tables << table
    end
  end
  
  puts "✓ 已存在的表: #{existing_tables.join(', ')}" if existing_tables.any?
  puts "✗ 缺失的表: #{missing_tables.join(', ')}" if missing_tables.any?
  
rescue => e
  puts "✗ 表状态检查失败: #{e.message}"
end

if missing_tables&.any? || existing_tables.empty?
  begin
    puts "3. 重新创建数据库表..."
    
    # 手动加载数据库初始化器
    require_relative 'lib/utils/database_initializer'
    
    # 创建所有表
    DatabaseInitializer.create_tables
    
    puts "✓ 数据库表创建完成"
    
    # 验证创建结果
    puts "4. 验证表创建结果..."
    required_tables.each do |table|
      if DB.table_exists?(table)
        count = DB[table].count
        puts "✓ #{table} - 创建成功 (#{count} 记录)"
      else
        puts "✗ #{table} - 创建失败"
      end
    end
    
  rescue => e
    puts "✗ 数据库表创建失败: #{e.message}"
    puts "错误详情: #{e.backtrace.first(3).join('\n')}"
    exit 1
  end
else
  puts "✓ 所有必要的数据库表都已存在"
end

begin
  puts "5. 验证默认数据..."
  
  # 检查默认管理员
  admin_user = DB[:users].where(username: 'admin').first
  if admin_user
    puts "✓ 默认管理员账户存在"
  else
    puts "✗ 默认管理员账户不存在"
  end
  
  # 检查默认工作空间
  default_workspace = DB[:workspaces].where(name: 'default').first
  if default_workspace
    puts "✓ 默认工作空间存在"
  else
    puts "✗ 默认工作空间不存在"
  end
  
  # 检查系统配置
  config_count = DB[:system_configs].count
  if config_count > 0
    puts "✓ 系统配置已初始化 (#{config_count} 项配置)"
  else
    puts "✗ 系统配置未初始化"
  end
  
rescue => e
  puts "✗ 默认数据验证失败: #{e.message}"
end

puts
puts "=== 数据库修复完成 ==="
puts "现在可以重新启动Docker容器：docker-compose up --build"
puts "或者运行验证脚本：ruby final_check.rb"