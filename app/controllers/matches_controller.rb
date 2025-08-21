class MatchesController < ApplicationController
  before_action :set_match, only: [ :show, :edit, :update, :destroy, :autobalance ]
  before_action :set_teams, only: [ :show ]
  before_action :available_players, :available_players_mvp, only: [ :show ]

  include MatchesHelper

  def index
    @next_match = Match
                    .where("date >= ?", Time.zone.today)
                    .order(date: :asc)
                    .first

    @past_matches = Match
                      .includes(participations: [ :player, :team ])
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
    vm = Matches::ShowFacade.new(
      match: @match,
      preview_autobalance: params[:preview_autobalance].present?,
      voter_key: (respond_to?(:duel_voter_key) ? duel_voter_key : nil)
    # season: Season.active.first # if you want to filter by active season
    )

    # Maintain compatibility with the current view:
    @participations          = vm.participations
    @teams                   = vm.teams
    @team_win_percentages    = vm.team_win_percentages
    @featured_by_team        = vm.featured_by_team
    @duel_a, @duel_b         = vm.duel_a, vm.duel_b
    @vs_label                = vm.vs_label
    @duel_a_pct, @duel_b_pct = vm.duel_a_pct, vm.duel_b_pct
    @duel_total              = vm.duel_total
    @your_duel_choice        = vm.your_duel_choice
    @mvp_total_awards        = vm.mvp_total_awards
    @mvp_win_rate            = vm.mvp_win_rate
    @available_players_mvp   = vm.available_players_mvp
    @available_players       = vm.available_players
    @win_rate_pct_by_player  = vm.win_rate_pct_by_player
    @team_a, @team_b         = vm.team_a, vm.team_b
    @match_weather           = vm.weather

    p vm
  end

  def autobalance
    parts   = @match.participations.includes(:player)
    team_a, team_b = TeamBalancer.new(parts.map(&:player)).call

    # Asegura equipos home/away
    home = @match.home_team || @match.build_home_team(name: "Equipo Blanco")
    away = @match.away_team || @match.build_away_team(name: "Equipo Negro")
    @match.save! if @match.changed?

    # Asignar team_id a las participaciones
    parts.each do |p|
      if team_a.include?(p.player)
        p.update!(team: home)
      elsif team_b.include?(p.player)
        p.update!(team: away)
      end
    end

    redirect_to @match, notice: "Equipos balanceados automáticamente."
  end


  def new
    @match = Match.new
  end

  def create
    @match = Match.new(match_params)
    if @match.save!
      redirect_to @match, notice: "El partido fue creado con éxito."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: "Partido actualizado exitosamente."
    else
      render :edit
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_path, notice: "Partido eliminado exitosamente."
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
