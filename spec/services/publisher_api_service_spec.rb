require "rails_helper"

RSpec.describe PublisherApiService do
  let(:request) { build(:request) }
  let(:user) { create(:user, name: "Test user") }

  before do
    stub_fact_check_response_posts
  end

  describe "#post_fact_check_response" do
    let(:response) { build(:response, request: request, user: user, accepted: true, body: "Custom message") }

    it "calls the Publisher api adapter with the correct arguments" do
      described_class.post_fact_check_response(response)

      expect(Services.publisher_api).to have_received(:post_fact_check_response).with(
        {
          edition_id: response.request.source_id.to_i,
          responder_name: "Test user",
          accepted: true,
          comment: "Custom message",
        },
      )
    end
  end
end
