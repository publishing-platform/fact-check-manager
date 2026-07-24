class FactCheckResponseController < ApplicationController
  include AuthenticationHelper

  before_action :set_request, :check_access, only: %i[respond validate confirm]
  before_action :check_already_responded, only: %i[respond validate confirm]

  def respond
    session.delete(:fact_check_response) unless params[:back]
    @errors = {}
    @form_data = session.fetch(:fact_check_response, {}).with_indifferent_access
  end

  def validate
    @form_data = permitted_params
    @errors = validate_form_data(@form_data)

    if @errors.any?
      render :respond
    else
      session[:fact_check_response] = @form_data
      render :confirm
    end
  end

  def confirm
    @errors = []
    @form_data = permitted_params

    @response = Response.new(
      request: @request,
      user: current_user,
      accepted: @form_data[:accepted],
      body: @form_data[:accepted] == "false" ? @form_data[:body] : nil,
    )

    ActiveRecord::Base.transaction do
      if @response.save
        begin
          PublisherApiService.post_fact_check_response(@response)
        rescue PublishingPlatformApi::HTTPErrorResponse
          @errors << t("fact_check_confirm.api_submission_error")
          raise ActiveRecord::Rollback
        end

        if @response.accepted
          FactCheckMailer.response_accepted_email(
            @response.user,
            @response,
          ).deliver_later
        else
          FactCheckMailer.response_rejected_email(
            @response.user,
            @response,
          ).deliver_later
        end
      else
        @errors = @response.errors.full_messages
      end
    end

    if @errors.present?
      render
    else
      session.delete(:fact_check_response)
      render :submitted
    end
  end

private

  def set_request
    @request = Request.most_recent_for_source(source_app: params[:source_app], source_id: params[:source_id])
    raise ActiveRecord::RecordNotFound, "No request found" unless @request
  end

  def check_already_responded
    return if @request.response.blank?

    render "shared/fact_check_already_submitted"
  end

  def check_access
    check_permissions(current_user, @request)
  end

  def permitted_params
    params.require(:fact_check_response)
          .permit(:accepted, :body)
  end

  def validate_form_data(data)
    errors = {}
    errors[:accepted] = t("fact_check_response.selection_error") if data[:accepted].blank?

    if data[:accepted] == "false" && data[:body].blank?
      errors[:body] = t("fact_check_response.factual_errors_empty_field")
    end

    errors
  end
end
