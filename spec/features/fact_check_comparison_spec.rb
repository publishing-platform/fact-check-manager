require "rails_helper"

RSpec.feature "Viewing a fact check comparison", type: :feature do
  let(:user) { create(:user) }
  let(:previous_content) { { "test_id" => { "heading" => "Test Heading", "body" => "<div>This is the unchanged line.</div><div>This line will be changed</div>" } } }
  let(:request) do
    create(
      :request,
      :with_collaborator,
      collaborator: user,
      source_title: "Example title",
      deadline: Time.zone.now + 5.days,
      previous_content:,
      current_content: { "test_id" => { "heading" => "Test Heading", "body" => "<div>This is the unchanged line.</div><div>This line has changes</div>" } },
    )
  end

  scenario "shows the comparison" do
    given_there_is_a_fact_check_request
    when_i_view_the_fact_check_comparison

    then_i_see_the_request_details
    and_i_see_the_content_changes
    and_i_see_the_guidance
    and_i_see_the_respond_link
  end

  scenario "responding to the fact check" do
    given_there_is_a_fact_check_request

    when_i_view_the_fact_check_comparison
    and_i_choose_to_respond_to_the_fact_check

    then_i_see_the_response_page
  end

  context "when a draft preview is available" do
    scenario "shows a preview link" do
      given_there_is_a_fact_check_request

      when_i_view_the_fact_check_comparison

      then_i_see_the_preview_link
    end
  end

  context "when a draft preview is unavailable" do
    scenario "does not show a preview link" do
      given_there_is_a_fact_check_request
      given_the_draft_preview_is_unavailable

      when_i_view_the_fact_check_comparison

      then_i_do_not_see_the_preview_link
    end
  end

  # -----------------------------------------------------------------------------
  # Given
  # -----------------------------------------------------------------------------

  def given_there_is_a_fact_check_request
    PublishingPlatform::SSO.test_user = user
    request # force creation
  end

  def given_the_draft_preview_is_unavailable
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(AuthenticationHelper)
      .to receive(:draft_origin_preview_url)
      .and_return(nil)
    # rubocop:enable RSpec/AnyInstance
  end

  # -----------------------------------------------------------------------------
  # When
  # -----------------------------------------------------------------------------

  def when_i_view_the_fact_check_comparison
    visit compare_path(
      source_app: request.source_app,
      source_id: request.source_id,
    )

    then_i_see_the_comparison_page
  end

  # -----------------------------------------------------------------------------
  # Then
  # -----------------------------------------------------------------------------

  def then_i_see_the_comparison_page
    expect(page).to have_content(I18n.t("fact_check_comparison.heading"))
    expect(page).to have_content(request.source_title)
  end

  def then_i_see_the_request_details
    expect(page).to have_content(request.source_title)
    expect(page).to have_content(request.formatted_deadline)
  end

  def and_i_see_the_content_changes
    expect(page).to have_content("This is the unchanged line.")
    expect(page).to have_css(".del", text: "This line will be changed")
    expect(page).to have_css(".ins", text: "This line has changes")
  end

  def and_i_see_the_guidance
    expect(page).to have_text(I18n.t("fact_check_comparison.guidance_heading"))
    expect(page).to have_text(I18n.t("fact_check_comparison.guidance_deleted"))
    expect(page).to have_text(I18n.t("fact_check_comparison.guidance_added"))
  end

  def and_i_see_the_respond_link
    expect(page).to have_link(I18n.t("fact_check_comparison.respond_to_button"))
  end

  def and_i_choose_to_respond_to_the_fact_check
    click_on I18n.t("fact_check_comparison.respond_to_button")
  end

  def then_i_see_the_response_page
    expect(page).to have_content(I18n.t("fact_check_response.heading"))
  end

  def then_i_see_the_preview_link
    expect(page).to have_content(I18n.t("fact_check_comparison.preview_heading"))
    expect(page).to have_link(I18n.t("fact_check_comparison.preview_link"))
  end

  def then_i_do_not_see_the_preview_link
    expect(page).not_to have_content(I18n.t("fact_check_comparison.preview_heading"))
    expect(page).not_to have_link(I18n.t("fact_check_comparison.preview_link"))
  end
end
