# frozen_string_literal: true

class Resource < Sequel::Model(:resources)
  def expired?
    expired_at < Time.now
  end
end
