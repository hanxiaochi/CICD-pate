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

# 配置Sinatra应用
configure do
  set :bind, '0.0.0.0'  # 绑定到所有网络接口，便于在Linux服务器上访问
  set :port, 4567
  set :views, './views'
  set :public_folder, './public'
  enable :sessions
  set :session_secret, 'cicd_tools_secret_key'
  register Sinatra::Flash
  
  # 确保中文正常显示
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
    String :repo_type, :null => false # git or svn
    String :repo_url, :null => false
    String :branch, :default => 'master'
    String :build_script
    String :artifact_path
    String :deploy_server
    String :deploy_path
    String :start_script
    String :backup_path
    Time :created_at, :default => Time.now
    Time :updated_at, :default => Time.now
  end
end

unless DB.table_exists?(:deployments)
  DB.create_table :deployments do
    primary_key :id
    foreign_key :project_id, :projects, :null => false
    String :version
    String :status, :default => 'pending' # pending, success, failed
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
    String :role, :default => 'user' # admin, user
    Time :created_at, :default => Time.now
  end
  # 创建默认管理员用户
  password_hash = BCrypt::Password.create('admin123')
  DB[:users].insert(:username => 'admin', :password_hash => password_hash, :role => 'admin')
end

# 模型类
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

# 辅助方法
helpers do
  def current_user
    if session[:user_id]
      @current_user ||= User[session[:user_id]]
    end
  end
  
  def login_required
    unless current_user
      session[:redirect_to] = request.path_info
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

# 路由
get '/' do
  login_required
  @projects = Project.all
  haml :index
end

# 用户认证相关路由
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
  redirect '/login'
end

# 项目相关路由
get '/projects/new' do
  login_required
  @project = Project.new
  haml :project_form
end

post '/projects' do
  login_required
  begin
    project = Project.create(
      :name => params[:name],
      :repo_type => params[:repo_type],
      :repo_url => params[:repo_url],
      :branch => params[:branch],
      :build_script => params[:build_script],
      :artifact_path => params[:artifact_path],
      :deploy_server => params[:deploy_server],
      :deploy_path => params[:deploy_path],
      :start_script => params[:start_script],
      :backup_path => params[:backup_path]
    )
    flash[:success] = '项目创建成功'
    redirect '/'
  rescue Sequel::UniqueConstraintViolation
    flash[:error] = '项目名称已存在'
    redirect '/projects/new'
  rescue => e
    flash[:error] = "创建项目失败: #{e.message}"
    redirect '/projects/new'
  end
end

get '/projects/:id/edit' do
  login_required
  @project = Project[params[:id]]
  haml :project_form
end

post '/projects/:id' do
  login_required
  project = Project[params[:id]]
  begin
    project.update(
      :name => params[:name],
      :repo_type => params[:repo_type],
      :repo_url => params[:repo_url],
      :branch => params[:branch],
      :build_script => params[:build_script],
      :artifact_path => params[:artifact_path],
      :deploy_server => params[:deploy_server],
      :deploy_path => params[:deploy_path],
      :start_script => params[:start_script],
      :backup_path => params[:backup_path]
    )
    flash[:success] = '项目更新成功'
    redirect '/'
  rescue Sequel::UniqueConstraintViolation
    flash[:error] = '项目名称已存在'
    redirect "/projects/#{params[:id]}/edit"
  rescue => e
    flash[:error] = "更新项目失败: #{e.message}"
    redirect "/projects/#{params[:id]}/edit"
  end
end

get '/projects/:id/delete' do
  login_required
  project = Project[params[:id]]
  if project
    project.destroy
    flash[:success] = '项目删除成功'
  else
    flash[:error] = '项目不存在'
  end
  redirect '/'
end

# 部署相关路由
get '/projects/:id/deploy' do
  login_required
  @project = Project[params[:id]]
  haml :deploy
end

post '/projects/:id/deploy' do
  login_required
  project = Project[params[:id]]
  log = []
  
  begin
    # 创建临时目录 - Linux兼容路径
    temp_dir = File.join(".", "tmp", "#{project.name}_#{Time.now.to_i}")
    FileUtils.mkdir_p(temp_dir)
    log << "创建临时目录: #{temp_dir}"
    
    # 克隆代码库
    if project.repo_type == 'git'
      log << "开始克隆Git仓库: #{project.repo_url}"
      g = Git.clone(project.repo_url, temp_dir, :branch => project.branch)
      log << "Git仓库克隆成功"
    else
      log << "开始检出SVN仓库: #{project.repo_url}"
      result = execute_command("svn checkout #{project.repo_url} #{temp_dir} -r HEAD")
      if result[:success]
        log << "SVN仓库检出成功"
      else
        log << "SVN仓库检出失败: #{result[:output]}"
        raise "SVN检出失败"
      end
    end
    
    # 执行构建脚本
    if project.build_script && !project.build_script.empty?
      log << "开始执行构建脚本"
      result = execute_command("cd #{temp_dir} && #{project.build_script}")
      if result[:success]
        log << "构建成功: #{result[:output]}"
      else
        log << "构建失败: #{result[:output]}"
        raise "构建失败"
      end
    end
    
    # 创建部署记录
    deployment = Deployment.create(
      :project_id => project.id,
      :version => "#{Time.now.strftime('%Y%m%d%H%M%S')}",
      :status => 'pending',
      :deploy_user => current_user.username,
      :log => log.join('\n')
    )
    
    # 准备部署
    log << "准备部署到服务器: #{project.deploy_server}"
    
    # 解析服务器信息 (格式: user@host:port)
    server_info = project.deploy_server.match(/^(?:(\w+)@)?([\w\.-]+)(?::(\d+))?$/)
    user = server_info[1] || 'root'
    host = server_info[2]
    port = server_info[3] ? server_info[3].to_i : 22
    
    # 连接服务器并部署
    Net::SSH.start(host, user, :port => port) do |ssh|
      # 创建备份目录
      if project.backup_path && !project.backup_path.empty?
        # 创建备份目录 - Linux路径处理
        backup_dir = File.join(project.backup_path, project.name)
        # 转义路径中的空格和特殊字符
        escaped_backup_dir = backup_dir.gsub(/([\s\'\"])/, '\\\\\1')
        ssh.exec!("mkdir -p #{escaped_backup_dir}")
        log << "创建备份目录: #{backup_dir}"
        
        # 备份当前文件
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        backup_file = "#{project.name}_#{timestamp}.tar.gz"
        backup_path = File.join(backup_dir, backup_file)
        escaped_backup_path = backup_path.gsub(/([\s\'\"])/, '\\\\\1')
        
        # 检查部署目录是否存在 - Linux路径处理
        escaped_deploy_path = project.deploy_path.gsub(/([\s\'\"])/, '\\\\\1')
        deploy_path_exists = ssh.exec!("if [ -d '#{escaped_deploy_path}' ]; then echo 'exists'; else echo 'not_exists'; fi").strip
        
        if deploy_path_exists == 'exists'
          # 转义目录名中的特殊字符
          deploy_dirname = File.dirname(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')
          deploy_basename = File.basename(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')
          ssh.exec!("tar -czf #{escaped_backup_path} -C #{deploy_dirname} #{deploy_basename}")
          log << "备份成功: #{backup_path}"
          deployment.update(:backup_file => backup_file)
        else
          log << "部署目录不存在，跳过备份"
        end
      end
      
      # 创建部署目录 - Linux路径处理
        escaped_deploy_path = project.deploy_path.gsub(/([\s\'\"])/, '\\\\\1')
        ssh.exec!("mkdir -p #{escaped_deploy_path}")
        log << "创建部署目录: #{project.deploy_path}"
      
      # 上传构建产物 - Linux路径处理
        if project.artifact_path && !project.artifact_path.empty?
          artifact_full_path = File.join(temp_dir, project.artifact_path)
          if File.exist?(artifact_full_path)
            log << "上传构建产物: #{artifact_full_path}"
            
            # 使用SFTP上传文件
            ssh.sftp.connect do |sftp|
              remote_artifact_path = File.join(project.deploy_path, File.basename(artifact_full_path))
              sftp.upload!(artifact_full_path, remote_artifact_path)
              log << "文件上传成功"
            end
            
            # 如果是压缩文件，解压缩 - Linux路径处理
            escaped_deploy_path = project.deploy_path.gsub(/([\s\'\"])/, '\\\\\1')
            artifact_basename = File.basename(artifact_full_path).gsub(/([\s\'\"])/, '\\\\\1')
            
            if artifact_full_path.end_with?('.tar.gz', '.tgz')
              ssh.exec!("cd #{escaped_deploy_path} && tar -xzf #{artifact_basename}")
              log << "文件解压成功"
            elsif artifact_full_path.end_with?('.zip')
              ssh.exec!("cd #{escaped_deploy_path} && unzip -o #{artifact_basename}")
              log << "文件解压成功"
            end
          else
            log << "构建产物不存在: #{artifact_full_path}"
            raise "构建产物不存在"
          end
        else
        # 如果没有指定构建产物路径，则上传整个临时目录
        log << "上传整个目录"
        Dir.glob(File.join(temp_dir, '*')).each do |file|
          next if File.basename(file) == '.git' || File.basename(file) == '.svn'
          
          ssh.sftp.connect do |sftp|
            if File.directory?(file)
              remote_dir = File.join(project.deploy_path, File.basename(file))
              ssh.exec!("mkdir -p #{remote_dir}")
              sftp.upload!(file, remote_dir, :recursive => true)
            else
              sftp.upload!(file, File.join(project.deploy_path, File.basename(file)))
            end
          end
        end
        log << "目录上传成功"
      end
      
      # 执行启动脚本 - Linux路径处理
      if project.start_script && !project.start_script.empty?
        log << "执行启动脚本: #{project.start_script}"
        # 在Linux上执行脚本时需要确保脚本有执行权限
        result = ssh.exec!(project.start_script)
        log << "启动脚本执行结果: #{result}"
      end
    end
    
    # 更新部署状态
    deployment.update(:status => 'success', :deployed_at => Time.now, :log => log.join('\n'))
    flash[:success] = '部署成功'
  rescue => e
    log << "部署失败: #{e.message}"
    log << e.backtrace.join('\n')
    if defined?(deployment) && deployment
      deployment.update(:status => 'failed', :log => log.join('\n'))
    end
    flash[:error] = "部署失败: #{e.message}"
  ensure
    # 清理临时目录
    if defined?(temp_dir) && File.exist?(temp_dir)
      FileUtils.rm_rf(temp_dir)
      log << "清理临时目录"
    end
    redirect '/'
  end
end

# 备份和回滚路由
get '/projects/:id/backups' do
  login_required
  @project = Project[params[:id]]
  if @project.backup_path && !@project.backup_path.empty?
    begin
      # 解析服务器信息
      server_info = @project.deploy_server.match(/^(?:(\w+)@)?([\w\.-]+)(?::(\d+))?$/)
      user = server_info[1] || 'root'
      host = server_info[2]
      port = server_info[3] ? server_info[3].to_i : 22
      
      # 获取备份文件列表
      backup_dir = File.join(@project.backup_path, @project.name)
      Net::SSH.start(host, user, :port => port) do |ssh|
        result = ssh.exec!("ls -la #{backup_dir}/*.tar.gz 2>/dev/null || echo 'no backups'")
        if result.strip != 'no backups'
          @backups = []
          result.each_line do |line|
            if line.match(/^\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\w+\s+\d+\s+\d+:\d+)\s+(.+\.tar\.gz)$/)
              date_str = $1
              file_name = $2
              # 尝试解析备份文件中的时间戳
              timestamp_match = file_name.match(/#{@project.name}_(\d{14})\.tar\.gz/)
              if timestamp_match
                timestamp = Time.strptime(timestamp_match[1], '%Y%m%d%H%M%S')
              else
                # 如果无法解析时间戳，使用默认时间
                timestamp = Time.parse(date_str)
              end
              @backups << { :file_name => file_name, :timestamp => timestamp }
            end
          end
          # 按时间倒序排列
          @backups.sort_by! { |b| -b[:timestamp].to_i }
        else
          @backups = []
          flash[:info] = '暂无备份文件'
        end
      end
    rescue => e
      flash[:error] = "获取备份列表失败: #{e.message}"
      @backups = []
    end
  else
    flash[:info] = '未设置备份路径'
    @backups = []
  end
  haml :backups
end

get '/projects/:id/rollback/:backup_file' do
  login_required
  project = Project[params[:id]]
  backup_file = params[:backup_file]
  log = []
  
  begin
    # 创建回滚部署记录
    deployment = Deployment.create(
      :project_id => project.id,
      :version => "rollback_#{Time.now.strftime('%Y%m%d%H%M%S')}",
      :status => 'pending',
      :deploy_user => current_user.username,
      :backup_file => backup_file,
      :log => log.join('\n')
    )
    
    log << "开始回滚到备份: #{backup_file}"
    
    # 解析服务器信息
    server_info = project.deploy_server.match(/^(?:(\w+)@)?([\w\.-]+)(?::(\d+))?$/)
    user = server_info[1] || 'root'
    host = server_info[2]
    port = server_info[3] ? server_info[3].to_i : 22
    
    backup_dir = File.join(project.backup_path, project.name)
    backup_path = File.join(backup_dir, backup_file)
    
    # 连接服务器并执行回滚
    Net::SSH.start(host, user, :port => port) do |ssh|
      # 再次备份当前状态，以防回滚失败 - Linux路径处理
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      pre_rollback_backup = "#{project.name}_pre_rollback_#{timestamp}.tar.gz"
      pre_rollback_path = File.join(backup_dir, pre_rollback_backup)
      
      # 转义路径中的特殊字符
      escaped_pre_rollback_path = pre_rollback_path.gsub(/([\s\'\"])/, '\\\\\1')
      deploy_dirname = File.dirname(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')
      deploy_basename = File.basename(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')
      
      ssh.exec!("tar -czf #{escaped_pre_rollback_path} -C #{deploy_dirname} #{deploy_basename}")
      log << "回滚前备份: #{pre_rollback_path}"
      
      # 停止应用（如果有停止脚本）
      if project.start_script && !project.start_script.empty?
        # 简单处理：如果启动脚本包含start关键字，可以尝试替换为stop
        stop_script = project.start_script.gsub('start', 'stop')
        log << "执行停止脚本: #{stop_script}"
        ssh.exec!(stop_script)
        log << "应用已停止"
      end
      
      # 解压备份文件到部署目录 - Linux路径处理
      log << "解压备份文件到部署目录"
      # 转义路径中的特殊字符
      escaped_deploy_path = project.deploy_path.gsub(/([\s\'\"])/, '\\\\\1')
      escaped_backup_path = backup_path.gsub(/([\s\'\"])/, '\\\\\1')
      deploy_dirname = File.dirname(project.deploy_path).gsub(/([\s\'\"])/, '\\\\\1')
      
      ssh.exec!("rm -rf #{escaped_deploy_path}/*")
      ssh.exec!("tar -xzf #{escaped_backup_path} -C #{deploy_dirname}")
      log << "备份文件解压成功"
      
      # 重启应用 - Linux路径处理
      if project.start_script && !project.start_script.empty?
        log << "执行启动脚本: #{project.start_script}"
        # 在Linux上执行脚本时需要确保脚本有执行权限
        ssh.exec!(project.start_script)
        log << "应用已重启"
      end
    end
    
    # 更新部署状态
    deployment.update(:status => 'success', :deployed_at => Time.now, :log => log.join('\n'))
    flash[:success] = '回滚成功'
  rescue => e
    log << "回滚失败: #{e.message}"
    log << e.backtrace.join('\n')
    deployment.update(:status => 'failed', :log => log.join('\n'))
    flash[:error] = "回滚失败: #{e.message}"
  ensure
    redirect '/'
  end
end

# 部署历史路由
get '/projects/:id/history' do
  login_required
  @project = Project[params[:id]]
  @deployments = @project.deployments.order(Sequel.desc(:deployed_at))
  haml :history
end

get '/projects/:id/history/:deployment_id' do
  login_required
  @deployment = Deployment[params[:deployment_id]]
  @project = @deployment.project
  haml :deployment_detail
end

# 创建所需目录 - 跨平台兼容
required_dirs = ['./views', './public', './tmp']
required_dirs.each do |dir|
  Dir.mkdir_p(dir) unless File.directory?(dir)
end