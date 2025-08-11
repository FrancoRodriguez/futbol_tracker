class MatchesController < ApplicationController
  before_action :set_match, only: [:show, :edit, :update, :destroy, :autobalance]
  before_action :set_teams, only: [:show]
  before_action :available_players, :available_players_mvp, only: [:show]

  include MatchesHelper

  def index
    @next_match = Match
                    .where("date >= ?", Time.zone.today)
                    .order(date: :asc)
                    .first

    @past_matches = Match
                      .includes(participations: [:player, :team])
                      .where("date < ?", Time.zone.today)
                      .order(date: :desc)
                      .page(params[:page])
                      .per(PAGINATION_NUMBER)

    @match_results = @past_matches.map do |match|
      teams = match.participations.map(&:team).uniq
      {
        match: match,
        result_message: calculate_team_goals(teams, match.participations)
      }
    end

    @top_mvp = Player.top_mvp
    @top_winners = Player.top_winners
  end


  def show
    @participations = @match.participations.includes(:player)
    @teams = [@match.home_team, @match.away_team].compact
    @team_win_percentages = {}

    # 1) Fuerza por equipo
    strengths = {}

    @teams.each do |team|
      players = @participations.select { |p| p.team_id == team.id }.map(&:player)
      eligible = players.select { |pl| pl.total_matches >= Player::MIN_MATCHES }
      next if eligible.empty?

      strengths[team.id] = eligible.sum { |pl| pl.total_wins.to_f / pl.total_matches.to_f }
    end

    # 2) Normalizar para que sumen 100%
    if strengths.size == 2
      ids = strengths.keys
      total_strength = strengths.values.sum

      if total_strength.positive?
        a = ((strengths[ids[0]] / total_strength) * 100).round(1)
        b = (100 - a).round(1) # asegura 100% total

        @team_win_percentages[ids[0]] = a
        @team_win_percentages[ids[1]] = b
      end
    end

    weather_service = WeatherService.new
    @match_weather = weather_service.forecast_for(@match.date)

    # (Opcional) Previsualizar sin guardar
    if params[:preview_autobalance].present?
      @team_a, @team_b = TeamBalancer.new(@participations.map(&:player)).call
    end
  end

  def autobalance
    parts   = @match.participations.includes(:player)
    team_a, team_b = TeamBalancer.new(parts.map(&:player)).call

    # Asegura equipos home/away
    home = @match.home_team || @match.build_home_team(name: 'Equipo Blanco')
    away = @match.away_team || @match.build_away_team(name: 'Equipo Negro')
    @match.save! if @match.changed?

    # Asignar team_id a las participaciones
    parts.each do |p|
      if team_a.include?(p.player)
        p.update!(team: home)
      elsif team_b.include?(p.player)
        p.update!(team: away)
      end
    end

    redirect_to @match, notice: 'Equipos balanceados automáticamente.'
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
