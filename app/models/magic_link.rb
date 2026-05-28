require "openssl"

class MagicLink < ApplicationRecord
  DEFAULT_LIFETIME = 20.minutes

  belongs_to :user

  scope :live, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  # Issues a fresh magic-link record for the user and returns the plaintext
  # token. The plaintext is never persisted — only its SHA-256 digest is.
  def self.issue!(user:, lifetime: DEFAULT_LIFETIME, ip: nil, user_agent: nil)
    plaintext = SecureRandom.urlsafe_base64(32)
    record = create!(
      user: user,
      token_digest: digest(plaintext),
      expires_at: lifetime.from_now,
      requested_ip: ip,
      requested_user_agent: user_agent
    )
    [ record, plaintext ]
  end

  def self.find_live_by_token(plaintext)
    return nil if plaintext.blank?

    live.find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext.to_s)
  end

  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def consume!
    update!(consumed_at: Time.current)
  end
end
