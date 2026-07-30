require "rails_helper"

RSpec.describe "FactCheckResponse", type: :request do
  let!(:collaborator) { create(:user) }

  let(:request) do
    create(
      :request,
      :with_collaborator,
      collaborator:,
      previous_content: { "test_id" => { "heading" => "Test Heading", "body" => "<div>This is the unchanged line.</div><div>This line will be changed</div>" } },
      current_content: { "test_id" => { "heading" => "Test Heading", "body" => "<div>This is the unchanged line.</div><div>This line has changes</div>" } },
    )
  end

  context "with signed in user who is a collaborator" do
    describe "GET /respond" do
      it "returns 404 when no request exists for the given source_app and source_id" do
        get respond_path(source_app: "invalid", source_id: "invalid")

        expect(response).to have_http_status(:not_found)
      end

      it "renders the response form" do
        get respond_path(source_app: request.source_app, source_id: request.source_id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_response.heading"))
      end

      it "shows the already submitted page when visiting respond for a request with a response" do
        create(:response, request: request)

        get respond_path(source_app: request.source_app, source_id: request.source_id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_already_submitted.heading"))
      end
    end

    describe "POST /validate" do
      it "returns 404 when no request exists for the given source_app and source_id" do
        post validate_path(source_app: "invalid", source_id: "invalid"),
             params: { fact_check_response: { accepted: "true" } }

        expect(response).to have_http_status(:not_found)
      end

      it "renders the confirm page when accepted is provided and true" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_confirm.heading"))
      end

      it "re-renders the response form with errors when accepted is blank" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_response.selection_error"))
      end

      it "re-renders the response form with errors when incorrect and body is blank" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "false", body: "" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_response.factual_errors_empty_field"))
      end

      it "does not require body when accepted is true" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true", body: "" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_confirm.heading"))
        expect(response.body).not_to include(I18n.t("fact_check_response.factual_errors_empty_field"))
      end
    end

    describe "POST /confirm" do
      before do
        allow(PublisherApiService).to receive(:post_fact_check_response)
                                        .and_return(double(code: 200))
      end

      it "sends a confirmation email for accepted fact check" do
        perform_enqueued_jobs do
          post confirm_path(source_app: request.source_app, source_id: request.source_id),
               params: { fact_check_response: { accepted: "true", body: "" } }
        end

        tos = ActionMailer::Base.deliveries.map(&:to)
        message = ActionMailer::Base.deliveries.first

        expect(tos).to contain_exactly([collaborator.email])

        expect(message.subject).to eq(I18n.t("fact_check_mailer.response_accepted_email.subject",
                                             title: request.source_title))
      end

      it "sends a confirmation email for rejected fact check" do
        perform_enqueued_jobs do
          post confirm_path(source_app: request.source_app, source_id: request.source_id),
               params: { fact_check_response: { accepted: "false", body: "This is factually incorrect!" } }
        end

        tos = ActionMailer::Base.deliveries.map(&:to)
        message = ActionMailer::Base.deliveries.first

        expect(tos).to contain_exactly([collaborator.email])

        expect(message.subject).to eq(I18n.t("fact_check_mailer.response_rejected_email.subject",
                                             title: request.source_title))
      end

      it "returns 404 when no request exists for the given source_app and source_id" do
        post confirm_path(source_app: "invalid", source_id: "invalid"),
             params: { fact_check_response: { accepted: "true" } }

        expect(response).to have_http_status(:not_found)
      end

      it "creates a response and renders the submitted page on success" do
        post confirm_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true", body: "" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_submitted.fact_check_submitted"))
        expect(Response.count).to eq(1)
      end

      it "calls the PublisherApiService" do
        post confirm_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true", body: "" } }

        expect(PublisherApiService).to have_received(:post_fact_check_response)
      end

      context "when Publisher API fails" do
        it "rolls back the response" do
          allow(PublisherApiService).to receive(:post_fact_check_response)
                                          .and_raise(PublishingPlatformApi::HTTPErrorResponse.new(422, "", "forced test error"))

          post confirm_path(source_app: request.source_app, source_id: request.source_id),
               params: { fact_check_response: { accepted: "true", body: "" } }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(I18n.t("fact_check_confirm.api_submission_error"))
          expect(Response.count).to eq(0)
        end

        it "does not trigger confirmation email" do
          allow(PublisherApiService).to receive(:post_fact_check_response)
                                          .and_raise(PublishingPlatformApi::HTTPErrorResponse.new(422, "", "forced test error"))

          perform_enqueued_jobs do
            post confirm_path(source_app: request.source_app, source_id: request.source_id),
                 params: { fact_check_response: { accepted: "false", body: "This is factually incorrect!" } }
          end

          expect(response).to have_http_status(:ok)
          expect(ActionMailer::Base.deliveries.empty?).to be true
        end
      end

      it "does not create a duplicate response or send emails when response already exists" do
        create(:response, request: request)

        perform_enqueued_jobs do
          post confirm_path(source_app: request.source_app, source_id: request.source_id),
               params: { fact_check_response: { accepted: "false", body: "This is factually incorrect!" } }
        end

        expect(response).to have_http_status(:ok)
        expect(ActionMailer::Base.deliveries.empty?).to be true
        expect(Response.count).to eq(1)
        expect(Response.first.accepted?).to be true
      end
    end
  end

  context "with signed in user who is an admin" do
    let(:admin) { create(:user, permissions: %w[signin publishing_platform_admin]) }

    before do
      PublishingPlatform::SSO.test_user = admin
    end

    describe "GET /respond" do
      it "renders the response form" do
        get respond_path(source_app: request.source_app, source_id: request.source_id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_response.heading"))
      end
    end

    describe "POST /validate" do
      it "renders the confirm page when accepted is provided and true" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_confirm.heading"))
      end
    end

    describe "POST /confirm" do
      before do
        allow(PublisherApiService).to receive(:post_fact_check_response)
                                        .and_return(double(code: 200))
      end

      it "sends a confirmation email" do
        perform_enqueued_jobs do
          post confirm_path(source_app: request.source_app, source_id: request.source_id),
               params: { fact_check_response: { accepted: "true", body: "" } }
        end

        tos = ActionMailer::Base.deliveries.map(&:to)
        message = ActionMailer::Base.deliveries.first

        expect(tos).to contain_exactly([admin.email])

        expect(message.subject).to eq(I18n.t("fact_check_mailer.response_accepted_email.subject",
                                             title: request.source_title))
      end

      it "creates a response and renders the submitted page on success" do
        post confirm_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true", body: "" } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("fact_check_submitted.fact_check_submitted"))
        expect(Response.count).to eq(1)
      end
    end
  end

  context "with signed in user who is not an admin or collaborator" do
    before do
      PublishingPlatform::SSO.test_user = create(:user, permissions: %w[signin])
    end

    describe "GET /respond" do
      it "is forbidden" do
        get respond_path(source_app: request.source_app, source_id: request.source_id)

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /validate" do
      it "is forbidden" do
        post validate_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true" } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /confirm" do
      before do
        allow(PublisherApiService).to receive(:post_fact_check_response)
                                        .and_return(double(code: 200))
      end

      it "is forbidden" do
        post confirm_path(source_app: request.source_app, source_id: request.source_id),
             params: { fact_check_response: { accepted: "true", body: "" } }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
