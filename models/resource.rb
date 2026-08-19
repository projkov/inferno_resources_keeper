class Resource < Sequel::Model(:resources)
  def expired?
    expired_at < Time.now
  end
end
