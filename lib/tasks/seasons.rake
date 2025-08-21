# lib/tasks/seasons.rake
namespace :seasons do
  desc "Assign season to matches by date range"
  task backfill_matches: :environment do
    Season.find_each do |s|
      Match.where(date: s.starts_on..s.ends_on).update_all(season_id: s.id)
    end
    puts "OK: matches.season_id backfilled"
  end
end
