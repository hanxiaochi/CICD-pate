# 权限中间件
class PermissionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # 跳过静态资源和公开页面
    if skip_permission_check?(request.path)
      return @app.call(env)
    end
    
    # 检查会话状态
    session = env['rack.session']
    user_id = session[:user_id] if session
    
    # API请求的特殊处理
    if api_request?(request.path)
      return handle_api_permission(env, user_id)
    end
    
    # 管理员页面权限检查
    if admin_required?(request.path) && !user_is_admin?(user_id)
      return unauthorized_response
    end
    
    @app.call(env)
  end

  private

  def skip_permission_check?(path)
    skip_paths = [
      '/login',
      '/logout',
      '/api/version',
      '/api/health',
      '/public',
      '/css',
      '/js',
      '/images'
    ]
    
    skip_paths.any? { |skip_path| path.start_with?(skip_path) }
  end

  def api_request?(path)
    path.start_with?('/api/')
  end

  def admin_required?(path)
    admin_paths = [
      '/system',
      '/api/system'
    ]
    
    admin_paths.any? { |admin_path| path.start_with?(admin_path) }
  end

  def handle_api_permission(env, user_id)
    request = Rack::Request.new(env)
    
    # 某些API端点需要登录
    protected_api_paths = [
      '/api/stats',
      '/api/monitor',
      '/api/user'
    ]
    
    if protected_api_paths.any? { |protected_path| request.path.start_with?(protected_path) }
      unless user_id
        return json_unauthorized_response
      end
    end
    
    @app.call(env)
  end

  def user_is_admin?(user_id)
    return false unless user_id
    
    begin
      user = User[user_id] if defined?(User)
      user&.admin?
    rescue => e
      puts "权限检查失败: #{e.message}"
      false
    end
  end

  def unauthorized_response
    [302, {'Location' => '/login'}, ['Redirecting to login']]
  end

  def json_unauthorized_response
    [401, 
     {'Content-Type' => 'application/json'}, 
     [{ success: false, message: '需要登录' }.to_json]]
  end
end