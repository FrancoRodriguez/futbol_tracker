module MatchesHelper
  def calculate_team_goals(teams, participations)
    team_goals = teams.map do |team|
      {
        name: team.name,
        goals: participations.where(team: team).sum(:goals)
      }
    end

    if team_goals.sum { |tg| tg[:goals] } == 0
      "Resultado no subido"
    else
      team_goals.map { |tg| "#{tg[:name]}: #{tg[:goals]}" }.join(" vs ")
    end
  end
end
