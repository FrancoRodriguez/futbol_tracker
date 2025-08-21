# spec/models/player_win_ranking_spec.rb
require "rails_helper"

RSpec.describe Player, ".win_ranking" do
  let!(:season_prev) do
    create(:season, name: "2024-25",
           starts_on: Date.new(2024, 9, 1), ends_on: Date.new(2025, 8, 31), active: false)
  end

  let!(:season_curr) do
    create(:season, name: "2025-26",
           starts_on: Date.new(2025, 9, 1), ends_on: Date.new(2026, 8, 31), active: true)
  end

  # Jugadores
  let!(:p1) { create(:player, name: "Alpha") }
  let!(:p2) { create(:player, name: "Beta") }
  let!(:p3) { create(:player, name: "Charlie") }
  let!(:p4) { create(:player, name: "Delta") }   # sólo global en este spec
  let!(:p5) { create(:player, name: "Aaron") }   # para probar desempate por nombre
  let!(:p6) { create(:player, name: "Zeta") }    # para probar desempate por nombre

  before do
    Rails.cache.clear
    # --- Stats por temporada (season_curr) ---
    # p1: tm=10, tw=7 => diff = 4, wr_pct ~ 70.0
    create(:player_stat, player: p1, season: season_curr,
           total_matches: 10, total_wins: 7, win_rate_cached: 0.7000)

    # p2: tm=12, tw=8 => diff = 4 (empata con p1), pero más tm => debe rankear arriba
    create(:player_stat, player: p2, season: season_curr,
           total_matches: 12, total_wins: 8, win_rate_cached: 0.6667)

    # p3: tm=4 (< MIN_MATCHES), wr_pct debe ser nil en la vista
    create(:player_stat, player: p3, season: season_curr,
           total_matches: 4, total_wins: 4, win_rate_cached: 1.0000)

    # Desempate por nombre: ambos con mismo diff y mismos tm
    # p5 y p6: tm=8, tw=5 => diff = 2; orden alfabético → Aaron antes que Zeta
    create(:player_stat, player: p5, season: season_curr,
           total_matches: 8, total_wins: 5, win_rate_cached: 0.6250)
    create(:player_stat, player: p6, season: season_curr,
           total_matches: 8, total_wins: 5, win_rate_cached: 0.6250)

    # p4 NO tiene fila en la temporada actual (quedará fuera del ranking con season)
    # --- Stats globales (season_id: nil) ---
    create(:player_stat, player: p1, season: nil,
           total_matches: 9, total_wins: 6, win_rate_cached: 0.6667)
    create(:player_stat, player: p4, season: nil,
           total_matches: 20, total_wins: 10, win_rate_cached: 0.5000)
  end

  it "usa player_stats por temporada y ordena por win_diff, luego total_matches, luego nombre" do
    ranking = Player.win_ranking(season: season_curr)

    # Esperado: p2 (diff=4, tm=12) > p1 (diff=4, tm=10) > p3 (diff=4, tm=4) > p5/p6 (diff=2)
    expect(ranking.map(&:id)).to start_with(p2.id, p1.id, p3.id)

    # p5 y p6 deben respetar orden por nombre (Aaron antes que Zeta)
    subset = ranking.select { |r| [ p5.id, p6.id ].include?(r.id) }.map(&:id)
    expect(subset).to eq [ p5.id, p6.id ]

    # Verifica aliases del primero (p2)
    top = ranking.first
    expect(top.id).to eq p2.id
    expect(top.stat_total_matches).to eq 12
    expect(top.stat_total_wins).to eq 8
    expect(top.stat_total_losses).to eq 4
    expect(top.stat_win_diff).to eq 4
    expect(top.stat_win_rate_pct.to_f).to eq 66.7

    # p3 < MIN_MATCHES ⇒ win_rate_pct debe ser nil (la vista muestra "5 PJ y hablamos 😉")
    low = ranking[2]
    expect(low.id).to eq p3.id
    expect(low.stat_total_matches).to eq 4
    expect(low.stat_win_rate_pct).to be_nil

    # p4 no aparece porque no tiene stats en la temporada
    expect(ranking.map(&:id)).not_to include(p4.id)
  end

  it "soporta alcance global (season=nil) y trae filas globales" do
    ranking = Player.win_ranking(season: nil)

    # Dif globales: p1 => 6*2-9=3, p4 => 10*2-20=0 ⇒ p1 debe ir antes
    ids = ranking.map(&:id)
    expect(ids).to include(p1.id, p4.id)
    expect(ids.index(p1.id)).to be < ids.index(p4.id)

    r1 = ranking.detect { |r| r.id == p1.id }
    expect(r1.stat_total_matches).to eq 9
    expect(r1.stat_total_wins).to eq 6
    expect(r1.stat_total_losses).to eq 3
    expect(r1.stat_win_diff).to eq 3
    expect(r1.stat_win_rate_pct.to_f).to eq 50.0 + 16.7 # 66.7

    r4 = ranking.detect { |r| r.id == p4.id }
    expect(r4.stat_total_matches).to eq 20
    expect(r4.stat_total_wins).to eq 10
    expect(r4.stat_total_losses).to eq 10
    expect(r4.stat_win_diff).to eq 0
    expect(r4.stat_win_rate_pct.to_f).to eq 50.0
  end
end
