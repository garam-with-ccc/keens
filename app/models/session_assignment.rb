class SessionAssignment < ApplicationRecord
  belongs_to :camp_session
  belongs_to :writer, class_name: "User"

  validates :writer_id, uniqueness: { scope: :camp_session_id }
end
