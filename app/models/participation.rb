class Participation < ApplicationRecord
  belongs_to :player
  belongs_to :match
  belongs_to :team

  validates :goals, numericality: { greater_than_or_equal_to: 0 }
  validates :assists, numericality: { greater_than_or_equal_to: 0 }
end
