# 部署模型
class Deployment < Sequel::Model
  plugin :timestamps, update_on_create: true
  many_to_one :project
  many_to_one :user
  many_to_one :build
  
  def to_hash
    {
      id: id,
      project_id: project_id,
      user_id: user_id,
      build_id: build_id,
      environment: environment,
      status: status,
      target_host: target_host,
      deployment_path: deployment_path,
      start_time: start_time,
      end_time: end_time,
      duration: duration,
      log_content: log_content,
      rollback_enabled: rollback_enabled,
      created_at: created_at,
      updated_at: updated_at
    }
  end
  
  def success?
    status == 'success'
  end
  
  def failed?
    status == 'failed'
  end
  
  def running?
    status == 'running'
  end
end