FactoryBot.define do
  factory :season do
    sequence(:name) { |n| "Temporada #{2025 + n}-#{2026 + n}" }
    starts_on { Date.new(2025, 8, 1) }
    ends_on   { Date.new(2026, 6, 30) }
    active    { false }
  end
end
