class User < ApplicationRecord
  ROLES = %w[organizer writer observer].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  has_many :organized_camps, class_name: "Camp", foreign_key: :organizer_id, dependent: :destroy
  has_many :session_assignments, foreign_key: :writer_id, dependent: :destroy
  has_many :assigned_camp_sessions, through: :session_assignments, source: :camp_session
  has_many :camp_memberships, dependent: :destroy
  has_many :camps, through: :camp_memberships
  has_many :writer_invites, dependent: :destroy
  has_one :writer_profile, dependent: :destroy

  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ROLES }

  def organizer?
    role == "organizer"
  end

  def writer?
    role == "writer"
  end

  def display_name
    name.presence || email
  end

  # Returns every camp the user can see as a writer — explicit memberships and
  # any camp where they have at least one session assignment.
  def writer_camps
    Camp.where(id: camps.pluck(:id) | assigned_camp_sessions.pluck(:camp_id)).order(start_date: :asc)
  end

  def ensure_calendar_feed_token!
    return calendar_feed_token if calendar_feed_token.present?

    update!(calendar_feed_token: SecureRandom.urlsafe_base64(24))
    calendar_feed_token
  end
end
