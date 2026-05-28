class Camp < ApplicationRecord
  belongs_to :organizer, class_name: "User"

  has_many :camp_sessions, dependent: :destroy
  has_many :session_assignments, through: :camp_sessions
  has_many :writers, -> { distinct }, through: :session_assignments

  validates :name, presence: true
  validates :start_date, :end_date, presence: true
  validate :end_date_on_or_after_start_date

  scope :upcoming, -> { where("end_date >= ?", Date.current).order(:start_date) }
  scope :recent, -> { order(start_date: :desc) }

  def length_in_days
    (end_date - start_date).to_i + 1
  end

  private

  def end_date_on_or_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end
end
