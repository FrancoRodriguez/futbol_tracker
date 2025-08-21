namespace :stats do
  desc "Backfill player_stats global (season_id: nil)"
  task backfill_global: :environment do
    Stats::BackfillPlayerStats.new.call
    puts "OK: backfill global"
  end

  desc "Backfill player_stats for a season by name (e.g., '2025-26')"
  task :backfill_season, [ :season_name ] => :environment do |_, args|
    name = args[:season_name] or abort "Use: rails stats:backfill_season['Nombre']"
    season = Season.find_by!(name: name)
    Stats::BackfillPlayerStats.new(season: season).call
    puts "OK: backfill season #{name}"
  end
end
