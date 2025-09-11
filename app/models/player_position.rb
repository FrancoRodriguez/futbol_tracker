class PlayerPosition < ApplicationRecord
  belongs_to :player
  belongs_to :position

  validate :only_one_primary, if: -> { primary? }

  private

  def only_one_primary
    exists = PlayerPosition.where(player_id: player_id, primary: true).where.not(id: id).exists?
    errors.add(:primary, "ya existe una posición principal") if exists
  end
end
