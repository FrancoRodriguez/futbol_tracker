class Admin::CachesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def clear
    authorize :cache, :clear?

    Rails.cache.clear
    redirect_back fallback_location: root_path, notice: "Caché borrado correctamente."
  end
end
