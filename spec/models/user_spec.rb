require "rails_helper"
require "publishing_platform_sso/lint/user_spec"

RSpec.describe User, type: :model do
  # Linting test verifies that User model is compatible with PublishingPlatform::SSO::User:
  it_behaves_like "a publishing_platform_sso user class"

  describe "associations" do
    it "can access requests through collaborations" do
      user = create(:user)
      request = create(:request)
      create(:collaboration, user: user, request: request)

      expect(user.requests).to include(request)
    end

    it "can access a user's associated responses" do
      user = create(:user)
      response = create(:response, request: create(:request), user: user)

      expect(user.responses).to include(response)
    end
  end
end
