#!/usr/bin/env ruby

# CICD系统 - 完整功能Docker启动脚本
# 包含工作空间、项目管理、资产管理等完整CICD功能
# =============================================

require 'rubygems'
require 'bundler/setup'

puts "🚀 启动完整版CICD系统..."
puts "包含工作空间、项目管理、资产管理等完整功能"
puts "========================================"

# 设置环境变量
ENV['RACK_ENV'] ||= 'production'
ENV['DATABASE_URL'] ||= 'sqlite:///app/cicd.db'

# 检查必要的gem依赖
required_gems = %w[sinatra sequel sqlite3 haml sass json bcrypt sinatra-flash]
missing_gems = []

required_gems.each do |gem_name|
  begin
    require gem_name.gsub('-', '/')
  rescue LoadError
    missing_gems << gem_name
  end
end

if missing_gems.any?
  puts "❌ 缺少必要的gem依赖: #{missing_gems.join(', ')}"
  puts "正在安装..."
  
  missing_gems.each do |gem_name|
    puts "安装 #{gem_name}..."
    system("gem install #{gem_name} --no-document")
  end
end

# 强制数据库初始化
始非跨界字符 = false
begin
  puts "🗄️  强制初始化数据库..."
  
  # 删除现有数据库文件（如果存在）
  if File.exist?('/app/cicd.db')
    File.delete('/app/cicd.db')
    puts "⚙️  已删除旧数据库文件"
  end
  
  # 要求必要的gem
  require 'sequel'
  require 'sqlite3'
  require 'bcrypt'
  
  # 创建数据库连接
  DB = Sequel.connect('sqlite:///app/cicd.db')
  
  puts "⚙️  创建数据库表..."
  
  # 创建 users 表
  DB.create_table :users do
    primary_key :id
    String :username, null: false, unique: true
    String :password_hash, null: false
    String :role, default: 'user'
    String :email
    Boolean :active, default: true
    Time :last_login
    Time :created_at, default: Time.now
    Time :updated_at, default: Time.now
  end
  
  # 创建 workspaces 表
  DB.create_table :workspaces do
    primary_key :id
    String :name, null: false
    String :description
    Integer :owner_id
    Time :created_at, default: Time.now
    Time :updated_at, default: Time.now
  end
  
  # 创建 projects 表
  DB.create_table :projects do
    primary_key :id
    String :name, null: false
    String :repo_url
    String :branch, default: 'master'
    Integer :user_id
    Integer :workspace_id
    Time :created_at, default: Time.now
    Time :updated_at, default: Time.now
  end
  
  # 创建 builds 表
  DB.create_table :builds do
    primary_key :id
    Integer :project_id
    String :status, default: 'pending'
    String :commit_hash
    Text :log_output
    Time :started_at
    Time :finished_at
    Time :created_at, default: Time.now
  end
  
  # 创建 resources 表
  DB.create_table :resources do
    primary_key :id
    String :name, null: false
    String :type, null: false
    String :status, default: 'offline'
    String :host
    Integer :port
    Text :config
    Time :created_at, default: Time.now
    Time :updated_at, default: Time.now
  end
  
  # 创建 logs 表
  DB.create_table :logs do
    primary_key :id
    String :level, default: 'info'
    String :message
    Integer :user_id
    String :ip_address
    Time :created_at, default: Time.now
  end
  
  # 创建管理员用户
  DB[:users].insert(
    username: 'admin',
    password_hash: BCrypt::Password.create('admin123'),
    role: 'admin',
    email: 'admin@cicd.local',
    created_at: Time.now,
    updated_at: Time.now
  )
  
  # 创建默认工作空间
  workspace_id = DB[:workspaces].insert(
    name: '默认工作空间',
    description: '系统默认的工作空间',
    owner_id: 1,
    created_at: Time.now,
    updated_at: Time.now
  )
  
  # 创建示例项目
  DB[:projects].insert(
    name: '示例项目',
    repo_url: 'https://github.com/example/demo.git',
    branch: 'main',
    user_id: 1,
    workspace_id: workspace_id,
    created_at: Time.now,
    updated_at: Time.now
  )
  
  puts "✅ 数据库初始化完成！"
  puts "✅ 已创建管理员账户: admin / admin123"
  puts "✅ 已创建默认工作空间和示例项目"
  
rescue => e
  puts "❌ 数据库初始化失败: #{e.message}"
  puts "详细错误: #{e.backtrace.first(3).join('\n')}"
end

puts "✅ 环境检查完成，启动完整版CICD系统..."

# 加载完整版应用
begin
  require_relative 'app_refactored'
  
  puts "🎯 CICD系统启动成功！"
  puts "================================="
  puts "访问地址: http://localhost:4567"
  puts "默认账户: admin / admin123"
  puts ""
  puts "功能包括:"
  puts "📂 工作空间管理 - /workspaces"
  puts "📁 项目管理 - /projects"  
  puts "💻 资产管理 - /assets"
  puts "👥 用户管理 - /users"
  puts "📊 系统监控 - /monitor"
  puts "🔧 API接口 - /api/*"
  puts ""
  puts "开始您的CICD工作流程！"
  puts "================================="
  
  # 启动应用
  CicdApp.run!
  
rescue LoadError => e
  puts "❌ 加载完整版应用失败: #{e.message}"
  puts "尝试修复依赖..."
  
  # 如果完整版加载失败，使用简化版作为备用
  puts "⚠️  切换到简化版启动..."
  require_relative 'start_docker'
  
rescue => e
  puts "❌ 启动失败: #{e.message}"
  puts "详细错误: #{e.backtrace.first(5).join('\n')}"
  exit 1
end