# app/services/stats/team_strength_calculator.rb
module Stats
  class TeamStrengthCalculator
    def call(match:, winrate_map:)
      teams = [match.home_team, match.away_team].compact
      teams.each_with_object({}) do |team, h|
        players = match.participations.includes(:player)
                       .where(team_id: team.id).map(&:player)
        h[team.id] = players.sum do |pl|
          s = winrate_map[pl.id]
          (s && s[:eligible] && s[:wr]) ? s[:wr] : 0.0
        end
      end
    end
  end
end
