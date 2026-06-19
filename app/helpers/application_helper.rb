module ApplicationHelper
  def navigation_items
    return [] unless current_user

    items = []

    items << { text: current_user.name, href: PublishingPlatformLocation.external_url_for("signon") }
    items << { text: "Sign out", href: publishing_platform_sign_out_path }
  end
end
