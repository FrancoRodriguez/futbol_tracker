class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Solo navegadores modernos
  allow_browser versions: :modern

  before_action :ensure_voter_cookie!

  after_action :verify_authorized, unless: :pundit_skip_or_index?
  after_action :verify_policy_scoped, if: :pundit_scope_check?

  PAGINATION_NUMBER = 5

  rescue_from Pundit::NotAuthorizedError do
    redirect_back fallback_location: root_path, alert: "No estás autorizado para realizar esta acción."
  end

  private

  def pundit_skip?
    devise_controller? || params[:controller].start_with?("active_storage/", "rails/mailers")
  end

  def pundit_skip_or_index?
    pundit_skip? || action_name == "index"
  end

  def pundit_scope_check?
    !pundit_skip? && action_name == "index"
  end

  def ensure_voter_cookie!
    return if cookies.signed[:voter_id].present?
    cookies.signed[:voter_id] = {
      value: SecureRandom.uuid,
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax
    }
  end

  def duel_voter_key
    raw = cookies.signed[:voter_id].to_s
    Digest::SHA256.hexdigest(raw)
  end
  helper_method :duel_voter_key
end
