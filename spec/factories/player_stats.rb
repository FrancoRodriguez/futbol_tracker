FactoryBot.define do
  factory :player_stat do
    association :player
    season { nil }
    total_matches { 0 }
    total_wins { 0 }
    win_rate_cached { nil }
    streak_current { 0 }
    streak_best_win { 0 }
    streak_best_loss { 0 }
    mvp_awards_count { 0 }
  end
end
