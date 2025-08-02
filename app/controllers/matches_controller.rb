class MatchesController < ApplicationController
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_teams, only: [:show]
  before_action :available_players, :available_players_mvp, only: [:show]

  include MatchesHelper

  def index
    @matches = Match.order(date: :desc)
    @next_match = @matches.where("date >= ?", Time.zone.today).first
    @past_matches = @matches.where("date < ?", Time.zone.today).page(params[:page]).per(PAGINATION_NUMBER)

    @match_results = @matches.map do |match|
      participations = match.participations.includes(:player)
      teams = participations.map(&:team).uniq
      {
        match: match,
        result_message: calculate_team_goals(teams, participations)
      }
    end

    @top_mvp = Player.joins(:mvp_matches).group(:id).order('COUNT(matches.id) DESC').first

    @top_players = Player
                     .joins(participations: :match)
                     .where.not('matches.result ~* ?', '^\s*(\d+)-\1\s*$')
                     .select(
                       'players.*,
       COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) AS total_wins'
                     )
                     .group('players.id')
                     .order('total_wins DESC')
                     .limit(3)
  end

  def show
    @participations = @match.participations.includes(:player)
    @teams = [@match.home_team, @match.away_team].compact

    @team_win_percentages = {}

    @teams.each do |team|
      players = @participations.select { |p| p.team_id == team.id }.map(&:player)

      next if players.empty?

      # Suma simple de porcentaje de victorias individuales
      total = players.sum do |player|
        player.total_matches.to_i > 0 ? (player.total_wins.to_f / player.total_matches) : 0
      end

      average = (total / players.size * 100).round(1)
      @team_win_percentages[team.id] = average
    end
  end


  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)
    if @match.save!
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

  def available_players
    @available_players = Player.where.not(id: Participation.where(match_id: @match.id)
                                                           .select(:player_id))
  end

  def available_players_mvp
    @available_players_mvp = Player.joins(:participations).where(participations: { match_id: @match.id })
  end

  def match_params
    params.require(:match).permit(:date, :location, :result, :home_team_id, :away_team_id, :video_url, :mvp_id, :win_id)
  end

end
