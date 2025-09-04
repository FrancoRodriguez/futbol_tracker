class SeasonsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_season, only: %i[ show edit update destroy activate deactivate ]

  def index
    @seasons = policy_scope(Season).order(starts_on: :desc)
    authorize Season
  end

  def show
    authorize @season
    @stats = ::Seasons::StatsService.call(season: @season, top_n: 5, min_matches: 3, rating_scale: 10)

    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end

  def new
    @season = Season.new
    authorize @season
  end

  def edit
    authorize @season
  end

  def create
    @season = Season.new(season_params)
    authorize @season
    if @season.save
      redirect_to seasons_path, notice: "Temporada creada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @season
    if @season.update(season_params)
      redirect_to seasons_path, notice: "Temporada actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    authorize @season
    @season.activate_exclusively!
    redirect_to seasons_path, notice: "Temporada activada."
  end

  def destroy
    authorize @season
    @season.destroy
    redirect_to seasons_path, notice: "Temporada eliminada."
  end

  def deactivate
    authorize @season
    @season.update!(active: false)
    redirect_to seasons_path, notice: "Temporada desactivada."
  end

  private

  def set_season
    @season = Season.find(params[:id])
  end

  def season_params
    params.require(:season).permit(:name, :starts_on, :ends_on, :active)
  end
end
