class DashboardController < ApplicationController
  require "ostruct"

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @active_season = Season.active.first
    season_key     = @active_season&.id || "global"

    # Próximo partido + clima
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    if @next_match
      @next_match_weather = Rails.cache.fetch([ "weather_forecast", @next_match.date ], expires_in: 1.hour) do
        WeatherService.new.forecast_for(@next_match.date)
      end
    end

    # ——— TOP del último mes (recortado a la ventana de la temporada activa) ———
    @top_last_month = Player.top_last_month(positions: 3, season: Season.first)
    players_last_month = @top_last_month.map(&:player)
    ActiveRecord::Associations::Preloader.new(
      records: players_last_month,
      associations: { profile_photo_attachment: :blob }
    ).call

    # ——— Tops por temporada (desde player_stats) ———
    # TTL: hasta el próximo jueves a medianoche
    next_thursday = Time.zone.today.next_occurring(:thursday).beginning_of_day
    ttl_seconds   = [ (next_thursday - Time.zone.now).to_i, 5.minutes ].max

    @top_mvp = Rails.cache.fetch([ "top_mvp", season_key ], expires_in: ttl_seconds) do
      Player.top_mvp(season: @active_season) # 1 jugador con más MVPs en la season
    end

    if @top_mvp
      stats = @top_mvp.stats_for(season: @active_season)
      @top_mvp_count     = @top_mvp.mvp_count.to_i
      @top_mvp_games     = stats.total_matches
      @top_mvp_rate      = @top_mvp_games.positive? ? ((100.0 * @top_mvp_count / @top_mvp_games).round) : 0
      @top_mvp_last_date = Match.where(mvp_id: @top_mvp.id, date: @active_season.starts_on..@active_season.ends_on)
                                .order(date: :desc).limit(1).pick(:date)
    end

    @top_winners = Rails.cache.fetch([ "top_winners", season_key ], expires_in: ttl_seconds) do
      Player.top_winners(limit: 5, season: @active_season) # top 3 ranking por victorias de la season
    end

    # Temporada pasada (la inmediatamente anterior a la activa)
    @prev_season = if @active_season
                     Season.where("ends_on < ?", @active_season.starts_on).order(ends_on: :desc).first
    end

    if @prev_season
      prev_key = @prev_season.id

      @prev_top_winners = Rails.cache.fetch([ "prev_top_winners", prev_key ], expires_in: 12.hours) do
        Player.top_winners(limit: 3, season: @prev_season)
      end

      @prev_mvp = Rails.cache.fetch([ "prev_mvp_leader", prev_key ], expires_in: 12.hours) do
        Player.mvp_ranking(season: @prev_season).first
      end
      @prev_mvp_stats = @prev_mvp&.stats_for(season: @prev_season)
      @prev_mvp_count = @prev_mvp&.mvp_count.to_i

      @prev_ironman = Rails.cache.fetch([ "prev_most_matches", prev_key ], expires_in: 12.hours) do
        Player.joins(:player_stats)
              .where(player_stats: { season_id: @prev_season.id })
              .select("players.*, player_stats.total_matches AS matches_count")
              .order("matches_count DESC, players.name ASC")
              .first
      end

      ActiveRecord::Associations::Preloader.new(
        records: [ *@prev_top_winners, @prev_mvp, @prev_ironman ].compact,
        associations: { profile_photo_attachment: :blob }
      ).call
    end
  end
end
