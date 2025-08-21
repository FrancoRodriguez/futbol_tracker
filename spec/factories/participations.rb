FactoryBot.define do
  factory :participation do
    association :player
    association :match
    team_id { match.home_team_id }
    goals { 0 }
    assists { 0 }
    rating { 0.0 }
  end
end
