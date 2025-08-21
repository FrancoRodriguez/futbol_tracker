require "rails_helper"

RSpec.describe Stats::Calculator, type: :service do
  let(:player) { create(:player) }
  let(:home_team) { create(:team) }
  let(:away_team) { create(:team) }

  def build_match_on(day, winner: :none, mvp: nil)
    date = Date.new(2025, 8, day)
    match = create(:match, date: date, home_team: home_team, away_team: away_team)
    # Participa el jugador siempre en el home_team por simplicidad
    create(:participation, player: player, match: match, team_id: home_team.id)

    case winner
    when :home
      match.update!(win_id: home_team.id, result: "1-0")
    when :away
      match.update!(win_id: away_team.id, result: "0-1")
    else
      # unfinished (win_id nil)
    end

    match.update!(mvp_id: player.id) if mvp == :player
    match
  end

  context "global" do
    it "calculates totals, wins, win_rate, and streaks (excludes unfinished games)" do
      # Orden cronológico: 1..5
      build_match_on(1, winner: :home)  # W
      build_match_on(2, winner: :home, mvp: :player)  # W + MVP
      build_match_on(3, winner: :away)  # L
      build_match_on(4, winner: :away)  # L
      build_match_on(5, winner: :none)  # unfinished (ignorado)

      attrs = described_class.new(player: player).call

      expect(attrs[:total_matches]).to eq(4)
      expect(attrs[:total_wins]).to eq(2)
      expect(attrs[:win_rate_cached]).to eq(0.5)
      expect(attrs[:mvp_awards_count]).to eq(1)
      # Secuencia: W W L L -> current: -2, best_win: 2, best_loss: 2
      expect(attrs[:streak_current]).to eq(-2)
      expect(attrs[:streak_best_win]).to eq(2)
      expect(attrs[:streak_best_loss]).to eq(2)
    end

    it "returns win_rate nil when there are no completed matches" do
      build_match_on(1, winner: :none) # unfinished
      attrs = described_class.new(player: player).call
      expect(attrs[:total_matches]).to eq(0)
      expect(attrs[:total_wins]).to eq(0)
      expect(attrs[:win_rate_cached]).to be_nil
    end
  end

  context "seasonal" do
    let!(:season) { create(:season, starts_on: Date.new(2025, 8, 1), ends_on: Date.new(2025, 8, 3)) }

    it "filter by season date range" do
      # Within the season (1..3)
      build_match_on(1, winner: :home)      # W
      build_match_on(2, winner: :home)      # W
      build_match_on(3, winner: :away, mvp: :player) # L + MVP within season
      # Out of season (ignored)
      build_match_on(4, winner: :away)
      build_match_on(5, winner: :home, mvp: :player)

      attrs = described_class.new(player: player, season: season).call

      expect(attrs[:total_matches]).to eq(3)
      expect(attrs[:total_wins]).to eq(2)
      expect(attrs[:win_rate_cached]).to eq(2.0/3)
      # During the season, the player had 1 MVP (day 3).
      expect(attrs[:mvp_awards_count]).to eq(1)
      # Sequence within season: W W L -> current: -1, best_win: 2, best_loss: 1
      expect(attrs[:streak_current]).to eq(-1)
      expect(attrs[:streak_best_win]).to eq(2)
      expect(attrs[:streak_best_loss]).to eq(1)
    end
  end
end
