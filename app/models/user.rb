class User < ApplicationRecord
  include PublishingPlatform::SSO::User
  serialize :permissions, type: Array, coder: YAML

  has_many :collaborations
  has_many :requests, through: :collaborations
  has_many :responses

  def publishing_platform_admin?
    permissions.include?("publishing_platform_admin")
  end
end
