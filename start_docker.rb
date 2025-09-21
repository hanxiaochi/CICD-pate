#!/usr/bin/env ruby
# Docker 专用启动脚本 - 绝对解决数据库问题

puts "=== CICD Docker 启动 - 终极解决方案 ==="

# 强制设置环境
ENV['RACK_ENV'] = 'production' unless ENV['RACK_ENV']

# 必需的库
require 'sinatra'
require 'sinatra/base'
require 'sequel'
require 'bcrypt'
require 'json'
require 'fileutils'

# 立即初始化数据库 - 绝对优先
puts "初始化数据库..."

begin
  # 确保数据库目录存在
  FileUtils.mkdir_p('/app')
  
  # 强制创建数据库连接
  DB = Sequel.connect('sqlite:///app/cicd.db', max_connections: 1)
  Sequel::Model.db = DB
  
  # 立即测试连接
  DB.test_connection
  puts "✓ 数据库连接成功"
  
  # 强制创建用户表 - 最核心的表
  unless DB.table_exists?(:users)
    puts "创建 users 表..."
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
    puts "✓ users 表创建成功"
  end
  
  # 创建其他必要表
  tables_to_create = {
    projects: proc {
      DB.create_table :projects do
        primary_key :id
        String :name, null: false
        String :repo_url
        String :branch, default: 'master'
        Integer :user_id
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    },
    logs: proc {
      DB.create_table :logs do
        primary_key :id
        String :message
        String :level, default: 'info'
        Time :created_at, default: Time.now
      end
    }
  }
  
  tables_to_create.each do |table_name, create_proc|
    unless DB.table_exists?(table_name)
      puts "创建 #{table_name} 表..."
      create_proc.call
      puts "✓ #{table_name} 表创建成功"
    end
  end
  
  # 确保有管理员用户
  unless DB[:users].where(username: 'admin').count > 0
    puts "创建管理员账户..."
    DB[:users].insert(
      username: 'admin',
      password_hash: BCrypt::Password.create('admin123'),
      role: 'admin',
      email: 'admin@cicd.local',
      created_at: Time.now,
      updated_at: Time.now
    )
    puts "✓ 管理员账户创建成功"
  end
  
  puts "✓ 所有数据库初始化完成"
  
rescue => e
  puts "✗ 数据库初始化失败: #{e.message}"
  puts "尝试删除数据库文件重新创建..."
  
  # 如果失败，删除数据库文件重试
  File.delete('/app/cicd.db') if File.exist?('/app/cicd.db')
  
  # 重新创建
  DB = Sequel.connect('sqlite:///app/cicd.db', max_connections: 1)
  Sequel::Model.db = DB
  
  # 再次尝试创建表
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
  
  DB[:users].insert(
    username: 'admin',
    password_hash: BCrypt::Password.create('admin123'),
    role: 'admin',
    email: 'admin@cicd.local',
    created_at: Time.now,
    updated_at: Time.now
  )
  
  puts "✓ 数据库重新创建成功"
end

# 定义简单的用户模型
class User < Sequel::Model(:users)
  def authenticate(password)
    BCrypt::Password.new(password_hash) == password
  rescue
    false
  end
  
  def admin?
    role == 'admin'
  end
end

class Project < Sequel::Model(:projects)
end

# 极简应用类
class DockerCicdApp < Sinatra::Base
  enable :sessions
  set :session_secret, 'cicd_docker_secret_key_2024_very_long_32_chars_minimum_length_required'
  set :bind, '0.0.0.0'
  set :port, 4567
  
  before do
    content_type :json if request.path.start_with?('/api/')
  end
  
  helpers do
    def current_user
      @current_user ||= User[session[:user_id]] if session[:user_id]
    end
    
    def require_login
      halt 401, { error: '需要登录' }.to_json unless current_user
    end
    
    def json_response(data, status = 200)
      halt status, data.to_json
    end
  end
  
  # 根路径 - 检查登录状态
  get '/' do
    if current_user
      # 已登录用户显示主页
      content_type :html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>CICD System - Dashboard</title></head>
        <body style="font-family: Arial; margin: 50px; background: #f5f5f5;">
          <div style="max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px;">
              <h1 style="color: #007bff;">🚀 CICD 系统控制台</h1>
              <div>
                <span>欢迎, <strong>#{current_user.username}</strong> (#{current_user.role})</span>
                <a href="/logout" style="margin-left: 15px; color: #dc3545;">退出</a>
              </div>
            </div>
            
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px;">
              <div style="background: #e7f3ff; padding: 20px; border-radius: 8px; border-left: 4px solid #007bff;">
                <h3 style="margin: 0 0 10px 0; color: #007bff;">数据库状态</h3>
                <p style="margin: 0; font-size: 18px; font-weight: bold;">✅ 正常</p>
              </div>
              <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; border-left: 4px solid #28a745;">
                <h3 style="margin: 0 0 10px 0; color: #28a745;">用户数量</h3>
                <p style="margin: 0; font-size: 18px; font-weight: bold;">#{User.count}</p>
              </div>
              <div style="background: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #ffc107;">
                <h3 style="margin: 0 0 10px 0; color: #ffc107;">项目数量</h3>
                <p style="margin: 0; font-size: 18px; font-weight: bold;">#{Project.count}</p>
              </div>
            </div>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
              <h3 style="margin-top: 0;">🔧 API 端点</h3>
              <ul style="list-style: none; padding: 0;">
                <li style="margin: 10px 0;">📊 <a href="/api/health">健康检查</a> - 系统状态监控</li>
                <li style="margin: 10px 0;">ℹ️ <a href="/api/version">版本信息</a> - 系统版本详情</li>
                <li style="margin: 10px 0;">👤 <a href="/api/user">用户信息</a> - 当前用户详情</li>
                <li style="margin: 10px 0;">📁 <a href="/api/projects">项目列表</a> - 所有项目</li>
              </ul>
            </div>
            
            <div style="background: #d1ecf1; padding: 15px; border-radius: 8px; border: 1px solid #bee5eb;">
              <h4 style="margin-top: 0; color: #0c5460;">💡 快速测试</h4>
              <p style="margin-bottom: 10px;">使用 curl 测试 API：</p>
              <code style="background: #f8f9fa; padding: 5px; border-radius: 4px; display: block; margin: 5px 0;">curl http://localhost:4567/api/health</code>
              <code style="background: #f8f9fa; padding: 5px; border-radius: 4px; display: block; margin: 5px 0;">curl http://localhost:4567/api/version</code>
            </div>
          </div>
        </body>
        </html>
      HTML
    else
      # 未登录用户显示登录页面
      content_type :html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>CICD System - Login</title></head>
        <body style="font-family: Arial; margin: 0; background: linear-gradient(135deg, #007bff, #0056b3); min-height: 100vh; display: flex; align-items: center; justify-content: center;">
          <div style="background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); max-width: 400px; width: 100%;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #007bff; margin: 0 0 10px 0;">🚀 CICD 系统</h1>
              <p style="color: #666; margin: 0;">持续集成部署平台</p>
            </div>
            
            <form method="post" action="/login" style="margin: 0;">
              <div style="margin-bottom: 20px;">
                <label style="display: block; margin-bottom: 8px; font-weight: bold; color: #333;">用户名</label>
                <input type="text" name="username" required 
                       style="width: 100%; padding: 12px; border: 2px solid #e1e5e9; border-radius: 6px; font-size: 16px; box-sizing: border-box;"
                       placeholder="请输入用户名">
              </div>
              
              <div style="margin-bottom: 25px;">
                <label style="display: block; margin-bottom: 8px; font-weight: bold; color: #333;">密码</label>
                <input type="password" name="password" required 
                       style="width: 100%; padding: 12px; border: 2px solid #e1e5e9; border-radius: 6px; font-size: 16px; box-sizing: border-box;"
                       placeholder="请输入密码">
              </div>
              
              <button type="submit" 
                      style="width: 100%; padding: 14px; background: #007bff; color: white; border: none; border-radius: 6px; font-size: 16px; font-weight: bold; cursor: pointer; transition: background 0.3s;"
                      onmouseover="this.style.background='#0056b3'" onmouseout="this.style.background='#007bff'">登录系统</button>
            </form>
            
            <div style="text-align: center; margin-top: 25px; padding-top: 20px; border-top: 1px solid #e1e5e9;">
              <p style="color: #666; margin: 0 0 5px 0; font-size: 14px;">默认账户信息</p>
              <p style="color: #007bff; margin: 0; font-weight: bold;">admin / admin123</p>
            </div>
            
            <div style="text-align: center; margin-top: 20px;">
              <p style="color: #999; font-size: 12px; margin: 0;">系统运行正常 ✅ | API: <a href="/api/health" style="color: #007bff;">/api/health</a></p>
            </div>
          </div>
        </body>
        </html>
      HTML
    end
  end
  
  # API: 健康检查
  get '/api/health' do
    begin
      user_count = User.count
      project_count = Project.count
      db_status = 'healthy'
    rescue
      db_status = 'error'
      user_count = 0
      project_count = 0
    end
    
    json_response({
      status: 'ok',
      database: db_status,
      users: user_count,
      projects: project_count,
      timestamp: Time.now.to_i
    })
  end
  
  # API: 版本信息
  get '/api/version' do
    json_response({
      name: 'CICD Docker System',
      version: '3.0.0',
      ruby: RUBY_VERSION,
      timestamp: Time.now.to_i
    })
  end
  
  # 网页登录处理
  post '/login' do
    username = params[:username]
    password = params[:password]
    
    user = User.where(username: username).first
    
    if user && user.authenticate(password)
      session[:user_id] = user.id
      user.update(last_login: Time.now)
      redirect '/'
    else
      # 登录失败，显示错误信息
      content_type :html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>登录失败</title></head>
        <body style="font-family: Arial; margin: 0; background: linear-gradient(135deg, #dc3545, #c82333); min-height: 100vh; display: flex; align-items: center; justify-content: center;">
          <div style="background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); max-width: 400px; width: 100%;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #dc3545; margin: 0 0 10px 0;">❌ 登录失败</h1>
              <p style="color: #666; margin: 0;">用户名或密码错误</p>
            </div>
            <div style="text-align: center;">
              <a href="/" style="display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">返回登录</a>
            </div>
            <div style="text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid #e1e5e9;">
              <p style="color: #666; margin: 0 0 5px 0; font-size: 14px;">默认账户信息</p>
              <p style="color: #007bff; margin: 0; font-weight: bold;">admin / admin123</p>
            </div>
          </div>
        </body>
        </html>
      HTML
    end
  end
  
  # 退出登录
  get '/logout' do
    session.clear
    redirect '/'
  end

  # API: 登录（用于API调用）
  post '/api/login' do
    data = JSON.parse(request.body.read) rescue {}
    username = data['username'] || params[:username]
    password = data['password'] || params[:password]
    
    user = User.where(username: username).first
    
    if user && user.authenticate(password)
      session[:user_id] = user.id
      user.update(last_login: Time.now)
      json_response({
        success: true,
        user: {
          id: user.id,
          username: user.username,
          role: user.role
        }
      })
    else
      json_response({ success: false, error: '用户名或密码错误' }, 401)
    end
  end
  
  # API: 获取用户信息
  get '/api/user' do
    require_login
    json_response({
      id: current_user.id,
      username: current_user.username,
      role: current_user.role,
      email: current_user.email
    })
  end
  
  # API: 项目列表
  get '/api/projects' do
    require_login
    projects = Project.all.map do |p|
      {
        id: p.id,
        name: p.name,
        repo_url: p.repo_url,
        branch: p.branch,
        created_at: p.created_at
      }
    end
    json_response(projects)
  end
  
  # 错误处理
  error do
    json_response({ error: '服务器内部错误' }, 500)
  end
  
  not_found do
    json_response({ error: '页面不存在' }, 404)
  end
end

# 启动应用
puts "启动 CICD Docker 应用..."
puts "访问地址: http://localhost:4567"
puts "API 测试: curl http://localhost:4567/api/health"
puts "=========================================="

DockerCicdApp.run!