require "openssl"

class OrganizerInvite < ApplicationRecord
  DEFAULT_LIFETIME = 14.days

  belongs_to :user
  belongs_to :invited_by, class_name: "User"

  scope :live, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Issues a fresh organizer invite. Returns [invite, plaintext_token].
  # Plaintext is never persisted — only its SHA-256 digest is.
  def self.issue!(user:, invited_by:, lifetime: DEFAULT_LIFETIME)
    plaintext = SecureRandom.urlsafe_base64(32)
    record = create!(
      user: user,
      invited_by: invited_by,
      token_digest: digest(plaintext),
      expires_at: lifetime.from_now
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

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def accept!
    transaction do
      update!(accepted_at: Time.current)
      user.update!(role: "organizer") unless user.organizer?
    end
  end
end
