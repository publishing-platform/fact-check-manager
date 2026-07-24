require "rails_helper"

RSpec.describe "Requests", type: :request do
  before { create(:user) }

  describe "POST /api/requests" do
    let(:draft_content_id) { SecureRandom.uuid }
    let(:draft_auth_bypass_id) { SecureRandom.uuid }

    let(:valid_payload) do
      {
        source_app: "Publisher",
        source_id: 620,
        source_url: "",
        source_title: "",
        requester_name: "A Content Designer",
        requester_email: "a-content-designer@example.com",
        current_content: { "part_id" => {
          "heading" => "heading", "body" => "Many lines of data for the content. Many changes that need fact checking"
        } },
        previous_content: {},
        reason_for_change: "a reason",
        deadline: 1.week.from_now.iso8601,
        recipients: ["recipient1@example.com", "recipient2@example.com"],
        draft_content_id:,
        draft_auth_bypass_id:,
        draft_slug: "test-edition-slug",
      }
    end

    context "with a valid payload" do
      it "creates a new Request with collaborations" do
        expect {
          post api_requests_path, params: valid_payload, as: :json
        }.to change(Request, :count).by(1)
                                    .and change(Collaboration, :count).by(2)

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json).to include("id")

        request = Request.last
        expect(request.source_app).to eq("Publisher")
        expect(request.source_id).to eq("620")
        expect(request.current_content["part_id"]["body"]).to eq("Many lines of data for the content. Many changes that need fact checking")
        expect(request.status).to eq("new")
        expect(request.requester_name).to eq("A Content Designer")
        expect(request.requester_email).to eq("a-content-designer@example.com")
        expect(request.reason_for_change).to eq("a reason")
        expect(request.draft_content_id).to eq(draft_content_id)
        expect(request.draft_auth_bypass_id).to eq(draft_auth_bypass_id)
        expect(request.draft_slug).to eq("test-edition-slug")
      end

      it "creates a Request without reason_for_change" do
        payload_without_reason_for_change = valid_payload.except(:reason_for_change)

        expect {
          post api_requests_path, params: payload_without_reason_for_change, as: :json
        }.to change(Request, :count).by(1)

        expect(response).to have_http_status(:created)

        request = Request.last
        expect(request.reason_for_change).to be_nil
      end

      it "creates a Request without draft fields" do
        payload_without_draft = valid_payload.except(:draft_content_id, :draft_auth_bypass_id, :draft_slug)

        expect {
          post api_requests_path, params: payload_without_draft, as: :json
        }.to change(Request, :count).by(1)

        expect(response).to have_http_status(:created)

        request = Request.last
        expect(request.draft_content_id).to be_nil
        expect(request.draft_auth_bypass_id).to be_nil
        expect(request.draft_slug).to be_nil
      end

      it "creates a user record for given email address when one does not already exist" do
        expect {
          post api_requests_path, params: valid_payload, as: :json
        }.to change(User, :count).by(2)

        expect(User.second_to_last.email).to eq("recipient1@example.com")
        expect(User.last.email).to eq("recipient2@example.com")
      end

      it "does not create any new user records if they already exist for given email addresses" do
        recipient1_email = "recipient1@example.com"
        recipient1 = create(:user, email: recipient1_email)

        expect {
          post api_requests_path, params: valid_payload, as: :json
        }.to change(User, :count).by(1)

        expect(User.find_by(email: recipient1_email).id).to eq(recipient1.id)
        expect(User.where(email: recipient1_email).count).to eq(1)
      end

      it "creates a user record which contains only the email, ID, timestamps and defaults" do
        post api_requests_path, params: valid_payload, as: :json

        populated_attributes = User.last.attributes.compact.keys
        expect(populated_attributes).to contain_exactly(
          "email",
          "id",
          "created_at",
          "updated_at",
          "disabled",
          "permissions",
        )
      end

      it "does not alter any existing user records" do
        recipient1_email = "recipient1@example.com"
        recipient1 = create(:user, email: recipient1_email)

        expect {
          post api_requests_path, params: valid_payload, as: :json
        }.not_to(change { recipient1.reload.updated_at })
      end

      it "successfully sends emails to each recipient" do
        deadline = Time.zone.parse("2026-06-12T09:00:00Z")
        payload = valid_payload.merge(source_title: "An interesting article", deadline:)

        perform_enqueued_jobs do
          post api_requests_path, params: payload, as: :json
        end

        request_record = Request.last
        expected_url_prefix = "#{PublishingPlatformLocation.external_url_for('fact-check-manager')}/requests/#{request_record.source_app}/#{request_record.source_id}/compare?token="

        tos = ActionMailer::Base.deliveries.map(&:to)
        message = ActionMailer::Base.deliveries.first

        expect(tos).to contain_exactly(["recipient1@example.com"], ["recipient2@example.com"])

        expect(message.subject).to eq(I18n.t("fact_check_mailer.new_fact_check_request_email.subject",
                                             title: payload[:source_title]))

        expect(message.body).to have_content(expected_url_prefix)
        expect(message.body).to have_content("Deadline: Friday 12 June 2026")
        expect(message.body).to have_content("a reason")
      end
    end

    context "with an invalid payload" do
      let(:dynamic_current_content) { {} }
      let(:base_payload) do
        {
          source_app: "Publisher",
          source_id: 594,
          requester_name: "A Content Designer",
          requester_email: "a-content-designer@example.com",
          current_content: dynamic_current_content,
          previous_content: {},
          deadline: 1.week.from_now.iso8601,
          recipients: ["recipient1@example.com", "recipient2@example.com"],
        }
      end

      it "returns errors for missing required fields" do
        payload_missing_required_fields = { requester_name: "Alice",
                                            recipients: ["recipient1@example.com", "recipient2@example.com"] }

        # rubocop:disable RSpec/ChangeByZero
        expect {
          post api_requests_path, params: payload_missing_required_fields, as: :json
        }.to change(Request, :count).by(0)
                                    .and change(Collaboration, :count).by(0)
        # rubocop:enable RSpec/ChangeByZero

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include(
          "Source can't be blank",
          "Source app can't be blank",
          "Requester email can't be blank",
          "Current content can't be blank",
          "Deadline can't be blank",
        )
      end

      it "does not create any new user collaborations records" do
        payload_missing_required_fields = { requester_name: "Alice" }

        expect {
          post api_requests_path, params: payload_missing_required_fields, as: :json
        }.not_to change(Collaboration, :count)
      end

      context "when current_content is not a hash" do
        let(:dynamic_current_content) { "not a hash" }

        it "returns an error" do
          post api_requests_path, params: base_payload, as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include("current_content must be a hash")
        end
      end

      context "when current_content body value is not a string" do
        let(:dynamic_current_content) do
          {
            "id": { heading: "normal_field", body: "This should pass" },
            "id2": { heading: "bad_number_field", body: 123 },
          }
        end

        it "returns an error" do
          post api_requests_path, params: base_payload, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include("Current content body in id2 must be a string")
        end
      end

      context "when current_content contains nested data" do
        let(:dynamic_current_content) do
          {
            "id": { heading: "normal_field", body: "This should pass" },
            "id2": { heading: "sneaky_nested_hash", body: { "naughty" => "This should fail" } },
          }
        end

        it "returns an error" do
          # rubocop:disable RSpec/ChangeByZero
          expect {
            post api_requests_path, params: base_payload, as: :json
          }.to change(Request, :count).by(0)
                                      .and change(Collaboration, :count).by(0)
          # rubocop:enable RSpec/ChangeByZero

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "when previous_content is not a hash" do
        it "returns an error" do
          post api_requests_path, params: valid_payload.merge(previous_content: "not a hash"), as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include("previous_content must be a hash")
        end
      end

      context "without recipients" do
        it "returns a 400 error" do
          payload = valid_payload
          payload.delete(:recipients)

          post api_requests_path, params: payload, as: :json

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)["errors"])
            .to include("At least one recipient email is required")
        end
      end
    end
  end

  describe "PATCH /api/requests/:source_app/:source_id" do
    let!(:existing_request) { create(:request) }

    let!(:update_payload) do
      {
        source_app: "something-else",
        source_id: existing_request.source_id,
        source_title: "Updated Title",
        current_content: { "part_id" => { "heading" => "heading", "body" => "Updated body goes here" } },
      }
    end

    context "with a valid payload" do
      it "updates the Request with collaborations" do
        expect {
          patch  api_requests_update_path(existing_request.source_app, existing_request.source_id), params: update_payload, as: :json
        }.not_to change(Request, :count)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json).to include("id")
        expect(json).to include("source_id")
        expect(json).to include("source_app")

        request = Request.last
        expect(request.source_app).to eq("publisher")
        expect(request.source_id).to eq(existing_request.source_id)
        expect(request.source_title).to eq("Updated Title")
        expect(request.current_content).to eq("part_id" => { "heading" => "heading", "body" => "Updated body goes here" })
        expect(request.status).to eq("new")
        expect(request.requester_name).to eq("Malcolm Tucker")
        expect(request.requester_email).to eq("m.tucker@publishing-platform.co.uk")
      end

      it "updates the draft_auth_bypass_id" do
        new_auth_bypass_id = SecureRandom.uuid
        payload_with_auth_bypass = update_payload.merge(draft_auth_bypass_id: new_auth_bypass_id)

        patch api_requests_update_path(existing_request.source_app, existing_request.source_id), params: payload_with_auth_bypass, as: :json

        expect(response).to have_http_status(:ok)
        expect(existing_request.reload.draft_auth_bypass_id).to eq(new_auth_bypass_id)
      end

      it "updates the draft_slug" do
        payload_with_slug = update_payload.merge(draft_slug: "updated-slug")

        patch api_requests_update_path(existing_request.source_app, existing_request.source_id), params: payload_with_slug, as: :json

        expect(response).to have_http_status(:ok)
        expect(existing_request.reload.draft_slug).to eq("updated-slug")
      end
    end

    context "with invalid request parameters" do
      let(:invalid_source_app) { "invalid-source-app" }
      let(:invalid_source_id) { "invalid-source-id" }

      context "with invalid source_app and invalid source_id" do
        it "returns a 404" do
          patch api_requests_update_path(invalid_source_app, invalid_source_id), params: update_payload, as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{invalid_source_id} not found for app #{invalid_source_app}",
          )
        end
      end

      context "with valid source_app and invalid source_id" do
        it "returns a 404" do
          patch api_requests_update_path(update_payload[:source_app], invalid_source_id), params: update_payload, as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{invalid_source_id} not found for app #{update_payload[:source_app]}",
          )
        end
      end

      context "with invalid source_app and valid source_id" do
        it "returns a 404" do
          patch api_requests_update_path(invalid_source_app, update_payload[:source_id]), params: update_payload, as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{update_payload[:source_id]} not found for app #{invalid_source_app}",
          )
        end
      end

      context "with source_app and source_id both valid, but invalid in combination" do
        let(:second_request) { create(:request, source_app: "second-app") }

        it "returns a 404" do
          patch api_requests_update_path(second_request[:source_app], update_payload[:source_id]), params: update_payload, as: :json
          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{update_payload[:source_id]} not found for app #{second_request[:source_app]}",
          )
        end
      end
    end

    context "with an invalid payload" do
      let(:invalid_content_payload) { { source_app: existing_request.source_app, source_id: existing_request.source_id, current_content: { body: 123 } } }

      it "returns errors for missing required fields" do
        patch api_requests_update_path(existing_request.source_app, existing_request.source_id), params: invalid_content_payload, as: :json

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["errors"]).to include(
          "Current content value for body must be a hash",
        )
      end
    end

    context "when current_content is not a hash" do
      let(:invalid_content_payload) { { source_app: existing_request.source_app, source_id: existing_request.source_id, current_content: "not a hash" } }

      it "returns errors for current_content format" do
        patch api_requests_update_path(existing_request.source_app, existing_request.source_id), params: invalid_content_payload, as: :json

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["errors"]).to include(
          "current_content must be a hash",
        )
      end
    end
  end

  describe "POST /api/requests/:source_app/:source_id/resend-emails" do
    let!(:user_one) { create(:user, email: "recipient1@example.com") }
    let!(:user_two) { create(:user, email: "recipient2@example.com") }
    let!(:existing_request) do
      request = create(:request)
      create(:collaboration, user: user_one, request: request, role: "fact_checker")
      create(:collaboration, user: user_two, request: request, role: "fact_checker")
      request
    end

    context "with valid request parameters" do
      let(:make_request) do
        post api_requests_resend_emails_path(existing_request.source_app, existing_request.source_id), as: :json
      end

      it "returns ok with the request's identifiers" do
        make_request

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to include("id", "source_id", "source_app")
      end

      it "does not create a new request or users" do
        # rubocop:disable RSpec/ChangeByZero
        expect {
          make_request
        }.to change(Request, :count).by(0)
                                    .and change(Collaboration, :count).by(0)
        # rubocop:enable RSpec/ChangeByZero
      end

      it "successfully sends emails to each collaborator" do
        perform_enqueued_jobs do
          make_request
        end

        expected_url_prefix = "#{PublishingPlatformLocation.external_url_for('fact-check-manager')}/requests/#{existing_request.source_app}/#{existing_request.source_id}/compare?token="

        tos = ActionMailer::Base.deliveries.map(&:to)
        message = ActionMailer::Base.deliveries.first

        expect(tos).to contain_exactly(["recipient1@example.com"], ["recipient2@example.com"])

        expect(message.subject).to eq(I18n.t("fact_check_mailer.new_fact_check_request_email.subject",
                                             title: existing_request.source_title))

        expect(message.body).to have_content(expected_url_prefix)
        expect(message.body).to have_content("Deadline: #{existing_request.deadline.strftime('%A %-e %B %Y')}")
        expect(message.body).to have_content(existing_request.reason_for_change)
      end
    end

    context "with invalid request parameters" do
      let!(:source_app) { "invalid-source-app" }
      let!(:source_id) { "invalid-source-id" }

      let!(:make_request) do
        post api_requests_resend_emails_path(source_app, source_id), as: :json
      end

      shared_examples "requests that do not send any emails" do
        it "does not send any emails" do
          perform_enqueued_jobs do
            make_request
          end

          expect(ActionMailer::Base.deliveries.empty?).to be true
        end
      end

      context "with invalid source_app and invalid source_id" do
        it "returns a 404" do
          make_request

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{source_id} not found for app #{source_app}",
          )
        end

        it_behaves_like "requests that do not send any emails"
      end

      context "with valid source_app and invalid source_id" do
        let!(:source_app) { existing_request.source_app }

        it "returns a 404" do
          make_request

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{source_id} not found for app #{source_app}",
          )
        end

        it_behaves_like "requests that do not send any emails"
      end

      context "with invalid source_app and valid source_id" do
        let!(:source_id) { existing_request.source_id }

        it "returns a 404" do
          make_request

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{source_id} not found for app #{source_app}",
          )
        end

        it_behaves_like "requests that do not send any emails"
      end

      context "with source_app and source_id both valid, but invalid in combination" do
        let!(:existing_request_another_app) { create(:request, source_app: "another") }
        let!(:source_app) { existing_request_another_app.source_app }
        let!(:source_id) { existing_request.source_id }

        it "returns a 404" do
          make_request

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json["errors"]).to include(
            "Request with ID #{source_id} not found for app #{source_app}",
          )
        end

        it_behaves_like "requests that do not send any emails"
      end
    end
  end
end
