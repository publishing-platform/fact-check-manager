class FactCheckMailer < ApplicationMailer
  include MailerHelper
  helper :authentication

  default from: proc { email_from }

  def new_fact_check_request_email(user, request, compare_link)
    @user = user
    @request = request
    @compare_link = compare_link

    subject = I18n.t("fact_check_mailer.new_fact_check_request_email.subject",
                     title: @request.source_title)
    mail(to: user.email, subject:)
  end
end
