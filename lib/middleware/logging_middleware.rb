# 日志中间件
class LoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.now
    request = Rack::Request.new(env)
    
    # 记录请求开始
    puts "[#{start_time.strftime('%Y-%m-%d %H:%M:%S')}] #{request.request_method} #{request.path}"
    
    status, headers, response = @app.call(env)
    
    # 计算响应时间
    duration = ((Time.now - start_time) * 1000).round(2)
    
    # 记录请求完成
    puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{status} - #{duration}ms"
    
    # 如果是生产环境，记录到日志文件
    if ENV['RACK_ENV'] == 'production'
      begin
        log_data = {
          method: request.request_method,
          path: request.path,
          status: status,
          duration: duration,
          ip: request.ip,
          user_agent: request.user_agent,
          timestamp: start_time
        }
        
        # 使用LogService记录访问日志
        if defined?(LogService)
          LogService.log(
            type: 'access',
            level: status >= 400 ? 'warning' : 'info',
            message: "#{request.request_method} #{request.path} - #{status}",
            ip_address: request.ip,
            details: log_data
          )
        end
      rescue => e
        puts "日志记录失败: #{e.message}"
      end
    end
    
    [status, headers, response]
  end
end