#!/usr/bin/env ruby
# 数据库修复验证脚本 - 最终版

puts "=== CICD 数据库修复验证 ==="
puts

begin
  puts "正在加载完整配置..."
  require_relative 'config/application'
  puts "✓ 配置文件加载成功"
  
rescue => e
  puts "✗ 配置加载失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
  exit 1
end

begin
  puts "正在检查核心类..."
  
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

begin
  puts
  puts "正在测试数据库操作..."
  
  if defined?(DB)
    DB.test_connection
    puts "✓ 数据库连接正常"
    
    # 测试模型操作
    user_count = User.count
    puts "✓ 模型查询正常 (用户数: #{user_count})"
  else
    puts "✗ 数据库未初始化"
  end
  
rescue => e
  puts "✗ 数据库操作失败: #{e.message}"
end

puts
puts "=== 验证完成 ==="
puts "如果所有项目都是 ✓，说明数据库修复成功！"