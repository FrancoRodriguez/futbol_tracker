namespace :db do
  desc "Seed teams Blanco and Negro"
  task seed_teams: :environment do
    teams = [ "Blanco", "Negro" ]
    teams.each do |team_name|
      Team.find_or_create_by(name: team_name)
    end
    puts "Teams seeded successfully!"
  end
end
