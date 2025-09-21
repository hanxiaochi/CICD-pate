#!/usr/bin/env ruby
# Docker 验证脚本 - 确保系统完全正常

puts "=== Docker CICD 系统验证 ==="

# 测试1: 基础连接
puts "1. 测试基础连接..."
begin
  require 'net/http'
  uri = URI('http://localhost:4567/api/health')
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "✓ 系统运行正常"
    puts "✓ 数据库状态: #{data['database']}"
    puts "✓ 用户数量: #{data['users']}"
  else
    puts "✗ 系统响应异常: #{response.code}"
  end
rescue => e
  puts "✗ 连接失败: #{e.message}"
end

# 测试2: API 版本
puts "\n2. 测试API版本..."
begin
  uri = URI('http://localhost:4567/api/version')
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "✓ 版本: #{data['version']}"
    puts "✓ Ruby: #{data['ruby']}"
  else
    puts "✗ 版本API异常"
  end
rescue => e
  puts "✗ 版本检查失败: #{e.message}"
end

# 测试3: 登录功能
puts "\n3. 测试登录功能..."
begin
  require 'net/http'
  require 'json'
  
  uri = URI('http://localhost:4567/api/login')
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = { username: 'admin', password: 'admin123' }.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    if data['success']
      puts "✓ 登录功能正常"
      puts "✓ 管理员账户: #{data['user']['username']}"
    else
      puts "✗ 登录失败: #{data['error']}"
    end
  else
    puts "✗ 登录API异常: #{response.code}"
  end
rescue => e
  puts "✗ 登录测试失败: #{e.message}"
end

puts "\n=== 验证完成 ==="
puts "如果所有测试都通过，Docker系统运行正常！"
puts "访问: http://localhost:4567"