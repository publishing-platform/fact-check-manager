FactoryBot.define do
  factory :user do
    name { "John Smith" }
    uid { SecureRandom.uuid }
    sequence(:email) { |n| "user#{n}@example.com" }
  end
end
