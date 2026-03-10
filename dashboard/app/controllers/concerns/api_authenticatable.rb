module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    token = request.headers["Authorization"]&.remove("Bearer ")
    return if token.present? && ActiveSupport::SecurityUtils.secure_compare(token, api_key)

    render json: {error: "Unauthorized"}, status: :unauthorized
  end

  def api_key
    ENV.fetch("DASHBOARD_API_KEY")
  end
end
