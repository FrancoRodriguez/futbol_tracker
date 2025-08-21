FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Equipo #{n}" }
  end
end
