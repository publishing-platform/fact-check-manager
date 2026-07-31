require "rails_helper"

RSpec.describe "Token Bypass Access", type: :request do
  include AuthenticationHelper

  let(:request_record) { create(:request) }

  describe "GET /requests/:source_app/:source_id/compare" do
    let(:path) { compare_path(request_record.source_app, request_record.source_id) }

    context "with a valid token" do
      before { PublishingPlatform::SSO.test_user = nil }

      it "bypasses authentication (does not call authenticate_user!)" do
        token = compare_preview_jwt_token(request_record)

        # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(ApplicationController).not_to receive(:authenticate_user!)
        # rubocop:enable RSpec/AnyInstance

        get path, params: { token: token }

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("Respond to fact check")
      end
    end

    context "with an invalid token" do
      before { PublishingPlatform::SSO.test_user = nil }

      it "attempts authentication (calls authenticate_user!)" do
        # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(ApplicationController).to receive(:authenticate_user!) do |controller|
          controller.redirect_to("/auth/publishing_platform")
        end
        # rubocop:enable RSpec/AnyInstance

        get path, params: { token: "invalid-token" }
        expect(response).to redirect_to("/auth/publishing_platform")
      end
    end

    context "with no token" do
      before { PublishingPlatform::SSO.test_user = nil }

      it "attempts authentication (calls authenticate_user!)" do
        # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(ApplicationController).to receive(:authenticate_user!) do |controller|
          controller.redirect_to("/auth/publishing_platform")
        end
        # rubocop:enable RSpec/AnyInstance

        get path
        expect(response).to redirect_to("/auth/publishing_platform")
      end
    end

    context "when logged in as a user who is not a collaborator or admin" do
      before { PublishingPlatform::SSO.test_user = create(:user) }

      it "prevents access with no token" do
        get path
        expect(response).to have_http_status(:forbidden)
      end

      it "allows access with a valid token" do
        token = compare_preview_jwt_token(request_record)

        get path, params: { token: token }
        expect(response).to have_http_status(:success)
      end

      it "prevents access with an invalid token" do
        token = "invalid-token"

        get path, params: { token: token }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when logged in as a user who is a collaborator" do
      let(:current_user) { PublishingPlatform::SSO.test_user = create(:user) }
      let(:request_record) do
        create(
          :request,
          :with_collaborator,
          collaborator: current_user,
        )
      end

      it "allows access with no token" do
        get path
        expect(response).to have_http_status(:success)
      end

      it "allows access with a valid token" do
        token = compare_preview_jwt_token(request_record)

        get path, params: { token: token }
        expect(response).to have_http_status(:success)
      end

      it "allows access with an invalid token" do
        token = "invalid-token"

        get path, params: { token: token }
        expect(response).to have_http_status(:success)
      end
    end

    context "when logged in as a user who is an admin" do
      before do
        PublishingPlatform::SSO.test_user = create(:user, permissions: %w[signin publishing_platform_admin])
      end

      it "allows access with no token" do
        get path
        expect(response).to have_http_status(:success)
      end

      it "allows access with a valid token" do
        token = compare_preview_jwt_token(request_record)

        get path, params: { token: token }
        expect(response).to have_http_status(:success)
      end

      it "allows access with an invalid token" do
        token = "invalid-token"

        get path, params: { token: token }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "sign out link" do
    let(:path) { compare_path(request_record.source_app, request_record.source_id) }

    context "when there is a current user" do
      before { PublishingPlatform::SSO.test_user = create(:user, permissions: %w[signin publishing_platform_admin]) }

      it "renders the sign out link" do
        get path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('href="/auth/publishing_platform/sign_out"')
      end
    end

    context "when there is no current user (token bypass)" do
      before { PublishingPlatform::SSO.test_user = nil }

      it "does not render the sign out link" do
        token = compare_preview_jwt_token(request_record)

        get path, params: { token: token }

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('href="/auth/publishing_platform/sign_out"')
      end
    end
  end
end
