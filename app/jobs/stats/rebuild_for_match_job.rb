class Stats::RebuildForMatchJob < ApplicationJob
  queue_as :default
  def perform(match_id)
    match = Match.find(match_id)
    players = match.participants
    seasons = Season.for_date!(match.date).to_a
    [ nil, *seasons ].each do |season|
      players.each do |pl|
        attrs = Stats::Calculator.new(player: pl, season: season).call
        stat  = PlayerStat.where(player_id: pl.id, season_id: season&.id).first_or_initialize
        stat.update!(attrs)
      end
    end
  end
end
