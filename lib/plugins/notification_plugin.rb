# 通知插件
class NotificationPlugin
  def self.send_notification(type, message, options = {})
    begin
      case type.to_s
      when 'email'
        send_email_notification(message, options)
      when 'webhook'
        send_webhook_notification(message, options)
      when 'log'
        send_log_notification(message, options)
      else
        puts "[通知] #{message}"
      end
    rescue => e
      puts "发送通知失败: #{e.message}"
    end
  end

  def self.send_build_notification(build, status)
    message = "构建 ##{build.build_number} #{status}"
    
    send_notification('log', message, {
      project_id: build.project_id,
      build_id: build.id,
      status: status
    })
  end

  def self.send_deployment_notification(deployment, status)
    message = "部署到 #{deployment.environment} #{status}"
    
    send_notification('log', message, {
      project_id: deployment.project_id,
      deployment_id: deployment.id,
      status: status
    })
  end

  private

  def self.send_email_notification(message, options)
    # 邮件通知功能（待实现）
    puts "[邮件通知] #{message}"
  end

  def self.send_webhook_notification(message, options)
    # Webhook通知功能（待实现）
    puts "[Webhook通知] #{message}"
  end

  def self.send_log_notification(message, options)
    if defined?(LogService)
      LogService.log(
        type: 'notification',
        level: 'info',
        message: message,
        details: options
      )
    else
      puts "[日志通知] #{message}"
    end
  end
end