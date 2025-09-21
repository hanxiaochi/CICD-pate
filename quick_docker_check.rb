#!/usr/bin/env ruby
# 快速Docker启动验证脚本

puts "=== CICD 快速启动验证 ==="
puts "Ruby版本: #{RUBY_VERSION}"
puts

# 检查关键文件
begin
  puts "1. 加载配置文件..."
  require_relative 'config/application'
  puts "✓ 配置文件加载成功"
rescue => e
  puts "✗ 配置文件加载失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
  exit 1
end

# 检查数据库
begin
  puts "2. 检查数据库..."
  if defined?(DB)
    DB.test_connection
    puts "✓ 数据库连接正常"
  else
    puts "✗ 数据库未初始化"
  end
rescue => e
  puts "✗ 数据库错误: #{e.message}"
end

# 检查核心类
begin
  puts "3. 检查核心类..."
  
  classes_to_check = [
    'User', 'Project', 'Workspace', 'Resource', 
    'Build', 'Deployment', 'Log', 'SystemConfig', 'Permission',
    'BaseController', 'ApiController', 'CicdApp'
  ]
  
  classes_to_check.each do |class_name|
    if Object.const_defined?(class_name)
      puts "✓ #{class_name} - 已定义"
    else
      puts "✗ #{class_name} - 未定义"
    end
  end
rescue => e
  puts "✗ 类检查失败: #{e.message}"
end

puts
puts "=== 验证完成 ==="
puts "如果所有项目都是 ✓，说明修复成功，Docker可以正常启动"