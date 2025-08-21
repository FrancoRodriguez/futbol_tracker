require "rails_helper"

RSpec.describe Stats::BackfillPlayerStats, type: :service do
  let!(:p1) { create(:player) }
  let!(:p2) { create(:player) }
  let!(:home_team) { create(:team) }
  let!(:away_team) { create(:team) }
  let!(:season) { create(:season, starts_on: Date.new(2025, 8, 1), ends_on: Date.new(2025, 8, 31), active: true, name: "2025-26") }

  def play(player:, day:, team: :home, winner:)
    match = create(:match, date: Date.new(2025, 8, day), home_team: home_team, away_team: away_team)
    team_id = (team == :home) ? home_team.id : away_team.id
    create(:participation, player: player, match: match, team_id: team_id)

    case winner
    when :home
      match.update!(win_id: home_team.id,  result: "1-0")
    when :away
      match.update!(win_id: away_team.id,  result: "0-1")
    when :draw
      match.update!(win_id: nil,           result: "1-1") # empate (si no cuentas empates como finalizados, se ignorará)
    when :none, nil
      # partido no finalizado: dejamos win_id y result en nil
    else
      raise ArgumentError, "winner must be :home, :away, :draw or :none"
    end

    match
  end

  it "creates/updates GLOBAL stats for all players" do
    play(player: p1, day: 1, team: :home, winner: :home) # p1 W
    play(player: p1, day: 2, team: :home, winner: :away) # p1 L
    play(player: p2, day: 3, team: :home, winner: :home) # p2 W

    expect {
      described_class.new.call
    }.to change { PlayerStat.count }.by(2)

    s1 = PlayerStat.find_by!(player_id: p1.id, season_id: nil)
    s2 = PlayerStat.find_by!(player_id: p2.id, season_id: nil)

    expect(s1.total_matches).to eq(2)
    expect(s1.total_wins).to eq(1)
    expect(s1.win_rate_cached).to eq(0.5)

    expect(s2.total_matches).to eq(1)
    expect(s2.total_wins).to eq(1)
    expect(s2.win_rate_cached).to eq(1.0)
  end

  it "creates/updates stats PER SEASON and is idempotent" do
    play(player: p1, day: 1, team: :home, winner: :home)
    play(player: p1, day: 2, team: :home, winner: :home)

    expect {
      described_class.new(season: season).call
    }.to change { PlayerStat.where(season_id: season.id).count }.by(1)

    stat = PlayerStat.find_by!(player_id: p1.id, season_id: season.id)
    expect(stat.total_matches).to eq(2)
    expect(stat.total_wins).to eq(2)
    expect(stat.win_rate_cached).to eq(1.0)

    # Idempotent (second run does not create duplicates)
    expect {
      described_class.new(season: season).call
    }.not_to change { PlayerStat.where(season_id: season.id).count }

    # If I add one more game and run it again, it updates.
    play(player: p1, day: 3, team: :home, winner: :away)
    described_class.new(season: season).call
    stat.reload
    expect(stat.total_matches).to eq(3)
    expect(stat.total_wins).to eq(2)
    expect(stat.win_rate_cached).to eq((2.0/3).round(4))
  end
end
