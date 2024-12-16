class Team < ApplicationRecord
  has_many :participations

  validates :name, presence: true, uniqueness: true
end
