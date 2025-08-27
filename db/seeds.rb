# db/seeds.rb

DuelVote.delete_all        if defined?(DuelVote)
Participation.delete_all   if defined?(Participation)
PlayerStat.delete_all      if defined?(PlayerStat)
Match.delete_all           if defined?(Match)
Team.delete_all            if defined?(Team)
Player.delete_all          if defined?(Player)
Season.delete_all          if defined?(Season)
User.delete_all            if defined?(User)

# --- Admin ---
User.create!(email: 'admin@example.com', password: 'password123')

# --- Temporadas ---
active_season = Season.create!(name: '2024–2025', starts_on: Date.new(2024, 9, 1),  ends_on: Date.new(2025, 8, 31), active: true)
prev_season   = Season.create!(name: '2023–2024', starts_on: Date.new(2023, 9, 1),  ends_on: Date.new(2024, 8, 31), active: false)

# --- Equipos base (puedes sumar más si quieres) ---
teams = %w[Tigres\ del\ Norte Águilas\ del\ Sur Lobos\ del\ Este Pumas\ del\ Oeste].map do |n|
  Team.create!(name: n)
end

# --- Jugadores ---
players = %w[
  Juan\ Pérez Carlos\ Gómez Luis\ Martínez Diego\ Fernández Matías\ Ortega
  Santiago\ Ruiz Iván\ Herrera Felipe\ Castro Leonardo\ Endara Augusto\ Maisterra
  Pablo\ Casqueiro Miguel\ Díaz Fernando\ Medina Agustín\ Colaneri Lucas\ García
  Fede\ Simkin Rama Javi
].map { |n| Player.create!(name: n) }

# --- Helpers ---
def sample_date_in(season)
  [ season.starts_on, [ season.ends_on, Date.current ].min ].then { |a, b| (a..b).to_a.sample }
end

def create_match_with_participations!(season:, teams:, players:)
  home_team, away_team = teams.sample(2)
  while home_team == away_team
    away_team = teams.sample
  end

  date = sample_date_in(season)

  # arma equipos de 5vs5 (ajusta si quieres)
  pool   = players.sample(10)
  home_ps = pool.first(5)
  away_ps = pool.last(5)

  match = Match.create!(
    date: date,
    location: %w[Santa\ Monica Santa\ Rita Parque\ Rivas].sample,
    home_team: home_team,
    away_team: away_team,
    result: nil,
    win: nil,        # <-- si usas win_id, pon win_id: nil
    mvp: nil         # <-- si usas mvp_id, pon mvp_id: nil
  )

  # Participaciones coherentes
  home_ps.each { |p| Participation.create!(match: match, team: home_team, player: p, goals: rand(0..3), assists: rand(0..2)) }
  away_ps.each { |p| Participation.create!(match: match, team: away_team, player: p, goals: rand(0..3), assists: rand(0..2)) }

  # Resultado + ganador + MVP del equipo ganador
  gh = rand(0..5)
  ga = rand(0..5)
  if gh == ga
    match.update!(result: "#{gh}-#{ga}", win: nil, mvp: nil) # <-- usa win_id/mvp_id si aplica
  else
    winner_team = gh > ga ? home_team : away_team
    winner_side_players = gh > ga ? home_ps : away_ps
    match.update!(
      result: "#{gh}-#{ga}",
      win: winner_team,                # <-- usa win_id: winner_team.id si tu columna es win_id
      mvp: winner_side_players.sample  # <-- usa mvp_id: winner_side_players.sample.id si usas mvp_id
    )
  end

  match
end

def recalc_player_stats_for!(season)
  season_range = (season.starts_on..[ season.ends_on, Date.current ].min)

  mvps_by_player = Match.where(date: season_range)
                        .where.not(mvp_id: nil) # funciona aunque asocies por mvp; ActiveRecord usa *_id internamente
                        .group(:mvp_id).count

  Player.find_each do |player|
    rows = Participation.joins(:match)
                        .where(player_id: player.id, matches: { date: season_range })
                        .select('matches.result, matches.win_id, participations.team_id') # win_id está aunque uses win
                        .order('matches.date ASC')
                        .to_a

    total_matches = rows.size
    next if total_matches.zero?

    draws = rows.count { |r| r.result&.match?(/^\s*(\d+)-\1\s*$/) }
    wins  = rows.count { |r| r.win_id.present? && r.win_id == r.team_id }

    # racha actual
    streak = 0
    rows.reverse_each do |r|
      if r.result&.match?(/^\s*(\d+)-\1\s*$/)    # empate => no afecta
        next
      elsif r.win_id == r.team_id
        streak = streak >= 0 ? streak + 1 : 1
      else
        streak = streak <= 0 ? streak - 1 : -1
      end
    end

    ps = PlayerStat.find_or_initialize_by(player_id: player.id, season_id: season.id)
    ps.total_matches    = total_matches
    ps.total_wins       = wins
    ps.mvp_awards_count = mvps_by_player[player.id].to_i
    ps.streak_current   = streak
    ps.win_rate_cached  = total_matches.zero? ? nil : (wins.to_f / total_matches)
    ps.save!
  end
end

# --- Genera partidos ---
{ prev_season => 26, active_season => 26 }.each do |season, qty|
  qty.times { create_match_with_participations!(season: season, teams: teams, players: players) }
end

# --- Recalcula stats por temporada ---
[ prev_season, active_season ].each { |s| recalc_player_stats_for!(s) }

# --- Partido reciente con video (opcional) ---
last_match = Match.create!(
  date: [ Date.today - 1, active_season.ends_on ].min,
  location: "Estadio Final",
  home_team: teams[1],
  away_team: teams[0],
  result: "2-2",
  win: nil,    # <-- win_id: nil si usas id
  mvp: players[3]
)
last_match.update!(video_url: "https://youtu.be/vaSLuJlkNsU?si=DkRY3WsRfDEIuk0O")

puts "✅ Seed listo:
- Usuarios: #{User.count}
- Temporadas: #{Season.count}
- Equipos: #{Team.count}
- Jugadores: #{Player.count}
- Partidos: #{Match.count}
- Participaciones: #{Participation.count}
- PlayerStats: #{PlayerStat.count}"
