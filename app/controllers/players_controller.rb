class PlayersController < ApplicationController
  before_action :set_player, only: [:show, :edit, :update, :destroy]

  def show
    @player = Player.find(params[:id])
    @results_count = {victories: 0, defeats: 0, draws: 0}

    @player.participations.each do |participation|
      match = participation.match
      participations = match.participations.includes(:player)
      opponent_participation = participations.reject { |p| p.team == participation.team }.first

      if opponent_participation
        opponent_team_goals = opponent_participation.goals
        player_team_goals = participation.goals

        if player_team_goals > opponent_team_goals
          @results_count[:victories] += 1
        elsif player_team_goals < opponent_team_goals
          @results_count[:defeats] += 1
        else
          @results_count[:draws] += 1
        end
      end
    end
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

  def goal_scorers
    @goal_scorers = Participation
                      .select('players.id AS player_id, players.name, SUM(participations.goals) AS total_goals')
                      .joins(:player)
                      .group('players.id, players.name')
                      .order('total_goals DESC')
  end

  def assist_scorers
    @assist_scorers = Participation
                        .select('players.id AS player_id, players.name, SUM(participations.assists) AS total_assists')
                        .joins(:player)
                        .group('players.id')
                        .order('total_assists DESC')
  end

  def mvp_ranking
    @players = Player.joins(:mvp_matches)
                     .select('players.*, COUNT(matches.id) AS mvp_count')
                     .group('players.id')
                     .order('mvp_count DESC')
  end

  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info)
  end
end
