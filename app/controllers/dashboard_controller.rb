class DashboardController < ApplicationController
  def index
    @active_season = Season.active.first

    # Próximo partido + clima
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    if @next_match
      @next_match_weather = Rails.cache.fetch(["weather_forecast", @next_match.date], expires_in: 1.hour) do
        WeatherService.new.forecast_for(@next_match.date)
      end
    end

    # ——— TOP del último mes (recortado a la ventana de la temporada activa) ———
    @top_last_month = Player.top_last_month(positions: 3, season: @active_season)
    # Preload avatares de esos jugadores
    players_last_month = @top_last_month.map(&:player)
    ActiveRecord::Associations::Preloader.new(
      records: players_last_month, associations: { profile_photo_attachment: :blob }
    ).call

    # ——— Tops por temporada (desde player_stats) ———
    # TTL: hasta el próximo jueves a medianoche
    next_thursday = Time.zone.today.next_occurring(:thursday).beginning_of_day
    ttl_seconds   = [(next_thursday - Time.zone.now).to_i, 5.minutes].max

    season_key = @active_season&.id || "global"

    @top_mvp = Rails.cache.fetch(["top_mvp", season_key], expires_in: ttl_seconds) do
      Player.top_mvp(season: @active_season)  # 1 jugador con más MVPs en la season
    end

    @top_winners = Rails.cache.fetch(["top_winners", season_key], expires_in: ttl_seconds) do
      Player.top_winners(limit: 3, season: @active_season) # top 3 ranking por victorias de la season
    end
  end
end
