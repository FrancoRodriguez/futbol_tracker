class MatchesController < ApplicationController
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_teams, only: [:show]

  def index
    @matches = Match.order(:date)
    @next_match = @matches.where("date >= ?", Time.zone.today).first
    @past_matches = @matches.where("date < ?", Time.zone.today)
  end

  def show
    @participations = @match.participations.includes(:player)
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)
    if @match.save
      redirect_to @match, notice: 'El partido fue creado con éxito.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: 'Partido actualizado exitosamente.'
    else
      render :edit
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_path, notice: 'Partido eliminado exitosamente.'
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def set_teams
    @teams = @match.participations.includes(:player).map(&:team).uniq
  end

  def match_params
    params.require(:match).permit(:location, :date, :result, player_ids: [])
  end
end
