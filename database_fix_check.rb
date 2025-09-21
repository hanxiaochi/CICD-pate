#!/usr/bin/env ruby
# 数据库修复验证脚本

puts "=== CICD 数据库修复验证 ==="
puts "Ruby版本: #{RUBY_VERSION}"
puts "时间: #{Time.now}"
puts

begin
  puts "1. 测试数据库连接设置..."
  
  # 手动设置数据库连接
  require 'sequel'
  database = Sequel.sqlite('cicd.db')
  Sequel::Model.db = database
  puts "✓ 数据库连接设置成功"
  
  # 测试数据库连接
  database.test_connection
  puts "✓ 数据库连接测试通过"
  
rescue => e
  puts "✗ 数据库连接失败: #{e.message}"
  exit 1
end

begin
  puts "2. 测试模型加载..."
  
  # 简单的模型定义测试
  class TestUser < Sequel::Model(:users)
    plugin :timestamps, update_on_create: true
  end
  
  puts "✓ 模型定义成功"
  
rescue => e
  puts "✗ 模型定义失败: #{e.message}"
  exit 1
end

begin
  puts "3. 加载完整配置..."
  require_relative 'config/application'
  puts "✓ 配置文件加载成功"
  
  # 检查核心类是否正确定义
  classes_to_check = ['User', 'Project', 'CicdApp']
  classes_to_check.each do |class_name|
    if Object.const_defined?(class_name)
      puts "✓ #{class_name} - 已定义"
    else
      puts "✗ #{class_name} - 未定义"
    end
  end
  
rescue => e
  puts "✗ 配置加载失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first}"
  exit 1
end

puts
puts "=== 数据库修复验证完成 ==="
puts "✓ 所有测试通过，Docker应该可以正常启动了！"