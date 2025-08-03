class DashboardController < ApplicationController
  def index
    @next_match = Match.where("date >= ?", Time.zone.today).order(date: :asc).first
    @top_mvp = Player.top_mvp
    @top_winners = Player.top_winners
  end
end
