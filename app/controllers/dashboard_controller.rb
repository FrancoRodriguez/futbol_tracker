class DashboardController < ApplicationController
  def index
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    if @next_match
      @next_match_weather = Rails.cache.fetch([ "weather_forecast", @next_match.date ], expires_in: 1.hour) do
        WeatherService.new.forecast_for(@next_match.date)
      end
    end

    @top_last_month = Player.top_last_month(positions: 3)

    players = @top_last_month.map(&:player)
    ActiveRecord::Associations::Preloader.new(
      records: players,
      associations: { profile_photo_attachment: :blob }
    ).call

    # Tops cacheados
    # más preciso y expirar justo antes del próximo jueves:
    next_thursday = Time.zone.today.next_occurring(:thursday).beginning_of_day
    ttl_seconds = (next_thursday - Time.zone.now).to_i
    @top_mvp = Rails.cache.fetch("top_mvp_global", expires_in: ttl_seconds) { Player.top_mvp }
    @top_winners = Rails.cache.fetch("top_winners_global", expires_in: ttl_seconds) { Player.top_winners }
  end
end
