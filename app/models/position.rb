# app/models/position.rb
class Position < ApplicationRecord
  has_many :player_positions, dependent: :destroy
  has_many :players, through: :player_positions

  validates :key,  presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:sort_order, :name) }
end

# app/models/player_position.rb
class PlayerPosition < ApplicationRecord
  belongs_to :player
  belongs_to :position
end

# app/models/player.rb
class Player < ApplicationRecord
  has_many :player_positions, dependent: :destroy
  has_many :positions, through: :player_positions

  def primary_position
    player_positions.find_by(primary: true)&.position
  end
end
