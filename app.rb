#!/usr/bin/env ruby
# CICD系统 - 统一主应用
# 支持完整功能和简化模式
# =============================================

puts "🚀 CICD系统启动中..."

# 环境检查和设置
ENV['RACK_ENV'] ||= 'production'
ENV['CICD_MODE'] ||= 'simple'  # simple/full

# 必需的库
require 'sinatra'
require 'sinatra/base'
require 'sequel'
require 'bcrypt'
require 'json'
require 'fileutils'

begin
  require 'sinatra/flash'
  require 'haml'
  FULL_FEATURES = true
rescue LoadError
  FULL_FEATURES = false
  puts "⚠️  部分高级功能不可用（缺少sinatra-flash或haml）"
end

# 数据库初始化
puts "初始化数据库..."

begin
  # 确保数据库目录存在
  db_path = ENV['DATABASE_URL'] || 'sqlite:///app/cicd.db'
  if db_path.include?('/app/')
    FileUtils.mkdir_p('/app')
  end
  
  # 创建数据库连接
  DB = Sequel.connect(db_path, max_connections: 5)
  Sequel::Model.db = DB
  
  # 测试连接
  DB.test_connection
  puts "✓ 数据库连接成功"
  
  # 创建必要的表
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
  end
  
  # 根据模式创建其他表
  if ENV['CICD_MODE'] == 'full'
    # 完整模式 - 创建所有表
    tables = {
      workspaces: proc {
        DB.create_table :workspaces do
          primary_key :id
          String :name, null: false
          String :description
          Integer :owner_id
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
        end
      },
      projects: proc {
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
      },
      builds: proc {
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
      },
      resources: proc {
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
      },
      logs: proc {
        DB.create_table :logs do
          primary_key :id
          String :level, default: 'info'
          String :message
          Integer :user_id
          String :ip_address
          Time :created_at, default: Time.now
        end
      }
    }
    
    tables.each do |table_name, create_proc|
      unless DB.table_exists?(table_name)
        puts "创建 #{table_name} 表..."
        create_proc.call
      end
    end
  else
    # 简化模式 - 只创建基础表
    unless DB.table_exists?(:projects)
      DB.create_table :projects do
        primary_key :id
        String :name, null: false
        String :repo_url
        String :branch, default: 'master'
        Integer :user_id
        Time :created_at, default: Time.now
        Time :updated_at, default: Time.now
      end
    end
    
    unless DB.table_exists?(:logs)
      DB.create_table :logs do
        primary_key :id
        String :message
        String :level, default: 'info'
        Time :created_at, default: Time.now
      end
    end
  end
  
  # 确保有管理员用户
  unless DB[:users].where(username: 'admin').count > 0
    puts "创建管理员账户..."
    admin_id = DB[:users].insert(
      username: 'admin',
      password_hash: BCrypt::Password.create('admin123'),
      role: 'admin',
      email: 'admin@cicd.local',
      created_at: Time.now,
      updated_at: Time.now
    )
    
    # 如果是完整模式，创建默认数据
    if ENV['CICD_MODE'] == 'full' && DB.table_exists?(:workspaces)
      workspace_id = DB[:workspaces].insert(
        name: '默认工作空间',
        description: '系统默认的工作空间',
        owner_id: admin_id,
        created_at: Time.now,
        updated_at: Time.now
      )
      
      DB[:projects].insert(
        name: '示例项目',
        repo_url: 'https://github.com/example/demo.git',
        branch: 'main',
        user_id: admin_id,
        workspace_id: workspace_id,
        created_at: Time.now,
        updated_at: Time.now
      )
    end
    
    puts "✓ 管理员账户创建成功"
  end
  
  puts "✓ 数据库初始化完成"
  
rescue => e
  puts "✗ 数据库初始化失败: #{e.message}"
  puts "尝试修复..."
  
  # 删除损坏的数据库文件
  db_file = db_path.gsub('sqlite://', '')
  File.delete(db_file) if File.exist?(db_file)
  
  # 重新初始化
  DB = Sequel.connect(db_path, max_connections: 5)
  Sequel::Model.db = DB
  
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
    email: 'admin@cicd.local'
  )
  
  puts "✓ 数据库重新创建成功"
end

# 模型定义
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

# 完整模式的额外模型
if ENV['CICD_MODE'] == 'full'
  class Workspace < Sequel::Model(:workspaces)
  end if DB.table_exists?(:workspaces)
  
  class Build < Sequel::Model(:builds)
  end if DB.table_exists?(:builds)
  
  class Resource < Sequel::Model(:resources)
  end if DB.table_exists?(:resources)
  
  class Log < Sequel::Model(:logs)
  end if DB.table_exists?(:logs)
end

# 主应用类
class CicdApp < Sinatra::Base
  enable :sessions
  set :session_secret, 'cicd_secret_key_2024_very_long_32_chars_minimum_length_required'
  set :bind, '0.0.0.0'
  set :port, 4567
  
  # 如果有flash功能则启用
  register Sinatra::Flash if defined?(Sinatra::Flash)
  
  before do
    content_type :json if request.path.start_with?('/api/')
  end
  
  helpers do
    def current_user
      @current_user ||= User[session[:user_id]] if session[:user_id]
    end
    
    def require_login
      if request.path.start_with?('/api/')
        halt 401, { error: '需要登录' }.to_json unless current_user
      else
        redirect '/' unless current_user
      end
    end
    
    def require_admin
      require_login
      halt 403, { error: '需要管理员权限' }.to_json unless current_user.admin?
    end
    
    def json_response(data, status = 200)
      halt status, data.to_json
    end
    
    def render_template(template, locals = {})
      if defined?(Haml) && ENV['CICD_MODE'] == 'full'
        haml template, locals: locals
      else
        # 使用内联HTML模板
        send("#{template}_html", locals)
      end
    end
  end
  
  # === 主页和认证 ===
  get '/' do
    if current_user
      render_template(:dashboard)
    else
      render_template(:login)
    end
  end
  
  post '/login' do
    username = params[:username]
    password = params[:password]
    
    user = User.where(username: username).first
    
    if user && user.authenticate(password)
      session[:user_id] = user.id
      user.update(last_login: Time.now)
      
      if request.accept.include?('application/json')
        json_response({ success: true, user: { id: user.id, username: user.username, role: user.role } })
      else
        redirect '/'
      end
    else
      if request.accept.include?('application/json')
        json_response({ success: false, error: '用户名或密码错误' }, 401)
      else
        render_template(:login_error)
      end
    end
  end
  
  get '/logout' do
    session.clear
    redirect '/'
  end
  
  # === API 端点 ===
  get '/api/health' do
    begin
      stats = {
        status: 'ok',
        mode: ENV['CICD_MODE'],
        features: FULL_FEATURES ? 'full' : 'basic',
        database: 'healthy',
        users: User.count,
        projects: Project.count,
        timestamp: Time.now.to_i
      }
      
      if ENV['CICD_MODE'] == 'full'
        stats[:workspaces] = defined?(Workspace) ? Workspace.count : 0
        stats[:builds] = defined?(Build) ? Build.count : 0
        stats[:resources] = defined?(Resource) ? Resource.count : 0
      end
      
      json_response(stats)
    rescue => e
      json_response({ status: 'error', message: e.message }, 500)
    end
  end
  
  get '/api/version' do
    json_response({
      name: 'CICD System',
      version: '4.0.0',
      mode: ENV['CICD_MODE'],
      ruby: RUBY_VERSION,
      features: FULL_FEATURES ? 'full' : 'basic',
      timestamp: Time.now.to_i
    })
  end
  
  get '/api/user' do
    require_login
    json_response({
      id: current_user.id,
      username: current_user.username,
      role: current_user.role,
      email: current_user.email,
      last_login: current_user.last_login
    })
  end
  
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
  
  # === 完整模式功能 ===
  if ENV['CICD_MODE'] == 'full'
    # 工作空间管理
    get '/workspaces' do
      require_login
      if defined?(Workspace)
        @workspaces = if current_user.admin?
          Workspace.all
        else
          Workspace.where(owner_id: current_user.id)
        end
        render_template(:workspaces)
      else
        halt 404, '工作空间功能不可用'
      end
    end
    
    get '/api/workspaces' do
      require_login
      if defined?(Workspace)
        workspaces = Workspace.all.map do |w|
          {
            id: w.id,
            name: w.name,
            description: w.description,
            owner_id: w.owner_id,
            created_at: w.created_at
          }
        end
        json_response(workspaces)
      else
        json_response({ error: '工作空间功能不可用' }, 404)
      end
    end
    
    # 构建管理
    get '/api/builds' do
      require_login
      if defined?(Build)
        builds = Build.order(Sequel.desc(:created_at)).limit(50).map do |b|
          {
            id: b.id,
            project_id: b.project_id,
            status: b.status,
            commit_hash: b.commit_hash,
            started_at: b.started_at,
            finished_at: b.finished_at,
            created_at: b.created_at
          }
        end
        json_response(builds)
      else
        json_response({ error: '构建功能不可用' }, 404)
      end
    end
    
    # 资源管理
    get '/api/resources' do
      require_login
      if defined?(Resource)
        resources = Resource.all.map do |r|
          {
            id: r.id,
            name: r.name,
            type: r.type,
            status: r.status,
            host: r.host,
            port: r.port,
            created_at: r.created_at
          }
        end
        json_response(resources)
      else
        json_response({ error: '资源管理功能不可用' }, 404)
      end
    end
  end
  
  # === 内联HTML模板 ===
  
  def login_html(locals = {})
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>CICD System - Login</title>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial; margin: 0; background: linear-gradient(135deg, #007bff, #0056b3); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
          .login-box { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); max-width: 400px; width: 100%; }
          .header { text-align: center; margin-bottom: 30px; }
          .header h1 { color: #007bff; margin: 0 0 10px 0; }
          .header p { color: #666; margin: 0; }
          .form-group { margin-bottom: 20px; }
          label { display: block; margin-bottom: 8px; font-weight: bold; color: #333; }
          input[type="text"], input[type="password"] { width: 100%; padding: 12px; border: 2px solid #e1e5e9; border-radius: 6px; font-size: 16px; box-sizing: border-box; }
          button { width: 100%; padding: 14px; background: #007bff; color: white; border: none; border-radius: 6px; font-size: 16px; font-weight: bold; cursor: pointer; }
          button:hover { background: #0056b3; }
          .default-account { text-align: center; margin-top: 25px; padding-top: 20px; border-top: 1px solid #e1e5e9; }
          .status { text-align: center; margin-top: 20px; color: #999; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="login-box">
          <div class="header">
            <h1>🚀 CICD 系统</h1>
            <p>持续集成部署平台 (#{ENV['CICD_MODE'].upcase} 模式)</p>
          </div>
          
          <form method="post" action="/login">
            <div class="form-group">
              <label>用户名</label>
              <input type="text" name="username" required placeholder="请输入用户名">
            </div>
            
            <div class="form-group">
              <label>密码</label>
              <input type="password" name="password" required placeholder="请输入密码">
            </div>
            
            <button type="submit">登录系统</button>
          </form>
          
          <div class="default-account">
            <p style="color: #666; margin: 0 0 5px 0; font-size: 14px;">默认账户信息</p>
            <p style="color: #007bff; margin: 0; font-weight: bold;">admin / admin123</p>
          </div>
          
          <div class="status">
            系统运行正常 ✅ | API: <a href="/api/health" style="color: #007bff;">/api/health</a>
          </div>
        </div>
      </body>
      </html>
    HTML
  end
  
  def dashboard_html(locals = {})
    user_count = User.count
    project_count = Project.count
    
    # 完整模式的额外统计
    extra_stats = ""
    extra_features = ""
    
    if ENV['CICD_MODE'] == 'full'
      workspace_count = defined?(Workspace) ? Workspace.count : 0
      build_count = defined?(Build) ? Build.count : 0
      resource_count = defined?(Resource) ? Resource.count : 0
      
      extra_stats = <<~HTML
        <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; border-left: 4px solid #28a745;">
          <h3 style="margin: 0 0 10px 0; color: #28a745;">工作空间</h3>
          <p style="margin: 0; font-size: 18px; font-weight: bold;">#{workspace_count}</p>
        </div>
        <div style="background: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #ffc107;">
          <h3 style="margin: 0 0 10px 0; color: #ffc107;">构建任务</h3>
          <p style="margin: 0; font-size: 18px; font-weight: bold;">#{build_count}</p>
        </div>
        <div style="background: #f8d7da; padding: 20px; border-radius: 8px; border-left: 4px solid #dc3545;">
          <h3 style="margin: 0 0 10px 0; color: #dc3545;">资源节点</h3>
          <p style="margin: 0; font-size: 18px; font-weight: bold;">#{resource_count}</p>
        </div>
      HTML
      
      extra_features = <<~HTML
        <li style="margin: 10px 0;">🏢 <a href="/api/workspaces">工作空间管理</a> - 团队协作空间</li>
        <li style="margin: 10px 0;">🔧 <a href="/api/builds">构建管理</a> - CI/CD 流水线</li>
        <li style="margin: 10px 0;">💻 <a href="/api/resources">资源管理</a> - 计算资源管理</li>
      HTML
    end
    
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>CICD System - Dashboard</title>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial; margin: 50px; background: #f5f5f5; }
          .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
          .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
          .header h1 { color: #007bff; }
          .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
          .api-section { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
          .api-section h3 { margin-top: 0; }
          .api-section ul { list-style: none; padding: 0; }
          .api-section li { margin: 10px 0; }
          .info-box { background: #d1ecf1; padding: 15px; border-radius: 8px; border: 1px solid #bee5eb; }
          .mode-badge { background: #{ENV['CICD_MODE'] == 'full' ? '#28a745' : '#007bff'}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div>
              <h1>🚀 CICD 系统控制台</h1>
              <span class="mode-badge">#{ENV['CICD_MODE'].upcase} 模式</span>
            </div>
            <div>
              <span>欢迎, <strong>#{current_user.username}</strong> (#{current_user.role})</span>
              <a href="/logout" style="margin-left: 15px; color: #dc3545;">退出</a>
            </div>
          </div>
          
          <div class="stats-grid">
            <div style="background: #e7f3ff; padding: 20px; border-radius: 8px; border-left: 4px solid #007bff;">
              <h3 style="margin: 0 0 10px 0; color: #007bff;">数据库状态</h3>
              <p style="margin: 0; font-size: 18px; font-weight: bold;">✅ 正常</p>
            </div>
            <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; border-left: 4px solid #28a745;">
              <h3 style="margin: 0 0 10px 0; color: #28a745;">用户数量</h3>
              <p style="margin: 0; font-size: 18px; font-weight: bold;">#{user_count}</p>
            </div>
            <div style="background: #fff3cd; padding: 20px; border-radius: 8px; border-left: 4px solid #ffc107;">
              <h3 style="margin: 0 0 10px 0; color: #ffc107;">项目数量</h3>
              <p style="margin: 0; font-size: 18px; font-weight: bold;">#{project_count}</p>
            </div>
            #{extra_stats}
          </div>
          
          <div class="api-section">
            <h3>🔧 API 端点</h3>
            <ul>
              <li>📊 <a href="/api/health">健康检查</a> - 系统状态监控</li>
              <li>ℹ️ <a href="/api/version">版本信息</a> - 系统版本详情</li>
              <li>👤 <a href="/api/user">用户信息</a> - 当前用户详情</li>
              <li>📁 <a href="/api/projects">项目列表</a> - 所有项目</li>
              #{extra_features}
            </ul>
          </div>
          
          <div class="info-box">
            <h4 style="margin-top: 0; color: #0c5460;">💡 快速测试</h4>
            <p style="margin-bottom: 10px;">使用 curl 测试 API：</p>
            <code style="background: #f8f9fa; padding: 5px; border-radius: 4px; display: block; margin: 5px 0;">curl http://localhost:4567/api/health</code>
            <code style="background: #f8f9fa; padding: 5px; border-radius: 4px; display: block; margin: 5px 0;">curl http://localhost:4567/api/version</code>
          </div>
        </div>
      </body>
      </html>
    HTML
  end
  
  def login_error_html(locals = {})
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>登录失败</title>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial; margin: 0; background: linear-gradient(135deg, #dc3545, #c82333); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
          .error-box { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); max-width: 400px; width: 100%; text-align: center; }
          h1 { color: #dc3545; margin: 0 0 10px 0; }
          p { color: #666; margin: 0 0 20px 0; }
          a { display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 6px; font-weight: bold; }
          .default-account { margin-top: 20px; padding-top: 20px; border-top: 1px solid #e1e5e9; }
        </style>
      </head>
      <body>
        <div class="error-box">
          <h1>❌ 登录失败</h1>
          <p>用户名或密码错误</p>
          <a href="/">返回登录</a>
          <div class="default-account">
            <p style="color: #666; margin: 0 0 5px 0; font-size: 14px;">默认账户信息</p>
            <p style="color: #007bff; margin: 0; font-weight: bold;">admin / admin123</p>
          </div>
        </div>
      </body>
      </html>
    HTML
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
puts "✅ CICD系统启动成功！"
puts "================================="
puts "模式: #{ENV['CICD_MODE'].upcase}"
puts "功能: #{FULL_FEATURES ? 'FULL' : 'BASIC'}"
puts "访问地址: http://localhost:4567"
puts "默认账户: admin / admin123"
puts ""
puts "API端点:"
puts "  GET  /api/health   - 健康检查"
puts "  GET  /api/version  - 版本信息"
puts "  GET  /api/user     - 用户信息"
puts "  GET  /api/projects - 项目列表"

if ENV['CICD_MODE'] == 'full'
  puts "  GET  /api/workspaces - 工作空间"
  puts "  GET  /api/builds     - 构建历史"
  puts "  GET  /api/resources  - 资源管理"
end

puts "================================="

# 运行应用
if __FILE__ == $0
  CicdApp.run!
end