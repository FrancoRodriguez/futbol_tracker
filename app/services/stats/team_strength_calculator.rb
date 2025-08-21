# Total eligible WRs per team in the match
module Stats
  class TeamStrengthCalculator
    # match: Match, winrate_map: {player_id=>{wr:,eligible:}}
    # Retorna { team_id => strength_float }
    def call(match:, winrate_map:)
      teams = [match.home_team, match.away_team].compact
      teams.index_with do |team|
        players = match.participations.includes(:player).where(team_id: team.id).map(&:player)
        players.sum do |pl|
          s = winrate_map[pl.id]
          (s && s[:eligible] && s[:wr]) ? s[:wr] : 0.0
        end
      end
    end
  end
end
