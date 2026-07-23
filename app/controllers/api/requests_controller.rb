module Api
  class RequestsController < Api::BaseController
    include AuthenticationHelper

    def create; end

  private

    def send_new_fact_check_request_emails(request)
      request.users.each do |user|
        FactCheckMailer.new_fact_check_request_email(
          user,
          request,
          generate_compare_preview_link(request),
        ).deliver_later
      end
    end
  end
end
