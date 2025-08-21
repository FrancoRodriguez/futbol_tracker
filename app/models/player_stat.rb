class PlayerStat < ApplicationRecord
  belongs_to :player
  belongs_to :season, optional: true

  scope :global, -> { where(season_id: nil) }

  def recalc_from_history!(season: nil)
    attrs = Stats::Calculator.new(player: player, season: season).call
    update!(attrs)
  end
end
