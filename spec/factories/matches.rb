FactoryBot.define do
  factory :match do
    date     { Date.new(2025, 8, 1) }
    location { "Cancha" }
    association :home_team, factory: :team
    association :away_team, factory: :team
    result  { nil }
    win_id  { nil }
    season  { nil }

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

    # === NUEVO: match con participations ya creadas ===
    factory :match_with_participations do
      transient do
        winners      { [] }   # Array de Player
        losers       { [] }   # Array de Player
        winning_side { :home } # :home o :away
      end

      after(:create) do |match, evaluator|
        # Asegura ganador coherente con winning_side
        case evaluator.winning_side
        when :home
          match.update!(win_id: match.home_team_id, result: "3-1") if match.win_id.nil?
          winners_team = match.home_team
          losers_team  = match.away_team
        when :away
          match.update!(win_id: match.away_team_id, result: "1-2") if match.win_id.nil?
          winners_team = match.away_team
          losers_team  = match.home_team
        else
          raise ArgumentError, "winning_side debe ser :home o :away"
        end

        # Crea participations
        Array(evaluator.winners).each do |player|
          create(:participation, match:, team: winners_team, player:)
        end
        Array(evaluator.losers).each do |player|
          create(:participation, match:, team: losers_team,  player:)
        end
      end
    end
  end
end
