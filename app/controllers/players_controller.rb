class PlayersController < ApplicationController
  before_action :set_player, only: [:show, :edit, :update, :destroy]

  include PlayersHelper

  def show
    @results_count = @player.results_count
    @chart_data = @player.chart_data
    @participations = @player.past_participations.page(params[:page]).per(PAGINATION_NUMBER)
  end

  def new
    @player = Player.new
  end

  def index
    @players = Player.left_joins(:participations).group('players.id').order('COUNT(participations.id) DESC')
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
    @players = Player.mvp_ranking
  end

  def win_ranking
    @top_players = Player.win_ranking
  end

  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info, :profile_photo)
  end
end
