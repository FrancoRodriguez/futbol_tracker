class PlayersController < ApplicationController
  before_action :set_player, only: [:show, :edit, :update, :destroy]

  include PlayersHelper

  def show
    @results_count = @player.results_count
    @chart_data = @player.chart_data
    @win_rate = @player.win_rate
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
    @players = Player.joins(:mvp_matches)
                     .select('players.*, COUNT(matches.id) AS mvp_count')
                     .group('players.id')
                     .order('mvp_count DESC')
  end

  def win_ranking
    @top_players = Player
                     .joins(participations: :match)
                     .where.not('matches.result ~* ?', '^\s*(\d+)-\1\s*$') # Excluir empates
                     .select(
                       'players.*,
      COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) AS total_wins,
      COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END) AS total_losses,
      (COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) -
       COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END)) AS win_diff,
      COUNT(*) AS total_matches'
                     )
                     .group('players.id')
                     .order('win_diff DESC, total_matches DESC')
  end

  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info, :profile_photo)
  end
end
