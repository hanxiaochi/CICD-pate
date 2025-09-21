# 权限模型
class Permission < Sequel::Model
  many_to_one :user
  many_to_one :workspace
  
  def to_hash
    {
      id: id,
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      permission_type: permission_type,
      granted: granted,
      granted_by: granted_by,
      granted_at: granted_at,
      expires_at: expires_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end
  
  def active?
    granted && (expires_at.nil? || expires_at > Time.now)
  end
  
  def expired?
    expires_at && expires_at <= Time.now
  end
end