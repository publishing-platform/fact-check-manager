Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }

  root to: proc { raise ActionController::RoutingError, "Not found" }

  scope "requests" do
    scope ":source_app" do
      scope ":source_id" do
        get "compare", to: "fact_check_comparison#compare"
        get "respond", to: "fact_check_response#respond"
        post "validate", to: "fact_check_response#validate"
        post "confirm", to: "fact_check_response#confirm"
      end
    end
  end
end
