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

# 确保数据库目录存在
db_dir = File.dirname('/app/cicd.db')
Dir.mkdir(db_dir) unless Dir.exist?(db_dir)

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