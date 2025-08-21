# app/services/stats/backfill_player_stats.rb
module Stats
  class BackfillPlayerStats
    def initialize(season: nil)
      @season = season
    end

    def call
      Player.find_each do |player|
        attrs    = Calculator.new(player: player, season: @season).call
        scope_id = @season&.id
        existing = PlayerStat.find_by(player_id: player.id, season_id: scope_id)

        if attrs[:total_matches].to_i.zero?
          # We do not create "empty" rows. We only update if there was already one.
          next unless existing
          existing.update!(attrs)
        else
          (existing || PlayerStat.new(player_id: player.id, season_id: scope_id)).update!(attrs)
        end
      end
    end
  end
end
