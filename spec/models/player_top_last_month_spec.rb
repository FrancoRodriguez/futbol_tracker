RSpec.describe Player, '.top_last_month' do
  it 'uses the previous calendar month and returns wins/PJ for the month' do
    travel_to(Time.zone.local(2025, 8, 27)) do
      season = create(:season, starts_on: '2024-09-01', ends_on: '2025-08-31', active: true)
      p1, p2 = create_list(:player, 2)

      create(:match_with_participations, date: Date.new(2025, 7, 5),  winners: [ p1 ], losers: [ p2 ])
      create(:match_with_participations, date: Date.new(2025, 7, 12), winners: [ p1 ], losers: [ p2 ])
      create(:match_with_participations, date: Date.new(2025, 8, 1),  winners: [ p2 ], losers: [ p1 ]) # fuera del mes anterior

      rows = Player.top_last_month(positions: 3, season: season)
      row1 = rows.find { |r| r.player == p1 }

      expect(row1.wins).to eq(2)
      expect(row1.total_matches).to eq(2)
      expect(rows.map(&:player)).to include(p1)
      expect(rows.map(&:player)).not_to include(p2)
    end
  end
end
