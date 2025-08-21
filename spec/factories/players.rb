FactoryBot.define do
  factory :player do
    sequence(:name) { |n| "Jugador #{n}" }
    rating { 0.0 }
  end
end
