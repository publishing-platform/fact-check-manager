require "rails_helper"

RSpec.feature "Respond to a fact check" do
  scenario "returning to the comparison page" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_start_responding_to_the_fact_check
    and_i_return_to_the_comparison_page

    then_i_see_the_fact_check_comparison
  end

  scenario "submitting a correct response" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_submit_a_correct_response
    and_i_confirm_my_response

    then_i_see_the_response_submitted_page
  end

  scenario "changing a correct response" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_submit_a_correct_response
    and_i_change_my_response

    then_i_see_the_response_page(back: true)
    and_i_see_the_correct_response_selected
  end

  scenario "reviewing an incorrect response" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_submit_an_incorrect_response(
      details: "Fact check error detail test string",
    )

    then_i_see_my_factual_error_details
  end

  scenario "changing an incorrect response" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_submit_an_incorrect_response(
      details: "Fact check error detail test string",
    )

    and_i_change_my_response

    then_i_see_the_response_page(back: true)
    and_i_see_the_incorrect_response_selected
    and_i_see_my_factual_error_details_on_the_response_page
  end

  scenario "submitting an incorrect response" do
    given_the_publisher_api_submission_succeeds
    given_there_is_a_fact_check_request

    when_i_submit_an_incorrect_response(
      details: "Fact check error detail test string",
    )

    when_i_confirm_my_response

    then_i_see_the_response_submitted_page
  end

  context "when validation fails" do
    scenario "without selecting a response" do
      given_the_publisher_api_submission_succeeds
      given_there_is_a_fact_check_request

      when_i_start_responding_to_the_fact_check
      and_i_continue_without_selecting_a_response

      then_i_see_a_selection_error
    end

    scenario "when selecting incorrect without entering details" do
      given_the_publisher_api_submission_succeeds
      given_there_is_a_fact_check_request

      when_i_start_responding_to_the_fact_check
      and_i_choose_that_the_content_is_incorrect
      and_i_continue_my_response

      then_i_see_a_factual_errors_validation_error
    end
  end

  context "when a response has already been submitted" do
    scenario "preventing another response" do
      given_the_publisher_api_submission_succeeds
      given_there_is_a_submitted_fact_check_response

      when_i_visit_the_response_page

      then_i_see_the_already_submitted_page
    end
  end

  context "when the Publisher API submission fails" do
    scenario "showing an error to the user" do
      given_the_publisher_api_submission_fails
      given_there_is_a_fact_check_request

      when_i_submit_a_correct_response
      and_i_confirm_my_response

      then_i_see_a_submission_error
    end
  end

  # -----------------------------------------------------------------------------
  # Given
  # -----------------------------------------------------------------------------

  def given_the_publisher_api_submission_succeeds
    allow(PublisherApiService).to receive(:post_fact_check_response)
      .and_return(double(code: 200))
  end

  def given_the_publisher_api_submission_fails
    allow(PublisherApiService).to receive(:post_fact_check_response)
      .and_raise(PublishingPlatformApi::HTTPErrorResponse.new(422, "", "forced test error"))
  end

  def given_there_is_a_fact_check_request
    current_user = PublishingPlatform::SSO.test_user = create(:user)

    @request = create(
      :request,
      :with_collaborator,
      collaborator: current_user,
      previous_content: {
        "test_id" => {
          "heading" => "Test Heading",
          "body" => "<div>This is the unchanged line.</div><div>This line will be changed</div>",
        },
      },
      current_content: {
        "test_id" => {
          "heading" => "Test Heading",
          "body" => "<div>This is the unchanged line.</div><div>This line has changes</div>",
        },
      },
    )
  end

  def given_there_is_a_submitted_fact_check_response
    given_there_is_a_fact_check_request
    create(:response, request: @request)
  end

  # -----------------------------------------------------------------------------
  # When
  # -----------------------------------------------------------------------------

  def when_i_visit_the_response_page
    visit respond_path(
      source_app: @request.source_app,
      source_id: @request.source_id,
    )
  end

  def when_i_start_responding_to_the_fact_check
    visit compare_path(
      source_app: @request.source_app,
      source_id: @request.source_id,
    )

    click_on I18n.t("fact_check_comparison.respond_to_button")

    then_i_see_the_response_page
  end

  def when_i_submit_a_correct_response
    when_i_start_responding_to_the_fact_check

    choose(I18n.t("fact_check_response.correct"), allow_label_click: true)
    and_i_continue_my_response
    then_i_see_the_response_confirmation_page
  end

  def when_i_submit_an_incorrect_response(details:)
    when_i_start_responding_to_the_fact_check

    choose(I18n.t("fact_check_response.incorrect"), allow_label_click: true)
    fill_in "fact_check_response_body", with: details

    and_i_continue_my_response
    then_i_see_the_response_confirmation_page
  end

  def and_i_choose_that_the_content_is_incorrect
    choose(I18n.t("fact_check_response.incorrect"), allow_label_click: true)
  end

  def and_i_continue_my_response
    click_button I18n.t("fact_check_response.continue_button")
  end

  def when_i_confirm_my_response
    click_button I18n.t("fact_check_confirm.confirm_button")
  end

  alias_method :and_i_confirm_my_response, :when_i_confirm_my_response

  def and_i_change_my_response
    click_on I18n.t("fact_check_confirm.change_link"), match: :first
  end

  def and_i_return_to_the_comparison_page
    click_on "Back"
  end

  def and_i_continue_without_selecting_a_response
    click_button I18n.t("fact_check_response.continue_button")
  end

  # -----------------------------------------------------------------------------
  # Then
  # -----------------------------------------------------------------------------

  def then_i_see_the_fact_check_comparison
    expect(page).to have_text("This line will be changed")
  end

  def then_i_see_the_response_page(back: false)
    expect(page).to have_current_path(
      respond_path(
        source_app: @request.source_app,
        source_id: @request.source_id,
        back: back.presence,
      ),
    )

    expect(page).to have_text(I18n.t("fact_check_response.heading"))
  end

  def then_i_see_the_response_confirmation_page
    expect(page).to have_current_path(
      validate_path(
        source_app: @request.source_app,
        source_id: @request.source_id,
      ),
    )

    expect(page).to have_text(I18n.t("fact_check_confirm.heading"))
  end

  def then_i_see_the_response_submitted_page
    expect(page).to have_current_path(
      confirm_path(
        source_app: @request.source_app,
        source_id: @request.source_id,
      ),
    )

    expect(page).to have_text(
      I18n.t("fact_check_submitted.fact_check_submitted"),
    )
  end

  def and_i_see_the_correct_response_selected
    expect(page).to have_checked_field(
      I18n.t("fact_check_response.correct"),
      visible: :all,
    )
  end

  def and_i_see_the_incorrect_response_selected
    expect(page).to have_checked_field(
      I18n.t("fact_check_response.incorrect"),
      visible: :all,
    )
  end

  def then_i_see_my_factual_error_details
    then_i_see_the_response_confirmation_page

    expect(page).to have_text(
      I18n.t("fact_check_confirm.factual_errors"),
    )

    expect(page).to have_text("Fact check error detail test string")
  end

  def and_i_see_my_factual_error_details_on_the_response_page
    expect(page).to have_field(
      "fact_check_response_body",
      with: "Fact check error detail test string",
    )
  end

  def then_i_see_a_selection_error
    expect(page).to have_text(
      I18n.t("fact_check_response.selection_error"),
    )
  end

  def then_i_see_a_factual_errors_validation_error
    expect(page).to have_text(
      I18n.t("fact_check_response.factual_errors_empty_field"),
    )
  end

  def then_i_see_the_already_submitted_page
    expect(page).to have_text(
      I18n.t("fact_check_already_submitted.heading"),
    )
  end

  def then_i_see_a_submission_error
    expect(page).to have_current_path(
      confirm_path(
        source_app: @request.source_app,
        source_id: @request.source_id,
      ),
    )

    expect(page).to have_text(
      I18n.t("fact_check_confirm.error_heading"),
    )

    expect(page).to have_text(
      I18n.t("fact_check_confirm.api_submission_error"),
    )
  end
end
