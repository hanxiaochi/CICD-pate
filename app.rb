#!/usr/bin/env ruby
# CICD系统 - 统一主应用
# 支持完整功能和简化模式
# =============================================

puts "🚀 CICD系统启动中..."

# 环境检查和设置
ENV['RACK_ENV'] ||= 'production'
ENV['CICD_MODE'] ||= 'full'  # simple/full

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
  db_path = ENV['DATABASE_URL'] || 'sqlite://cicd.db'
  db_dir = File.dirname(db_path.sub('sqlite://', '')) rescue '.'
  FileUtils.mkdir_p(db_dir) unless db_dir == '.'
  
  # 创建数据库连接
  DB = Sequel.connect(db_path, max_connections: 5)
  Sequel::Model.db = DB
  
  # 测试连接
  DB.test_connection
  puts "✓ 数据库连接成功: #{db_path}"
  
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
    
    # 创建默认管理员用户
    DB[:users].insert(
      username: 'admin',
      password_hash: BCrypt::Password.create('admin123'),
      role: 'admin',
      email: 'admin@cicd.local',
      active: true,
      created_at: Time.now,
      updated_at: Time.now
    )
    puts "✓ 默认管理员用户创建成功"
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
          String :repo_type, default: 'git'
          String :project_type, default: 'java'
          Text :description
          Text :environment_vars
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
          Integer :user_id
          String :status, default: 'pending'
          String :build_number
          String :commit_hash
          String :branch
          Time :start_time
          Time :end_time
          Integer :duration
          Text :log_content
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
        end
      },
      deployments: proc {
        DB.create_table :deployments do
          primary_key :id
          Integer :project_id
          Integer :build_id
          Integer :user_id
          String :environment
          String :status, default: 'pending'
          Text :log_content
          Time :start_time
          Time :end_time
          Integer :duration
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
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
          String :username
          String :password
          String :ssh_key_path
          String :os_type
          Text :config
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
          Time :last_check
        end
      },
      docker_resources: proc {
        DB.create_table :docker_resources do
          primary_key :id
          String :name, null: false
          String :host
          Integer :port, default: 2376
          String :status, default: 'unknown'
          String :version
          String :api_version
          Text :config
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
        end
      },
      scripts: proc {
        DB.create_table :scripts do
          primary_key :id
          String :name, null: false
          String :script_type
          String :file_path
          Text :description
          String :content_hash
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
        end
      },
      permissions: proc {
        DB.create_table :permissions do
          primary_key :id
          Integer :user_id
          String :resource_type
          Integer :resource_id
          String :action
          Time :created_at, default: Time.now
        end
      },
      system_configs: proc {
        DB.create_table :system_configs do
          primary_key :id
          String :config_key, null: false, unique: true
          Text :config_value
          String :description
          Time :created_at, default: Time.now
          Time :updated_at, default: Time.now
        end
      },
      logs: proc {
        DB.create_table :logs do
          primary_key :id
          String :level
          String :source
          Text :message
          Text :details
          Time :created_at, default: Time.now
        end
      }
    }
    
    # 创建表
    tables.each do |name, definition|
      unless DB.table_exists?(name)
        puts "创建 #{name} 表..."
        definition.call
      end
    end
    
    puts "✓ 所有表创建完成"
  end
rescue => e
  puts "✗ 数据库初始化失败: #{e.message}"
  exit 1
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
end if DB.table_exists?(:projects)

class Build < Sequel::Model(:builds)
end if DB.table_exists?(:builds)

class Resource < Sequel::Model(:resources)
end if DB.table_exists?(:resources)

class Script < Sequel::Model(:scripts)
end if DB.table_exists?(:scripts)

class Workspace < Sequel::Model(:workspaces)
end if DB.table_exists?(:workspaces)

# 主应用类
class CicdApp < Sinatra::Base
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET'] || 'cicd_secret_key_2024_very_long_64_chars_minimum_length_required_for_rack_session_encryptor_cicd_system'
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
        redirect '/login' unless current_user
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
      if defined?(Haml) && ENV['CICD_MODE'] == 'full'
        haml :dashboard
      else
        json_response({ message: "欢迎, #{current_user.username}!", user: current_user.values })
      end
    else
      if defined?(Haml) && ENV['CICD_MODE'] == 'full'
        haml :login
      else
        json_response({ message: "请登录" })
      end
    end
  end
  
  get '/login' do
    if defined?(Haml) && ENV['CICD_MODE'] == 'full'
      haml :login
    else
      json_response({ message: "请使用POST /login进行登录" })
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
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          haml :login_error
        else
          json_response({ success: false, error: '用户名或密码错误' }, 401)
        end
      end
    end
  end
  
  get '/logout' do
    session.clear
    redirect '/login'
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
  
  # === 完整模式功能 ===
  if ENV['CICD_MODE'] == 'full'
    get '/projects' do
      require_login
      @projects = Project.all
      haml :projects
    end
    
    get '/projects/new' do
      require_login
      haml :project_form
    end
    
    post '/projects' do
      require_login
      begin
        # 检查必需参数
        unless params[:name] && !params[:name].strip.empty?
          raise "项目名称不能为空"
        end
        
        # 创建项目并设置属性
        project = Project.new
        project.name = params[:name].strip
        project.repo_url = (params[:repo_url] || '').strip
        project.branch = (params[:branch] || 'master').strip
        project.repo_type = params[:repo_type] || 'git'
        project.project_type = params[:project_type] || 'java'
        project.user_id = current_user.id
        
        # 保存项目
        if project.save
          puts "项目创建成功: #{project.name}"
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:success] = '项目创建成功' if defined?(Sinatra::Flash)
            redirect '/projects'
          else
            json_response({ success: true, message: '项目创建成功' })
          end
        else
          error_msg = "项目保存失败: #{project.errors.full_messages.join(', ')}"
          raise error_msg
        end
      rescue => e
        error_msg = "创建项目失败: #{e.message}"
        puts error_msg
        puts e.backtrace
        # 在开发环境中显示详细错误信息
        if ENV['RACK_ENV'] == 'development'
          puts "参数信息: #{params.inspect}"
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          flash[:error] = error_msg if defined?(Sinatra::Flash)
          redirect '/projects/new'
        else
          json_response({ success: false, error: error_msg }, 400)
        end
      end
    end
    
    # 编辑项目表单路由
    get '/projects/:id/edit' do
      require_login
      begin
        @project = Project[params[:id]]
        if @project.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '项目不存在'
            redirect '/projects'
          else
            json_response({ success: false, error: '项目不存在' }, 404)
          end
        end
        
        # 检查项目是否属于当前用户（或用户是管理员）
        if @project.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '权限不足'
            redirect '/projects'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          haml :project_form
        else
          json_response({ success: true, project: @project.values })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          flash[:error] = "获取项目信息失败: #{e.message}"
          redirect '/projects'
        else
          json_response({ success: false, error: "获取项目信息失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 更新项目路由
    put '/projects/:id' do
      require_login
      begin
        project = Project[params[:id]]
        if project.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '项目不存在'
            redirect '/projects'
          else
            json_response({ success: false, error: '项目不存在' }, 404)
          end
        end
        
        # 检查项目是否属于当前用户（或用户是管理员）
        if project.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '权限不足'
            redirect '/projects'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 更新项目属性
        project.name = params[:name].strip if params[:name]
        project.repo_url = (params[:repo_url] || '').strip
        project.branch = (params[:branch] || 'master').strip
        project.repo_type = params[:repo_type] || 'git'
        project.project_type = params[:project_type] || 'java'
        project.description = params[:description] if params[:description]
        
        # 保存项目
        if project.save
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:success] = '项目更新成功'
            redirect "/projects/#{project.id}"
          else
            json_response({ success: true, message: '项目更新成功', project: project.values })
          end
        else
          error_msg = "项目保存失败: #{project.errors.full_messages.join(', ')}"
          raise error_msg
        end
      rescue => e
        error_msg = "更新项目失败: #{e.message}"
        puts error_msg
        puts e.backtrace
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          flash[:error] = error_msg
          redirect "/projects/#{params[:id]}/edit"
        else
          json_response({ success: false, error: error_msg }, 400)
        end
      end
    end
    
    # 项目详情路由
    get '/projects/:id' do
      require_login
      begin
        @project = Project[params[:id]]
        if @project.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '项目不存在'
            redirect '/projects'
          else
            json_response({ success: false, error: '项目不存在' }, 404)
          end
        end
        
        # 检查项目是否属于当前用户（或用户是管理员）
        if @project.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full'
            flash[:error] = '权限不足'
            redirect '/projects'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 获取项目相关的构建记录（如果模型支持）
        if @project.respond_to?(:builds_dataset)
          @builds = @project.builds_dataset.order(Sequel.desc(:created_at)).limit(10).all
        else
          @builds = []
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          haml :project_detail
        else
          json_response({
            success: true,
            project: @project.values,
            builds: @builds.map(&:values)
          })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full'
          flash[:error] = "获取项目详情失败: #{e.message}"
          redirect '/projects'
        else
          json_response({ success: false, error: "获取项目详情失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 删除项目路由
    delete '/projects/:id' do
      require_login
      begin
        project = Project[params[:id]]
        if project.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '项目不存在'
            redirect '/projects'
          else
            json_response({ success: false, error: '项目不存在' }, 404)
          end
        end
        
        # 检查项目是否属于当前用户（或用户是管理员）
        if project.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/projects'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 删除项目
        project.destroy
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '项目删除成功'
          redirect '/projects'
        else
          json_response({ success: true, message: '项目删除成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "删除失败: #{e.message}"
          redirect '/projects'
        else
          json_response({ success: false, error: "删除失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/workspaces' do
      require_login
      if defined?(Workspace)
        @workspaces = if current_user.admin?
          Workspace.all
        else
          Workspace.where(owner_id: current_user.id)
        end
        haml :workspaces
      else
        halt 404, '工作空间功能不可用'
      end
    end
    
    post '/workspaces' do
      require_login
      begin
        workspace = Workspace.create(
          name: params[:name],
          description: params[:description],
          owner_id: current_user.id
        )
        
        redirect '/workspaces'
      rescue => e
        redirect '/workspaces'
      end
    end
    
    delete '/workspaces/:id' do
      require_login
      begin
        workspace = Workspace[params[:id]]
        if workspace.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '工作空间不存在'
            redirect '/workspaces'
          else
            json_response({ success: false, error: '工作空间不存在' }, 404)
          end
        end
        
        # 检查工作空间是否属于当前用户（或用户是管理员）
        if workspace.owner_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/workspaces'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 删除工作空间
        workspace.destroy
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '工作空间删除成功'
          redirect '/workspaces'
        else
          json_response({ success: true, message: '工作空间删除成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "删除失败: #{e.message}"
          redirect '/workspaces'
        else
          json_response({ success: false, error: "删除失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/builds' do
      require_login
      if defined?(Build)
        @builds = Build.order(Sequel.desc(:created_at)).limit(50).all
        haml :builds
      else
        halt 404, '构建功能不可用'
      end
    end
    
    get '/builds/new' do
      require_login
      if defined?(Build)
        @projects = Project.all
        haml :build_form
      else
        halt 404, '构建功能不可用'
      end
    end

    post '/builds' do
      require_login
      begin
        project = Project[params[:project_id]]
        if project.nil?
          halt 404, { error: '项目不存在' }.to_json
        end
      
        build = Build.create(
          project_id: params[:project_id],
          user_id: current_user.id,
          commit_hash: params[:commit_hash] || '',
          branch: params[:branch] || project.branch || 'master',
          status: params[:status] || 'pending',
          build_number: "BUILD-#{Time.now.to_i}"
        )
        
        redirect '/builds'
      rescue => e
        redirect '/builds/new'
      end
    end
    
    # 构建详情路由
    get '/builds/:id' do
      require_login
      begin
        @build = Build[params[:id]]
        if @build.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '构建记录不存在'
            redirect '/builds'
          else
            json_response({ success: false, error: '构建记录不存在' }, 404)
          end
        end
        
        # 检查构建是否属于当前用户（或用户是管理员）
        if @build.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/builds'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          haml :build_detail
        else
          json_response({ success: true, build: @build.values })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "获取构建详情失败: #{e.message}"
          redirect '/builds'
        else
          json_response({ success: false, error: "获取构建详情失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 重新构建路由
    post '/builds/:id/rebuild' do
      require_login
      begin
        original_build = Build[params[:id]]
        if original_build.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '构建记录不存在'
            redirect '/builds'
          else
            json_response({ success: false, error: '构建记录不存在' }, 404)
          end
        end
        
        # 检查构建是否属于当前用户（或用户是管理员）
        if original_build.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/builds'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 创建新的构建记录（复制原始构建的配置）
        new_build = Build.create(
          project_id: original_build.project_id,
          user_id: current_user.id,
          commit_hash: original_build.commit_hash,
          branch: original_build.branch || 'master',
          status: 'pending',
          build_number: "BUILD-#{Time.now.to_i}",
          log_content: original_build.log_content
        )
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '重新构建请求已发送'
          redirect '/builds'
        else
          json_response({ success: true, message: '重新构建请求已发送', build: new_build.values })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "重新构建失败: #{e.message}"
          redirect '/builds'
        else
          json_response({ success: false, error: "重新构建失败: #{e.message}" }, 500)
        end
      end
    end
    
    delete '/builds/:id' do
      require_login
      begin
        build = Build[params[:id]]
        if build.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '构建记录不存在'
            redirect '/builds'
          else
            json_response({ success: false, error: '构建记录不存在' }, 404)
          end
        end
        
        # 检查构建是否属于当前用户（或用户是管理员）
        if build.user_id != current_user.id && !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/builds'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 删除构建
        build.destroy
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '构建记录删除成功'
          redirect '/builds'
        else
          json_response({ success: true, message: '构建记录删除成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "删除失败: #{e.message}"
          redirect '/builds'
        else
          json_response({ success: false, error: "删除失败: #{e.message}" }, 500)
        end
      end
    end
    # 资源详情路由
    get '/resources/:id' do
      require_login
      begin
        @resource = Resource[params[:id]]
        if @resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          haml :resource_detail
        else
          json_response({ success: true, resource: @resource.values })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "获取资源详情失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "获取资源详情失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/resources' do
      require_login
      if defined?(Resource)
        @resources = Resource.all
        haml :resources
      else
        halt 404, '资源管理功能不可用'
      end
    end
    
    post '/resources' do
      require_login
      begin
        # 准备资源参数
        resource_params = {
          name: params[:name],
          type: params[:type],
          host: params[:host],
          port: params[:port],
          username: params[:username],
          os_type: params[:os_type] || 'Linux'
        }
        
        # 设置默认端口
        unless resource_params[:port]
          resource_params[:port] = case params[:type]
                                  when 'SSH' then 22
                                  when 'Windows' then 5985
                                  else 5985
                                  end
        end
        
        # 根据认证类型设置认证信息
        if params[:type] == 'SSH'
          if params[:auth_type] == 'key' && params[:ssh_key_path]
            resource_params[:ssh_key_path] = params[:ssh_key_path]
            resource_params[:password] = nil # 确保密码为空
          elsif params[:auth_type] != 'key' && params[:password]
            resource_params[:password] = params[:password]
            resource_params[:ssh_key_path] = nil # 确保密钥路径为空
          end
        elsif ['Windows', 'Linux'].include?(params[:type]) && params[:password]
          resource_params[:password] = params[:password]
          resource_params[:ssh_key_path] = nil # 确保密钥路径为空
        end
        
        # 创建资源
        resource = Resource.create(resource_params)
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '资源创建成功'
          redirect '/resources'
        else
          json_response({ success: true, message: '资源创建成功', resource: resource.values })
        end
      rescue Sequel::ValidationFailed => e
        error_messages = e.errors.full_messages.join(', ')
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "创建失败: #{error_messages}"
          redirect '/resources'
        else
          json_response({ success: false, error: "创建失败: #{error_messages}" }, 400)
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "创建失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "创建失败: #{e.message}" }, 500)
        end
      end
    end
    
    delete '/resources/:id' do
      require_login
      begin
        resource = Resource[params[:id]]
        if resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        # 检查资源是否属于当前用户（或用户是管理员）
        # 注意：资源可能没有直接的用户关联，这里简化处理
        if !current_user.admin?
          # 如果需要更严格的权限控制，可以在这里添加检查
        end
        
        # 删除资源
        resource.destroy
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '资源删除成功'
          redirect '/resources'
        else
          json_response({ success: true, message: '资源删除成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "删除失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "删除失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 资源编辑表单路由
    get '/resources/:id/edit' do
      require_login
      begin
        @resource = Resource[params[:id]]
        if @resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          haml :resource_form
        else
          json_response({ success: true, resource: @resource.values })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "获取资源信息失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "获取资源信息失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 更新资源路由
    put '/resources/:id' do
      require_login
      begin
        resource = Resource[params[:id]]
        if resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        # 准备更新参数
        update_params = {
          name: params[:name],
          host: params[:host],
          port: params[:port],
          username: params[:username],
          os_type: params[:os_type] || 'Linux'
        }
        
        # 根据资源类型和认证类型设置认证信息
        if resource.type == 'SSH'
          if params[:auth_type] == 'key' && params[:ssh_key_path]
            update_params[:ssh_key_path] = params[:ssh_key_path]
            update_params[:password] = nil # 清除密码
          elsif params[:auth_type] != 'key' && params[:password]
            update_params[:password] = params[:password]
            update_params[:ssh_key_path] = nil # 清除密钥路径
          end
        elsif resource.type == 'Windows' && params[:password]
          update_params[:password] = params[:password]
        end
        
        # 更新资源
        resource.update(update_params)
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '资源更新成功'
          redirect "/resources/#{resource.id}"
        else
          json_response({ success: true, message: '资源更新成功', resource: resource.values })
        end
      rescue Sequel::ValidationFailed => e
        error_messages = e.errors.full_messages.join(', ')
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "更新失败: #{error_messages}"
          redirect "/resources/#{params[:id]}/edit"
        else
          json_response({ success: false, error: "更新失败: #{error_messages}" }, 400)
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "更新失败: #{e.message}"
          redirect "/resources/#{params[:id]}/edit"
        else
          json_response({ success: false, error: "更新失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 测试资源连接路由
    post '/resources/:id/test_connection' do
      require_login
      begin
        resource = Resource[params[:id]]
        if resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        # 执行连接测试
        test_result = false
        test_message = ""
        
        begin
          case resource.type
          when 'SSH'
            # SSH连接测试
            if (resource.ssh_key_path && !resource.ssh_key_path.empty?) || (resource.password && !resource.password.empty?)
              test_message = resource.ssh_key_path ? "使用密钥认证测试SSH连接" : "使用密码认证测试SSH连接"
              
              # 实际测试SSH连接
              resource.ssh_connect do |ssh|
                output = ssh.exec!("echo 'Connection successful'")
                test_result = output.include?('Connection successful')
              end
              
              test_message = test_result ? "SSH连接测试成功" : "SSH连接测试失败"
            else
              raise "没有提供有效的认证信息"
            end
            
          when 'Windows'
            # Windows连接测试（这里简化处理，实际应使用WinRM等）
            if resource.username && resource.password
              test_result = resource.check_connectivity
              test_message = test_result ? "Windows连接测试成功" : "Windows连接测试失败"
            else
              raise "Windows资源需要提供用户名和密码"
            end
            
          when 'Docker'
            # Docker连接测试（简化处理）
            test_result = resource.check_connectivity
            test_message = test_result ? "Docker连接测试成功" : "Docker连接测试失败"
            
          when 'Kubernetes'
            # Kubernetes连接测试（简化处理）
            test_result = resource.check_connectivity
            test_message = test_result ? "Kubernetes连接测试成功" : "Kubernetes连接测试失败"
            
          else
            # 默认TCP连接测试
            test_result = resource.check_connectivity
            test_message = test_result ? "TCP连接测试成功" : "TCP连接测试失败"
          end
          
          # 更新资源状态
          status = test_result ? 'online' : 'offline'
          resource.update(status: status, last_check: Time.now)
          
        rescue => e
          test_result = false
          test_message = "连接测试失败: #{e.message}"
          # 更新资源状态为离线
          resource.update(status: 'offline', last_check: Time.now)
        end
        
        if test_result
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:success] = test_message
            redirect '/resources'
          else
            json_response({ success: true, message: test_message, status: 'online' })
          end
        else
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = test_message
            redirect '/resources'
          else
            json_response({ success: false, error: test_message, status: 'offline' }, 500)
          end
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "测试失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "测试失败: #{e.message}" }, 500)
        end
      end
    end
    
    # 连接资源终端路由
    post '/resources/:id/connect_terminal' do
      require_login
      begin
        resource = Resource[params[:id]]
        if resource.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源不存在'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源不存在' }, 404)
          end
        end
        
        # 检查资源是否有认证信息
        has_auth_info = false
        case resource.type
        when 'SSH'
          has_auth_info = (resource.ssh_key_path && !resource.ssh_key_path.empty?) || (resource.password && !resource.password.empty?)
        when 'Windows'
          has_auth_info = resource.username && resource.password
        else
          has_auth_info = true # 其他类型资源默认可以连接
        end
        
        unless has_auth_info
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '资源缺少认证信息，请先配置认证信息'
            redirect '/resources'
          else
            json_response({ success: false, error: '资源缺少认证信息，请先配置认证信息' }, 400)
          end
        end
        
        # 模拟终端连接过程
        # 在实际应用中，这里应该包含真实的终端连接逻辑
        # 比如建立 WebSocket 连接、SSH 终端会话等
        
        connection_info = ""
        case resource.type
        when 'SSH'
          auth_method = resource.ssh_key_path && !resource.ssh_key_path.empty? ? "密钥认证" : "密码认证"
          connection_info = "SSH连接到 #{resource.host}:#{resource.port || 22} (#{auth_method})"
        when 'Windows'
          connection_info = "WinRM连接到 #{resource.host}:#{resource.port || 5985}"
        when 'Docker'
          connection_info = "Docker连接到 #{resource.host}:#{resource.port || 2376}"
        when 'Kubernetes'
          connection_info = "Kubernetes连接到 #{resource.host}"
        else
          connection_info = "TCP连接到 #{resource.host}:#{resource.port || 80}"
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = "终端连接成功: #{connection_info}"
          redirect "/resources/#{resource.id}"
        else
          json_response({ 
            success: true, 
            message: "已连接到 #{resource.name}",
            connection_info: connection_info,
            resource: resource.values
          })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "连接失败: #{e.message}"
          redirect '/resources'
        else
          json_response({ success: false, error: "连接失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/scripts' do
      require_login
      if defined?(Script)
        @scripts = Script.all
        haml :scripts
      else
        halt 404, '脚本管理功能不可用'
      end
    end
    
    post '/scripts' do
      require_login
      begin
        script = Script.create(
          name: params[:name],
          script_type: params[:script_type],
          description: params[:description],
          content: params[:content]
        )
        
        redirect '/scripts'
      rescue => e
        redirect '/scripts'
      end
    end
    
    delete '/scripts/:id' do
      require_login
      begin
        script = Script[params[:id]]
        if script.nil?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '脚本不存在'
            redirect '/scripts'
          else
            json_response({ success: false, error: '脚本不存在' }, 404)
          end
        end
        
        # 检查脚本是否属于当前用户（或用户是管理员）
        # 注意：脚本可能没有直接的用户关联，这里简化处理
        if !current_user.admin?
          # 如果需要更严格的权限控制，可以在这里添加检查
        end
        
        # 删除脚本
        script.destroy
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '脚本删除成功'
          redirect '/scripts'
        else
          json_response({ success: true, message: '脚本删除成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "删除失败: #{e.message}"
          redirect '/scripts'
        else
          json_response({ success: false, error: "删除失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/plugins' do
      require_login
      haml :plugins
    end
    
    post '/plugins' do
      require_login
      # 这里应该处理插件上传和安装的逻辑
      # 由于插件系统较为复杂，这里仅做示例
      begin
        # 模拟插件安装过程
        plugin_name = params[:plugin_name] || "新插件"
        redirect '/plugins'
      rescue => e
        redirect '/plugins'
      end
    end
    
    delete '/plugins/:id' do
      require_login
      begin
        # 这里应该根据实际情况查找插件
        # 由于插件系统可能有不同的实现方式，这里简化处理
        if defined?(Plugin)
          plugin = Plugin[params[:id]]
          if plugin.nil?
            if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
              flash[:error] = '插件不存在'
              redirect '/plugins'
            else
              json_response({ success: false, error: '插件不存在' }, 404)
            end
          end
        end
        
        # 检查权限
        if !current_user.admin?
          if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
            flash[:error] = '权限不足'
            redirect '/plugins'
          else
            json_response({ success: false, error: '权限不足' }, 403)
          end
        end
        
        # 删除插件（模拟）
        # 实际应用中，这里应该有真正的插件卸载逻辑
        if defined?(Plugin)
          plugin.destroy
        end
        
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:success] = '插件卸载成功'
          redirect '/plugins'
        else
          json_response({ success: true, message: '插件卸载成功' })
        end
      rescue => e
        if defined?(Haml) && ENV['CICD_MODE'] == 'full' && request.xhr? == false
          flash[:error] = "卸载失败: #{e.message}"
          redirect '/plugins'
        else
          json_response({ success: false, error: "卸载失败: #{e.message}" }, 500)
        end
      end
    end
    
    get '/system' do
      require_admin
      haml :system
    end
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
puts "API文档: http://localhost:4567/api/docs"
puts "健康检查: http://localhost:4567/api/health"
puts ""
puts "默认账户:"
puts "  用户名: admin"
puts "  密码: admin123"
puts ""
puts "可用API:"
puts "  GET  /api/health     - 系统健康检查"
puts "  GET  /api/version    - 系统版本信息"
puts "================================="

# 运行应用
if __FILE__ == $0
  CicdApp.run!
end