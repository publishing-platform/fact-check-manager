RSpec.configure do |config|
  %i[request system].each do |spec_type|
    config.after(:each, type: spec_type) do
      PublishingPlatform::SSO.test_user = nil
    end
  end
end
