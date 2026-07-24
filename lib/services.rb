module Services
  def self.publisher_api
    @publisher_api ||= PublishingPlatformApi::Publisher.new(
      PublishingPlatformLocation.find("publisher"),
      bearer_token: ENV.fetch("PUBLISHER_BEARER_TOKEN", "example"),
    )
  end
end
