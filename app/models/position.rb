# app/models/position.rb
class Position < ApplicationRecord
  has_many :player_positions, dependent: :destroy
  has_many :players, through: :player_positions

  validates :key,  presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:sort_order, :name) }
end
