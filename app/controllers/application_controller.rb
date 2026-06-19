class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  include PublishingPlatform::SSO::ControllerMethods

  before_action :authenticate_user!
end
