class CampMembership < ApplicationRecord
  belongs_to :camp
  belongs_to :user

  validates :user_id, uniqueness: { scope: :camp_id }
end
