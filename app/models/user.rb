class User < ApplicationRecord
  ROLES = %w[organizer writer observer].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

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
