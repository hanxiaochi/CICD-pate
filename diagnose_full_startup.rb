#!/usr/bin/env ruby

# CICD系统 - 完整版启动问题诊断脚本
# 专门诊断app_refactored.rb启动时的依赖和数据库问题
# ===============================================

puts "🔍 CICD完整版启动问题诊断"
puts "========================="

require 'rubygems'
require 'bundler/setup'

# 检查必要的gem依赖
puts "\n📦 检查Gem依赖..."
required_gems = {
  'sinatra' => 'Sinatra web框架',
  'sequel' => 'Sequel ORM',
  'sqlite3' => 'SQLite3数据库',
  'haml' => 'HAML模板引擎',
  'sass' => 'Sass样式表',
  'json' => 'JSON处理',
  'bcrypt' => '密码加密',
  'sinatra/flash' => 'Flash消息'
}

missing_gems = []
required_gems.each do |gem_name, description|
  begin
    gem_require_name = gem_name.gsub('-', '/')
    require gem_require_name
    puts "✅ #{gem_name} - #{description}"
  rescue LoadError
    puts "❌ #{gem_name} - #{description} (缺失)"
    missing_gems << gem_name
  end
end

if missing_gems.any?
  puts "\n⚠️  需要安装的gem: #{missing_gems.join(', ')}"
  puts "执行: gem install #{missing_gems.join(' ')}"
else
  puts "\n✅ 所有必要的gem依赖都已满足"
end

# 检查项目文件结构
puts "\n📁 检查项目文件结构..."
required_files = {
  'app_refactored.rb' => '完整版主应用文件',
  'config/application.rb' => '应用配置文件',
  'lib/utils/database_initializer.rb' => '数据库初始化器',
  'lib/models/base_model.rb' => '基础模型',
  'lib/controllers/base_controller.rb' => '基础控制器',
  'lib/services/permission_service.rb' => '权限服务',
  'lib/services/log_service.rb' => '日志服务'
}

missing_files = []
required_files.each do |file_path, description|
  if File.exist?(file_path)
    puts "✅ #{file_path} - #{description}"
  else
    puts "❌ #{file_path} - #{description} (缺失)"
    missing_files << file_path
  end
end

# 检查数据库相关文件
puts "\n🗄️  检查数据库状态..."
db_path = '/app/cicd.db'
if File.exist?(db_path)
  puts "✅ 数据库文件存在: #{db_path}"
  file_size = File.size(db_path)
  puts "   文件大小: #{file_size} 字节"
  
  # 尝试连接数据库并检查表结构
  begin
    require 'sequel'
    db = Sequel.connect("sqlite://#{db_path}")
    
    puts "   数据库连接: ✅"
    
    # 检查表是否存在
    tables = db.tables
    puts "   现有表: #{tables.join(', ')}"
    
    required_tables = [:users, :projects, :workspaces, :builds, :resources]
    missing_tables = required_tables - tables
    
    if missing_tables.empty?
      puts "   ✅ 所有必要的表都存在"
      
      # 检查users表结构
      if tables.include?(:users)
        users_schema = db.schema(:users)
        puts "   users表结构: #{users_schema.map { |col| col[0] }.join(', ')}"
      end
    else
      puts "   ❌ 缺失的表: #{missing_tables.join(', ')}"
    end
    
    db.disconnect
  rescue => e
    puts "   ❌ 数据库连接失败: #{e.message}"
  end
else
  puts "❌ 数据库文件不存在: #{db_path}"
end

# 检查配置文件加载
puts "\n⚙️  测试配置文件加载..."
begin
  if File.exist?('config/application.rb')
    require_relative 'config/application'
    puts "✅ 配置文件加载成功"
  else
    puts "❌ 配置文件不存在"
  end
rescue => e
  puts "❌ 配置文件加载失败: #{e.message}"
  puts "   错误详情: #{e.backtrace.first(3).join('\n   ')}"
end

# 尝试加载应用文件
puts "\n🚀 测试应用文件加载..."
begin
  if File.exist?('app_refactored.rb')
    # 仅解析不运行
    content = File.read('app_refactored.rb')
    puts "✅ app_refactored.rb 文件读取成功 (#{content.length} 字符)"
    
    # 检查是否包含必要的类定义
    if content.include?('class CicdApp')
      puts "✅ 找到 CicdApp 类定义"
    else
      puts "❌ 未找到 CicdApp 类定义"
    end
    
    if content.include?('ApplicationConfig.configure_sinatra')
      puts "✅ 找到 Sinatra 配置调用"
    else
      puts "❌ 未找到 Sinatra 配置调用"
    end
    
  else
    puts "❌ app_refactored.rb 文件不存在"
  end
rescue => e
  puts "❌ 应用文件处理失败: #{e.message}"
end

# 生成修复建议
puts "\n🔧 修复建议"
puts "=========="

if missing_gems.any?
  puts "1. 安装缺失的gem依赖:"
  puts "   gem install #{missing_gems.join(' ')}"
end

if missing_files.any?
  puts "2. 补充缺失的项目文件:"
  missing_files.each do |file|
    puts "   - #{file}"
  end
end

if !File.exist?('/app/cicd.db')
  puts "3. 初始化数据库:"
  puts "   ruby -e \"require_relative 'config/application'; ApplicationConfig.initialize_database\""
end

puts "\n4. 强制重新初始化数据库:"
puts "   rm -f /app/cicd.db"
puts "   ruby start_full_docker.rb"

puts "\n5. 如果问题持续，尝试简化版模式:"
puts "   export CICD_MODE=simple"
puts "   docker-compose up --build -d"

puts "\n📋 诊断完成"
puts "============"
puts "请根据上述建议修复问题，然后重新启动系统。"