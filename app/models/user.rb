class User < ApplicationRecord
  ROLES = %w[organizer writer observer].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  has_many :organized_camps, class_name: "Camp", foreign_key: :organizer_id, dependent: :destroy
  has_many :session_assignments, foreign_key: :writer_id, dependent: :destroy
  has_many :assigned_camp_sessions, through: :session_assignments, source: :camp_session
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
end
