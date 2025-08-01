# Borrar datos existentes
Participation.delete_all
Match.delete_all
Player.delete_all
Team.delete_all
User.delete_all

# Crear usuario admin
User.create!(email: 'admin@example.com', password: 'password123')

# Crear equipos
teams = [
  Team.create!(name: 'Tigres del Norte'),
  Team.create!(name: 'Águilas del Sur'),
  Team.create!(name: 'Lobos del Este'),
  Team.create!(name: 'Pumas del Oeste')
]

# Crear jugadores
players = [
  Player.create!(name: 'Juan Pérez', nickname: 'El Rayo'),
  Player.create!(name: 'Carlos Gómez'),
  Player.create!(name: 'Luis Martínez', nickname: 'Zurdo'),
  Player.create!(name: 'Diego Fernández'),
  Player.create!(name: 'Matías Ortega', nickname: 'Tigre'),
  Player.create!(name: 'Santiago Ruiz'),
  Player.create!(name: 'Iván Herrera', nickname: 'Tanque'),
  Player.create!(name: 'Felipe Castro')
]

# Crear 100 partidos con participaciones aleatorias para historial amplio
100.times do |i|
  home_team, away_team = teams.sample(2)
  while home_team == away_team
    away_team = teams.sample
  end

  # Fecha distribuida entre hace 1 año y hoy
  match_date = (Date.today - rand(0..365))

  # Crear goles aleatorios
  goals_home = rand(0..5)
  goals_away = rand(0..5)
  result = "#{goals_home}-#{goals_away}"

  winner = if goals_home > goals_away
             home_team
           elsif goals_away > goals_home
             away_team
           else
             nil # empate
           end

  # Seleccionar jugadores aleatoriamente para el partido (4 a 6 jugadores)
  match_players = players.sample(rand(4..6))

  match = Match.create!(
    home_team: home_team,
    away_team: away_team,
    date: match_date,
    result: result,
    win: winner,
    mvp: match_players.sample,
    players: match_players
  )

  # Asignar equipo y stats a cada participación
  match.participations.each do |p|
    # Aseguramos que la participación pertenezca a uno de los equipos del partido
    team = [home_team, away_team].sample
    p.update!(
      goals: rand(0..3),
      assists: rand(0..2),
      team: team
    )
  end
end

# Crear último partido con video
last_match = Match.create!(
  date: Date.today - 1,
  location: "Estadio Final",
  home_team: teams[1], # 'Águilas del Sur'
  away_team: teams[0], # 'Tigres del Norte'
  result: "2-2",
  win: nil, # empate
  mvp: players[3]      # Diego Fernández
)

last_match.update!(video_url: "https://youtu.be/vaSLuJlkNsU?si=DkRY3WsRfDEIuk0O")

puts "✅ Se generaron:"
puts "- #{User.count} usuario(s)"
puts "- #{Team.count} equipo(s)"
puts "- #{Player.count} jugador(es)"
puts "- #{Match.count} partido(s)"
puts "- #{Participation.count} participación(es)"
