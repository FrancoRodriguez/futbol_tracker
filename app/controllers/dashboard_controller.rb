class DashboardController < ApplicationController
  def index
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    if @next_match
      weather_service = WeatherService.new
      @next_match_weather = weather_service.forecast_for(@next_match.date)
    end
    @top_mvp = Player.top_mvp
    @top_winners = Player.top_winners
  end
end
