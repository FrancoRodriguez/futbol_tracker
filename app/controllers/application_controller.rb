class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :ensure_voter_cookie!

  PAGINATION_NUMBER = 5

  private

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
