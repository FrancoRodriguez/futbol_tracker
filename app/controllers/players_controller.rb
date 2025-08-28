# app/controllers/players_controller.rb
class PlayersController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :set_player,         only: %i[show edit update destroy]

  include PlayersHelper

  def index
    @players = policy_scope(Player)
                 .left_joins(:participations)
                 .group("players.id")
                 .order("COUNT(participations.id) DESC")
  end

  def show
    authorize @player
    next_thursday = Time.zone.today.next_occurring(:thursday).beginning_of_day
    ttl_seconds   = [ (next_thursday - Time.zone.now).to_i, 5.minutes ].max

    @selected_season =
      if params.key?(:season_id)
        params[:season_id].present? ? Season.find_by(id: params[:season_id]) : nil
      else
        Season.active.first
      end

    season_cache_key = @selected_season&.id || 'global'

    @seasons         = Season.order(starts_on: :desc)
    @season          = @selected_season
    @stat            = @player.stats_for(season: @season)
    @results_count   = { victories: @stat.total_wins, defeats: @stat.total_losses, draws: @stat.total_draws }
    @chart_data      = @player.chart_data_for(season: @season)
    @participations  = @player.participations_in(season: @season).page(params[:page]).per(PAGINATION_NUMBER)
    @synergy = Rails.cache.fetch([ "synergy-#{@player.id}", season_cache_key ], expires_in: ttl_seconds) do
      @player.synergy_for(season: @season)
    end
  end

  def new
    @player = Player.new
    authorize @player
  end

  def create
    @player = Player.new(player_params)
    authorize @player

    if @player.save
      redirect_to @player, notice: "Jugador #{@player.full_name} creado exitosamente."
    else
      render :new
    end
  end

  def edit
    authorize @player
  end

  def update
    authorize @player
    if @player.update(player_params)
      redirect_to @player, notice: "Jugador #{@player.full_name} actualizado exitosamente."
    else
      render :edit
    end
  end

  def destroy
    authorize @player
    full_name = @player.full_name
    @player.destroy
    redirect_to players_path, notice: "Jugador #{full_name} eliminado exitosamente."
  end

  # ===== RANKINGS PÚBLICOS =====
  # Como no queremos exigir autorización aquí, indicamos a Pundit que omita la verificación.
  def mvp_ranking
    skip_authorization

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
    skip_authorization

    @seasons = Season.order(starts_on: :desc)
    @selected_season =
      if params.key?(:season_id)
        params[:season_id].present? ? Season.find_by(id: params[:season_id]) : nil
      else
        Season.active.first
      end

    @top_players = Player.win_ranking(season: @selected_season)
  end

  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info, :profile_photo, :primary_position_id, position_ids: [])
  end
end
