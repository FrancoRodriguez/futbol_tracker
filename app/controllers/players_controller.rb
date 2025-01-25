class PlayersController < ApplicationController
  before_action :set_player, only: [:show, :edit, :update, :destroy]

  def show
    @player = Player.find(params[:id])
    @results_count = {victories: 0, defeats: 0, draws: 0}

    @player.participations.joins(:match).where('matches.date <= ?', Date.today).each do |participation|
      match = participation.match
      next if match.win_id.nil?

      if match.win.name == 'Empate'
        @results_count[:draws] += 1
      elsif match.win_id == participation.team_id
        @results_count[:victories] += 1
      else
        @results_count[:defeats] += 1
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

  def win_ranking
    @players = Player
                 .joins(participations: :match)
                 .where.not('matches.result ~* ?', '^\s*(\d+)-\1\s*$') # Exclude draws where scores are equal
                 .select(
                   'players.*,
                  COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) AS total_wins,
                  COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END) AS total_losses'
                 )
                 .group('players.id')
                 .order(Arel.sql('
                 COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) -
                 COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END) DESC
               ')) # Order by win-loss difference
  end

  private

  def set_player
    @player = Player.find(params[:id])
  end

  def player_params
    params.require(:player).permit(:name, :nickname, :contact_info)
  end
end
