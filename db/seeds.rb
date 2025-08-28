# db/seeds.rb

# --- Limpieza (en orden para respetar FKs) ---
DuelVote.delete_all        if defined?(DuelVote)
Participation.delete_all   if defined?(Participation)
Match.delete_all           if defined?(Match)
PlayerStat.delete_all      if defined?(PlayerStat)

# Si ya tienes las tablas de posiciones:
PlayerPosition.delete_all  if defined?(PlayerPosition)
Position.delete_all        if defined?(Position)

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

# --- Posiciones (Fútbol 7 simple) ---
# Requiere tablas: positions, player_positions (con columnas: player_id, position_id, primary:boolean)
pos_data = [
  { key: "GK",  name: "Portero" },
  { key: "DEF", name: "Defensa" },
  { key: "MID", name: "Mediocampista" },
  { key: "ATT", name: "Delantero" }
]
positions = pos_data.each_with_index.map do |attrs, i|
  Position.find_or_create_by!(key: attrs[:key]) do |p|
    p.name       = attrs[:name]
    p.sort_order = i
  end
end
POS = Position.all.index_by(&:key) # => {"GK"=>#<Position ...>, ...}

# --- Jugadores ---
players = %w[
  Juan\ Pérez Carlos\ Gómez Luis\ Martínez Diego\ Fernández Matías\ Ortega
  Santiago\ Ruiz Iván\ Herrera Felipe\ Castro Leonardo\ Endara Augusto\ Maisterra
  Pablo\ Casqueiro Miguel\ Díaz Fernando\ Medina Agustín\ Colaneri Lucas\ García
  Fede\ Simkin Rama Javi
].map { |n| Player.create!(name: n) }

# --- Helper para asignar posiciones a jugadores ---
def set_positions!(player, primary_key:, secondary_keys: [])
  # Asegura existencia del vínculo con 'primary' en uno y secundarios en el resto
  # Nota: usa constantes POS definidas arriba (hash por key)
  primary_pos = POS.fetch(primary_key)
  PlayerPosition.find_or_create_by!(player: player, position: primary_pos) do |pp|
    pp.primary = true
  end
  # Marcar como primaria por si ya existía
  pp_primary = PlayerPosition.find_by(player: player, position: primary_pos)
  pp_primary.update!(primary: true)

  # Quitar 'primary' de otras posiciones del jugador
  PlayerPosition.where(player: player).where.not(position_id: primary_pos.id).update_all(primary: false)

  # Secundarias
  Array(secondary_keys).uniq.each do |k|
    next if k == primary_key
    pos = POS[k]
    PlayerPosition.find_or_create_by!(player: player, position: pos) do |pp|
      pp.primary = false
    end
  end
end

# --- Asignación de posiciones (distribución equilibrada) ---
# 2 arqueros, resto repartido en DEF/MID/ATT
gks, defs, mids, atts = [], [], [], []

players.each_with_index do |p, i|
  case i
  when 0 then set_positions!(p, primary_key: "GK",  secondary_keys: ["DEF"]);  gks << p
  when 1 then set_positions!(p, primary_key: "GK",  secondary_keys: ["MID"]);  gks << p
  when 2,3,4,5 then set_positions!(p, primary_key: "DEF", secondary_keys: ["MID"]); defs << p
  when 6,7,8,9 then set_positions!(p, primary_key: "MID", secondary_keys: ["DEF"]); mids << p
  when 10,11,12 then set_positions!(p, primary_key: "ATT", secondary_keys: ["MID"]); atts << p
  else
    # Los últimos jugadores con perfiles mixtos que suelen ayudar a balancear
    set_positions!(p, primary_key: %w[DEF MID ATT].sample, secondary_keys: (%w[DEF MID ATT] - [primary_key = nil]).sample(1))
  end
end

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

  # Fútbol 7 -> 7 vs 7
  pool    = players.sample(14)
  home_ps = pool.first(7)
  away_ps = pool.last(7)

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
  gh = rand(0..6)
  ga = rand(0..6)
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
                        .where.not(mvp_id: nil)
                        .group(:mvp_id).count

  Player.find_each do |player|
    rows = Participation.joins(:match)
                        .where(player_id: player.id, matches: { date: season_range })
                        .select('matches.result, matches.win_id, participations.team_id')
                        .order('matches.date ASC')
                        .to_a

    total_matches = rows.size
    next if total_matches.zero?

    draws = rows.count { |r| r.result&.match?(/^\s*(\d+)-\1\s*$/) }
    wins  = rows.count { |r| r.win_id.present? && r.win_id == r.team_id }

    # racha actual (positiva = victorias, negativa = derrotas)
    streak = 0
    rows.reverse_each do |r|
      if r.result&.match?(/^\s*(\d+)-\1\s*$/)    # empate
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
- Posiciones: #{Position.count}
- Jugadores: #{Player.count}
- PlayerPositions: #{defined?(PlayerPosition) ? PlayerPosition.count : 0}
- Partidos: #{Match.count}
- Participaciones: #{Participation.count}
- PlayerStats: #{PlayerStat.count}"
