class CampSession < ApplicationRecord
  attr_accessor :writer_emails

  belongs_to :camp

  has_many :session_assignments, dependent: :destroy
  has_many :writers, through: :session_assignments

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_start

  scope :chronological, -> { order(:starts_at) }

  def display_title
    title.presence || default_title
  end

  private

  def default_title
    return "Session" if starts_at.blank?

    starts_at.strftime("%a %b %-d, %-I:%M %p")
  end

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
