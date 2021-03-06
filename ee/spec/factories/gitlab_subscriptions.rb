# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription do
    namespace
    association :hosted_plan, factory: :gold_plan
    seats { 10 }
    start_date { Date.today }
    end_date { Date.today.advance(years: 1) }
    trial { false }

    trait :expired do
      start_date { Date.today.advance(years: -1, months: -1) }
      end_date { Date.today.advance(months: -1) }
    end

    trait :active_trial do
      trial { true }
      trial_ends_on { Date.today.advance(months: 1) }
    end

    trait :expired_trial do
      trial { true }
      trial_ends_on { Date.today.advance(days: -1) }
    end

    trait :default do
      association :hosted_plan, factory: :default_plan
    end

    trait :free do
      hosted_plan_id { nil }
    end

    trait :bronze do
      association :hosted_plan, factory: :bronze_plan
    end

    trait :silver do
      association :hosted_plan, factory: :silver_plan
    end

    trait :gold do
      association :hosted_plan, factory: :gold_plan
    end
  end
end
