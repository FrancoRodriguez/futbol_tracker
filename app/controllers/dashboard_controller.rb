class DashboardController < ApplicationController
  require "ostruct"
  def index
    @active_season = Season.active.first

    # Próximo partido + clima
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    if @next_match
      @next_match_weather = Rails.cache.fetch([ "weather_forecast", @next_match.date ], expires_in: 1.hour) do
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
    ttl_seconds   = [ (next_thursday - Time.zone.now).to_i, 5.minutes ].max

    @top_mvp = Rails.cache.fetch([ "top_mvp", @active_season ], expires_in: ttl_seconds) do
      Player.top_mvp(season: @active_season)  # 1 jugador con más MVPs en la season
    end

    if @top_mvp
      # Stats de la season activa para ese jugador
      stats = @top_mvp.stats_for(season: @active_season)

      @top_mvp_count      = @top_mvp.mvp_count.to_i
      @top_mvp_games      = stats.total_matches
      @top_mvp_rate       = @top_mvp_games.positive? ? ((100.0 * @top_mvp_count / @top_mvp_games).round) : 0
      @top_mvp_last_date  = Match.where(mvp_id: @top_mvp.id, date: @active_season.starts_on..@active_season.ends_on)
                                 .order(date: :desc)
                                 .limit(1)
                                 .pick(:date)
    end

    @top_winners = Rails.cache.fetch([ "top_winners", @active_season ], expires_in: ttl_seconds) do
      Player.top_winners(limit: 3, season: @active_season) # top 3 ranking por victorias de la season
    end
  end
end
