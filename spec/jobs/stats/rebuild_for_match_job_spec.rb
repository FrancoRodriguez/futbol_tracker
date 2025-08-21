require "rails_helper"

RSpec.describe Stats::RebuildForMatchJob, type: :job do
  let(:player) { create(:player) }
  let(:home_team) { create(:team) }
  let(:away_team) { create(:team) }
  let!(:season) { create(:season, starts_on: Date.new(2025, 8, 1), ends_on: Date.new(2025, 8, 31), name: "2025-26") }

  it "Recalculates global and seasonal stats for match participants." do
    match = create(:match, date: Date.new(2025, 8, 10), home_team: home_team, away_team: away_team)
    create(:participation, player: player, match: match, team_id: home_team.id)

    # Define ganador y dispara el job manualmente
    match.update!(win_id: home_team.id, result: "1-0")

    # Ejecuta el job (sin cola)
    described_class.perform_now(match.id)

    global = PlayerStat.find_by(player_id: player.id, season_id: nil)
    seasonal = PlayerStat.find_by(player_id: player.id, season_id: season.id)

    expect(global).to be_present
    expect(seasonal).to be_present

    expect(global.total_matches).to eq(1)
    expect(global.total_wins).to eq(1)
    expect(global.win_rate_cached).to eq(1.0)

    expect(seasonal.total_matches).to eq(1)
    expect(seasonal.total_wins).to eq(1)
    expect(seasonal.win_rate_cached).to eq(1.0)
  end
end
