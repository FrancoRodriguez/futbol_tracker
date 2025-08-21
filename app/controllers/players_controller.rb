class PlayersController < ApplicationController
  before_action :set_player, only: [ :show, :edit, :update, :destroy ]

  include PlayersHelper

  def show
    # Season seleccionada (Global si llega season_id vacío; si no llega el param, usa la activa)
    @selected_season =
      if params.key?(:season_id)
        params[:season_id].present? ? Season.find_by(id: params[:season_id]) : nil
      else
        Season.active.first
      end

    @seasons = Season.order(starts_on: :desc)

    @season = @selected_season
    @stat   = @player.stats_for(season: @season)
    @results_count = { victories: @stat.total_wins, defeats: @stat.total_losses, draws: @stat.total_draws }
    @chart_data    = @player.chart_data_for(season: @season)
    @participations = @player.participations_in(season: @season).page(params[:page]).per(PAGINATION_NUMBER)
  end


  def new
    @player = Player.new
  end

  def index
    @players = Player.left_joins(:participations).group("players.id").order("COUNT(participations.id) DESC")
  end

  def create
    @player = Player.new(player_params)
    if @player.save
      redirect_to @player, notice: "Jugador #{@player.full_name} creado exitosamente."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @player.update(player_params)
      redirect_to @player, notice: "Jugador #{@player.full_name} actualizado exitosamente."
    else
      render :edit
    end
  end

  def destroy
    full_name = @player.full_name
    @player.destroy
    redirect_to players_path, notice: "Jugador #{full_name} eliminado exitosamente."
  end

  def mvp_ranking
    @seasons = Season.order(starts_on: :desc)
    @selected_season =
      if params.key?(:season_id)
        params[:season_id].present? ? Season.find_by(id: params[:season_id]) : nil
      else
        Season.active.first
      end

    @players = Player.mvp_ranking(season: @selected_season)
  end

  def win_ranking
    @seasons = Season.order(starts_on: :desc)

    if params.key?(:season_id)
      # El usuario tocó el selector: usa la elegida o Global si viene vacío
      @selected_season = params[:season_id].present? ? Season.find_by(id: params[:season_id]) : nil
    else
      # Por defecto: GLOBAL (todas las seasons)
      @selected_season = Season.active.first
    end

    @top_players = Player.win_ranking(season: @selected_season)
  end


  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info, :profile_photo)
  end
end
