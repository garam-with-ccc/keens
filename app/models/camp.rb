class Camp < ApplicationRecord
  belongs_to :organizer, class_name: "User"

  has_many :camp_sessions, dependent: :destroy
  has_many :session_assignments, through: :camp_sessions
  has_many :assigned_writers, -> { distinct }, through: :session_assignments, source: :writer

  has_many :memberships, class_name: "CampMembership", dependent: :destroy
  has_many :roster_writers, -> { order(:email) }, through: :memberships, source: :user

  has_many :writer_invites, dependent: :destroy

  validates :name, presence: true
  validates :start_date, :end_date, presence: true
  validate :end_date_on_or_after_start_date

  scope :upcoming, -> { where("end_date >= ?", Date.current).order(:start_date) }
  scope :recent, -> { order(start_date: :desc) }

  def length_in_days
    (end_date - start_date).to_i + 1
  end

  # Roster = explicit memberships ∪ writers assigned to any session on this camp.
  # Falling back to assigned writers keeps the historical session-based roster
  # working until every camp has explicit memberships.
  def roster
    User.where(id: roster_writers.pluck(:id) | assigned_writers.pluck(:id))
      .order(:email)
  end

  def member?(user)
    return false if user.nil?

    memberships.exists?(user_id: user.id) ||
      session_assignments.exists?(writer_id: user.id) ||
      organizer_id == user.id
  end

  private

  def end_date_on_or_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end
end
