require "rails_helper"

RSpec.describe Stats::WinRateReader, type: :service do
  let(:player)     { create(:player) }
  let(:home_team)  { create(:team) }
  let(:away_team)  { create(:team) }

  # Temporadas: pasada (sep→ago) y actual (sep→ago siguiente)
  let!(:season_prev) do
    create(:season, name: "2024-25",
           starts_on: Date.new(2024, 9, 1), ends_on: Date.new(2025, 8, 31), active: false)
  end
  let!(:season_curr) do
    create(:season, name: "2025-26",
           starts_on: Date.new(2025, 9, 1), ends_on: Date.new(2026, 8, 31), active: true)
  end

  # Helper para crear un match con resultado N-N coherente con el ganador
  def play_on(date:, winner:, player_team: :home, mvp: false)
    match = create(:match, date: date, home_team: home_team, away_team: away_team)

    team_id = (player_team == :home) ? home_team.id : away_team.id
    create(:participation, player: player, match: match, team_id: team_id)

    case winner
    when :home
      match.update!(win_id: home_team.id, result: "1-0")
    when :away
      match.update!(win_id: away_team.id, result: "0-1")
    when :draw
      match.update!(win_id: nil, result: "1-1") # no se cuenta como finalizado para WR
    when :none
      # partido no finalizado: result/win_id nil
    else
      raise ArgumentError, "winner must be :home, :away, :draw, :none"
    end

    match.update!(mvp_id: player.id) if mvp
    match
  end

  context "fallback to last season (last 5 completed)" do
    it "use the last 5 from last season if the current season does not reach the minimum" do
      # Temporada actual: solo 2 partidos finalizados (insuficiente)
      play_on(date: Date.new(2025, 10, 1), winner: :home) # W
      play_on(date: Date.new(2025, 10, 8), winner: :away) # L

      # Temporada pasada: 7 partidos finalizados con resultados conocidos
      # Los ÚLTIMOS 5 por fecha DESC serán: 7,6,5,4,3
      play_on(date: Date.new(2025, 4, 1), winner: :home) # 1: W (no entra)
      play_on(date: Date.new(2025, 4, 2), winner: :home) # 2: W
      play_on(date: Date.new(2025, 4, 3), winner: :away) # 3: L
      play_on(date: Date.new(2025, 4, 4), winner: :home) # 4: W
      play_on(date: Date.new(2025, 4, 5), winner: :away) # 5: L
      play_on(date: Date.new(2025, 4, 6), winner: :home) # 6: W
      play_on(date: Date.new(2025, 4, 7), winner: :home) # 7: W
      # Últimos 5 (7,6,5,4,3) => W, W, L, W, L => 3 victorias

      # Lógica esperada en fallback (últimos 5 finalizados por fecha DESC): 6,5,4,3,2 -> W, L, W, L, W => 3 victorias
      reader = described_class.new(min_matches: 5, season: season_curr)
      res = reader.call(players: [ player ])

      st = res[player.id]
      expect(st).to be_present
      expect(st[:eligible]).to eq(true)
      expect(st[:tm]).to eq(5)
      expect(st[:tw]).to eq(3)
      expect(st[:wr]).to eq(3.0/5.0)
    end

    it "If you don't have 5 in the last round either, you are ineligible (the view leaves it blank)." do
      # Temporada actual: 1 partido
      play_on(date: Date.new(2025, 10, 1), winner: :home)

      # Temporada pasada: solo 3 finalizados (insuficiente)
      play_on(date: Date.new(2025, 5, 1), winner: :home)
      play_on(date: Date.new(2025, 5, 8), winner: :away)
      play_on(date: Date.new(2025, 5, 15), winner: :home)

      reader = described_class.new(min_matches: 5, season: season_curr)
      res = reader.call(players: [ player ])

      st = res[player.id]
      expect(st).to be_present
      expect(st[:eligible]).to eq(false)
      # wr puede tener un valor (por la temporada actual), pero la UI no lo muestra al no ser elegible.
      # Por eso no afirmamos sobre :wr aquí.
    end

    it "ignores unfinished matches in the past and takes the last 5 FINISHED matches" do
      # Temporada actual: 0 o pocos partidos -> forzamos fallback
      play_on(date: Date.new(2025, 10, 1), winner: :away) # 1 partido actual

      # Temporada pasada: mezclamos finalizados y no finalizados
      # Fechas altas con 'none' no cuentan; el fallback debe saltarlas y seguir buscando
      play_on(date: Date.new(2025, 8, 30), winner: :none)  # unfinished
      play_on(date: Date.new(2025, 8, 29), winner: :none)  # unfinished

      # 6 finalizados anteriores, así el fallback puede tomar 5 finalizados "más recientes"
      # (en orden DESC: 8/28, 8/27, 8/26, 8/25, 8/24)
      play_on(date: Date.new(2025, 8, 28), winner: :home) # W
      play_on(date: Date.new(2025, 8, 27), winner: :away) # L
      play_on(date: Date.new(2025, 8, 26), winner: :home) # W
      play_on(date: Date.new(2025, 8, 25), winner: :home) # W
      play_on(date: Date.new(2025, 8, 24), winner: :away) # L
      play_on(date: Date.new(2025, 8, 23), winner: :home) # W (este queda fuera al tomar 5)

      reader = described_class.new(min_matches: 5, season: season_curr)
      res = reader.call(players: [ player ])

      st = res[player.id]
      expect(st[:eligible]).to eq(true)
      # Últimos 5 FINALIZADOS por fecha DESC: 28(W),27(L),26(W),25(W),24(L) => 3 victorias
      expect(st[:tm]).to eq(5)
      expect(st[:tw]).to eq(3)
      expect(st[:wr]).to eq(3.0/5.0)
    end
  end
end
