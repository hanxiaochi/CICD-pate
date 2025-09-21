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
  set :session_secret, 'cicd_docker_secret_2024'
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
  
  # 根路径 - 简单状态页
  get '/' do
    content_type :html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>CICD System - Docker</title></head>
      <body style="font-family: Arial; margin: 50px; background: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px;">
          <h1 style="color: #007bff;">🚀 CICD 系统运行中</h1>
          <p>✅ 数据库状态: <strong>正常</strong></p>
          <p>✅ 用户数量: <strong>#{User.count}</strong></p>
          <p>✅ 项目数量: <strong>#{Project.count}</strong></p>
          <hr>
          <h3>API 端点:</h3>
          <ul>
            <li><a href="/api/health">/api/health</a> - 健康检查</li>
            <li><a href="/api/version">/api/version</a> - 版本信息</li>
            <li><a href="/api/login">/api/login</a> - 登录接口</li>
          </ul>
          <hr>
          <p><strong>默认管理员:</strong> admin / admin123</p>
        </div>
      </body>
      </html>
    HTML
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
  
  # API: 登录
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