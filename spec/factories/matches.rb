FactoryBot.define do
  factory :match do
    date { Date.new(2025, 8, 1) }
    location { "Cancha" }
    association :home_team, factory: :team
    association :away_team, factory: :team
    result { nil }
    win_id { nil }
    season { nil }

    trait :finished_home_win do
      after(:build) do |m|
        m.win_id = m.home_team_id
        m.result = "Home"
      end
    end

    trait :finished_away_win do
      after(:build) do |m|
        m.win_id = m.away_team_id
        m.result = "Away"
      end
    end
  end
end
