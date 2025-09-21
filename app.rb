# --- 配置和初始化 ---
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'git'
require 'net/sftp'
require 'net/ssh'
require 'fileutils'
require 'json'
require 'time'

# 读取配置文件
def load_config
  config_path = File.join(File.dirname(__FILE__), 'config.json')
  if File.exist?(config_path)
    JSON.parse(File.read(config_path))
  else
    {
      "ssh_default_port" => 22,
      "app_port" => 4567,
      "log_level" => "info",
      "temp_dir" => "./tmp",
      "docker_support" => true
    }
  end
end

CONFIG = load_config

# 配置Sinatra应用
configure do
  set :bind, '0.0.0.0'
  set :port, CONFIG['app_port'] || 4567
  set :views, './views'
  set :public_folder, './public'
  enable :sessions
  set :session_secret, 'cicd_tools_secret_key'

  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

# 初始化数据库
DB = Sequel.sqlite('cicd.db')

# 确保必要的数据库表存在
unless DB.table_exists?(:projects)
  DB.create_table :projects do
    primary_key :id
    String :name, :unique => true, :null => false
    String :repo_type, :null => false
    String :repo_url, :null => false
    String :branch, :default => 'master'
    String :build_script
    String :artifact_path
    String :deploy_server
    String :deploy_path
    String :start_script
    String :backup_path
    String :start_mode, :default => 'default'
    String :stop_mode, :default => 'sh_script'
    String :docker_compose_file, :default => ''
    String :start_type, :default => 'script_path'
    Time :created_at, :default => Time.now
    Time :updated_at, :default => Time.now
  end
end

unless DB.table_exists?(:deployments)
  DB.create_table :deployments do
    primary_key :id
    foreign_key :project_id, :projects, :null => false
    String :version
    String :status, :default => 'pending'
    String :backup_file
    Time :deployed_at
    String :deploy_user
    Text :log
  end
end

unless DB.table_exists?(:users)
  DB.create_table :users do
    primary_key :id
    String :username, :unique => true, :null => false
    String :password_hash, :null => false
    String :role, :default => 'user'
    Time :created_at, :default => Time.now
  end
  password_hash = BCrypt::Password.create('admin123')
  DB[:users].insert(:username => 'admin', :password_hash => password_hash, :role => 'admin')
end

# --- 模型定义 ---
class Project < Sequel::Model(:projects)
  one_to_many :deployments
  def before_save
    self.updated_at = Time.now
    super
  end
end

class Deployment < Sequel::Model(:deployments)
  many_to_one :project
end

class User < Sequel::Model(:users)
  def authenticate(password)
    BCrypt::Password.new(password_hash) == password
  end
end

# --- 辅助方法 ---
helpers do
  def current_user
    if session[:user_id]
      @current_user ||= User[session[:user_id]]
    end
  end

  def login_required
    unless current_user
      session[:redirect_to] = request.path_info
      flash[:error] = '请先登录'
      redirect '/login'
    end
  end

  def admin_required
    unless current_user && current_user.role == 'admin'
      flash[:error] = '需要管理员权限'
      redirect '/'
    end
  end

  def execute_command(cmd)
    output = `#{cmd} 2>&1`
    { :output => output, :success => $?.success? }
  end
end

# --- 路由定义 ---

## 用户认证相关路由
get '/login' do
  haml :login
end

post '/login' do
  user = User.find(:username => params[:username])
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id
    redirect session[:redirect_to] || '/'
  else
    flash[:error] = '用户名或密码错误'
    redirect '/login'
  end
end

get '/logout' do
  session.clear
  flash[:success] = '已成功退出登录'
  redirect '/login'
end

## 项目管理相关路由
get '/projects/new' do
  login_required
  @project = Project.new
  haml :project_form
end

post '/projects' do
  login_required
  # 处理项目创建逻辑
end

get '/projects/:id/edit' do
  login_required
  @project = Project[params[:id]]
  haml :project_form
end

post '/projects/:id' do
  login_required
  # 处理项目更新逻辑
end

get '/projects/:id/delete' do
  login_required
  # 处理项目删除逻辑
end

## 部署管理相关路由
get '/projects/:id/deploy' do
  login_required
  @project = Project[params[:id]]
  haml :deploy
end

post '/projects/:id/deploy' do
  login_required
  # 处理部署逻辑
end

## Docker操作相关路由
get '/projects/:id/docker/start' do
  login_required
  # 处理Docker启动逻辑
end

get '/projects/:id/docker/stop' do
  login_required
  # 处理Docker停止逻辑
end

get '/projects/:id/docker/restart' do
  login_required
  # 处理Docker重启逻辑
end

# --- 创建所需目录 ---
required_dirs = ['./views', './public', './tmp']
required_dirs.each do |dir|
  FileUtils.mkdir_p(dir) unless File.directory?(dir)
end      deploy_basename = File.basename(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')            ssh.exec!("tar -czf #{escaped_pre_rollback_path} -C #{deploy_dirname} #{deploy_basename}")      log << "回滚前备份: #{pre_rollback_path}"            # 停止应用      if project.start_script && !project.start_script.empty?        log << "根据停止模式停止应用"        if project.stop_mode == 'kill_process'          # 查找并杀死相关进程          if project.start_script.include?('/')            script_name = File.basename(project.start_script)            kill_command = "pgrep -f #{script_name} | xargs kill -9 2>/dev/null || echo 'No process found'"          else            kill_command = "pgrep -f #{project.start_script} | xargs kill -9 2>/dev/null || echo 'No process found'"          end          log << "执行进程杀死命令: #{kill_command}"          result = ssh.exec!(kill_command)          log << "进程杀死结果: #{result}"        else          # 使用sh脚本停止          # 简单处理：如果启动脚本包含start关键字，可以尝试替换为stop          stop_script = project.start_script.gsub('start', 'stop')          log << "执行停止脚本: #{stop_script}"          result = ssh.exec!(stop_script)          log << "应用已停止: #{result}"        end      end            # 解压备份文件到部署目录 - Linux路径处理      log << "解压备份文件到部署目录"      # 转义路径中的特殊字符      escaped_deploy_path = project.deploy_path.gsub(/([\s\'\"])/, '\\\\\1')      escaped_backup_path = backup_path.gsub(/([\s\'\"])/, '\\\\\1')      deploy_dirname = File.dirname(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')            ssh.exec!("rm -rf #{escaped_deploy_path}/*")      ssh.exec!("tar -xzf #{escaped_backup_path} -C #{deploy_dirname}")      log << "备份文件解压成功"            # 重启应用 - 根据启动类型和启动模式执行      if project.start_script && !project.start_script.empty?        log << "执行启动命令: #{project.start_script}"                # 转义命令中的特殊字符        escaped_start_script = project.start_script.gsub(/([\s\'\"])/, '\\\\\1')                # 根据启动类型和启动模式执行不同的命令        if project.start_type == 'script_path' && project.start_mode == 'nohup' && project.start_script.end_with?('.sh')          # 使用nohup启动脚本          start_command = "nohup #{escaped_start_script} > /dev/null 2>&1 &"          log << "使用nohup模式启动服务: #{start_command}"          result = ssh.exec!(start_command)          log << "nohup启动结果: #{result}"        else          # 默认直接执行命令          result = ssh.exec!(escaped_start_script)          log << "启动命令执行结果: #{result}"        end      end            # 如果配置了Docker Compose文件，使用docker-compose启动      if project.docker_compose_file && !project.docker_compose_file.empty?        log << "使用Docker Compose启动服务: #{project.docker_compose_file}"                # 转义部署路径中的特殊字符        escaped_deploy_path = project.deploy_path.gsub(/([\s\'"])/, '\\\\\\1')        docker_compose_file = project.docker_compose_file.gsub(/([\s\'"])/, '\\\\\\1')                # 执行docker-compose up命令        compose_command = "cd #{escaped_deploy_path} && docker-compose -f #{docker_compose_file} up -d"        log << "执行Docker Compose命令: #{compose_command}"        result = ssh.exec!(compose_command)        log << "Docker Compose启动结果: #{result}"      end    end        # 更新部署状态    deployment.update(:status => 'success', :deployed_at => Time.now, :log => log.join('\n'))    flash[:success] = '回滚成功'  rescue => e    log << "回滚失败: #{e.message}"    log << e.backtrace.join('\n')    deployment.update(:status => 'failed', :log => log.join('\n'))    flash[:error] = "回滚失败: #{e.message}"  ensure    redirect '/'  endend# 部署历史路由get '/projects/:id/history' do  login_required  @project = Project[params[:id]]  @deployments = @project.deployments.order(Sequel.desc(:deployed_at))  haml :historyendget '/projects/:id/history/:deployment_id' do  login_required  @deployment = Deployment[params[:deployment_id]]  @project = @deployment.project  haml :deployment_detailend# Docker相关操作路由get '/projects/:id/docker/start' do  login_required  project = Project[params[:id]]  log = []    begin    log << "开始启动Docker服务"        # 解析服务器信息    server_info = project.deploy_server.match(/^(?:(\w+)@)?([\[\w\.-]+)(?::(\d+))?$/)    user = server_info[1] || 'root'    host = server_info[2]    port = server_info[3] ? server_info[3].to_i : (CONFIG['ssh_default_port'] || 22)        # 连接服务器并执行Docker操作    Net::SSH.start(host, user, :port => port) do |ssh|      # 启动Docker服务      result = ssh.exec!("systemctl start docker")      log << "Docker服务启动结果: #{result}"            # 如果配置了Docker Compose文件，使用docker-compose启动      if project.docker_compose_file && !project.docker_compose_file.empty?        log << "使用Docker Compose启动应用: #{project.docker_compose_file}"                # 转义部署路径中的特殊字符        escaped_deploy_path = project.deploy_path.gsub(/([\s\'"])/, '\\\\\\1')        docker_compose_file = project.docker_compose_file.gsub(/([\s\'"])/, '\\\\\\1')                # 执行docker-compose up命令        compose_command = "cd #{escaped_deploy_path} && docker-compose -f #{docker_compose_file} up -d"        log << "执行Docker Compose命令: #{compose_command}"        result = ssh.exec!(compose_command)        log << "Docker Compose启动结果: #{result}"      end    end        flash[:success] = "Docker服务和应用已成功启动"  rescue => e    log << "Docker启动失败: #{e.message}"    log << e.backtrace.join('\n')    flash[:error] = "Docker启动失败: #{e.message}"  ensure    redirect "/projects/#{project.id}/deploy"  endendget '/projects/:id/docker/stop' do  login_required  project = Project[params[:id]]  log = []    begin    log << "开始停止Docker服务"        # 解析服务器信息    server_info = project.deploy_server.match(/^(?:(\w+)@)?([\[\w\.-]+)(?::(\d+))?$/)    user = server_info[1] || 'root'    host = server_info[2]    port = server_info[3] ? server_info[3].to_i : (CONFIG['ssh_default_port'] || 22)        # 连接服务器并执行Docker操作    Net::SSH.start(host, user, :port => port) do |ssh|      # 如果配置了Docker Compose文件，使用docker-compose停止      if project.docker_compose_file && !project.docker_compose_file.empty?        log << "使用Docker Compose停止应用: #{project.docker_compose_file}"                # 转义部署路径中的特殊字符        escaped_deploy_path = project.deploy_path.gsub(/([\s\'"])/, '\\\\\\1')        docker_compose_file = project.docker_compose_file.gsub(/([\s\'"])/, '\\\\\\1')                # 执行docker-compose down命令        compose_command = "cd #{escaped_deploy_path} && docker-compose -f #{docker_compose_file} down"        log << "执行Docker Compose命令: #{compose_command}"        result = ssh.exec!(compose_command)        log << "Docker Compose停止结果: #{result}"      end    end        flash[:success] = "Docker应用已成功停止"  rescue => e    log << "Docker停止失败: #{e.message}"    log << e.backtrace.join('\n')    flash[:error] = "Docker停止失败: #{e.message}"  ensure    redirect "/projects/#{project.id}/deploy"  endendget '/projects/:id/docker/restart' do  login_required  project = Project[params[:id]]  log = []    begin    log << "开始重启Docker服务"        # 解析服务器信息    server_info = project.deploy_server.match(/^(?:(\w+)@)?([\[\w\.-]+)(?::(\d+))?$/)    user = server_info[1] || 'root'    host = server_info[2]    port = server_info[3] ? server_info[3].to_i : (CONFIG['ssh_default_port'] || 22)        # 连接服务器并执行Docker操作    Net::SSH.start(host, user, :port => port) do |ssh|      # 重启Docker服务      result = ssh.exec!("systemctl restart docker")      log << "Docker服务重启结果: #{result}"            # 如果配置了Docker Compose文件，使用docker-compose重启      if project.docker_compose_file && !project.docker_compose_file.empty?        log << "使用Docker Compose重启应用: #{project.docker_compose_file}"                # 转义部署路径中的特殊字符        escaped_deploy_path = project.deploy_path.gsub(/([\s\'"])/, '\\\\\\1')        docker_compose_file = project.docker_compose_file.gsub(/([\s\'"])/, '\\\\\\1')                # 执行docker-compose restart命令        compose_command = "cd #{escaped_deploy_path} && docker-compose -f #{docker_compose_file} restart"        log << "执行Docker Compose命令: #{compose_command}"        result = ssh.exec!(compose_command)        log << "Docker Compose重启结果: #{result}"      end    end        flash[:success] = "Docker服务和应用已成功重启"  rescue => e    log << "Docker重启失败: #{e.message}"    log << e.backtrace.join('\n')    flash[:error] = "Docker重启失败: #{e.message}"  ensure    redirect "/projects/#{project.id}/deploy"  endendget '/admin' do  login_required  admin_required # 限制管理员访问  @users = User.all  haml :adminend

post '/admin/users' do
  login_required
  admin_required
  User.create(
    username: params[:username],
    password_hash: BCrypt::Password.create(params[:password]),
    role: params[:role]
  )
  redirect '/admin'
end

# 创建所需目录 - 跨平台兼容
required_dirs = ['./views', './public', './tmp']
required_dirs.each do |dir|
  FileUtils.mkdir_p(dir) unless File.directory?(dir) # 修复 Dir.mkdir_p 为 FileUtils.mkdir_p
end