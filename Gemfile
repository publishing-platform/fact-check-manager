source "https://rubygems.org"

gem "rails", "~> 8.1.3"

gem "bootsnap", require: false
gem "dartsass-rails"
gem "jbuilder"
gem "jsbundling-rails"
gem "pg", "~> 1.1"
gem "publishing_platform_api_adapters"
gem "publishing_platform_app_config"
gem "publishing_platform_location"
gem "publishing_platform_nokodiff"
gem "publishing_platform_publishing_components"
gem "publishing_platform_sidekiq"
gem "publishing_platform_sso"
gem "sentry-sidekiq"
gem "sprockets-rails"
gem "terser"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "publishing_platform_rubocop"
  gem "publishing_platform_test"
  gem "rspec-rails"
end

group :development do
  gem "web-console"
end

group :test do
  gem "simplecov"
end
