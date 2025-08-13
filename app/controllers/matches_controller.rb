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
    # Pre-carga para evitar N+1 (incluye avatar)
    @participations = @match.participations.includes(player: { profile_photo_attachment: :blob })
    @teams = [@match.home_team, @match.away_team].compact

    @team_win_percentages = {}
    @featured_by_team     = {}

    # Helpers locales
    wr = ->(pl) { pl.total_matches.to_i > 0 ? (pl.total_wins.to_f / pl.total_matches.to_f) : nil }
    rt = ->(pl) { (pl.respond_to?(:rating) && pl.rating.present?) ? pl.rating.to_f : 0.0 }

    pick_best_by_wr = lambda do |players|
      return nil if players.blank?

      # 1) elegibles por mínimo de partidos
      eligible = players.select { |pl| pl.total_matches.to_i >= Player::MIN_MATCHES && wr.call(pl) }
      # 2) si no hay elegibles, tomar los que tengan al menos un partido
      with_matches = players.select { |pl| wr.call(pl) }

      pool = eligible.presence || with_matches.presence || players
      # Orden: win rate desc, luego partidos desc, luego rating desc
      pool.max_by { |pl| [wr.call(pl) || -1.0, pl.total_matches.to_i, rt.call(pl)] }
    end

    # --- Destacado por equipo (para listas y VS) => mejor win rate ---
    @teams.each do |team|
      players = @participations.select { |p| p.team_id == team.id }.map(&:player)
      next if players.empty?
      @featured_by_team[team.id] = pick_best_by_wr.call(players)
    end

    # --- Probabilidad por equipo (normalizada a 100%) ---
    strengths = {}
    @teams.each do |team|
      players  = @participations.select { |p| p.team_id == team.id }.map(&:player)
      eligible = players.select { |pl| pl.total_matches.to_i >= Player::MIN_MATCHES }
      next if eligible.empty?
      strengths[team.id] = eligible.sum { |pl| pl.total_wins.to_f / pl.total_matches.to_f }
    end

    case strengths.size
    when 2
      ids   = strengths.keys
      total = strengths.values.sum
      if total.positive?
        a = ((strengths[ids[0]] / total) * 100).round(1)
        b = (100 - a).round(1)
        @team_win_percentages[ids[0]] = a
        @team_win_percentages[ids[1]] = b
      end
    when 1
      only_id  = strengths.keys.first
      other_id = (@teams.map(&:id) - [only_id]).first
      @team_win_percentages[only_id] = 50.0
      @team_win_percentages[other_id] = 50.0 if other_id
    end

    # --- Clima ---
    weather_service = WeatherService.new
    @match_weather  = weather_service.forecast_for(@match.date)

    # --- Previsualización (autobalancer) ---
    if params[:preview_autobalance].present?
      @team_a, @team_b = TeamBalancer.new(@participations.map(&:player)).call
    end

    # --- VS (Duelo de la Fecha) basado en mejor win rate + votos reales ---
    home = @match.home_team
    away = @match.away_team
    if home && away && @featured_by_team[home.id] && @featured_by_team[away.id]
      @duel_a = @featured_by_team[home.id]
      @duel_b = @featured_by_team[away.id]
      @vs_label = "Mejor win rate (mín. #{Player::MIN_MATCHES} PJ)"

      # Lee votos reales solo de los dos jugadores del VS
      counts = DuelVote.where(match_id: @match.id, player_id: [@duel_a.id, @duel_b.id])
                       .group(:player_id).count

      a_ct = counts.fetch(@duel_a.id, 0)
      b_ct = counts.fetch(@duel_b.id, 0)
      tot  = a_ct + b_ct

      if tot.positive?
        @duel_a_pct = (a_ct * 100.0 / tot).round(1)
        @duel_b_pct = (100.0 - @duel_a_pct).round(1)  # asegura 100%
      else
        @duel_a_pct = 50.0
        @duel_b_pct = 50.0
      end

      @duel_total       = tot
      @your_duel_choice = DuelVote.where(match_id: @match.id, voter_key: duel_voter_key).pick(:player_id)
    end

    # --- MVP (chips y modal) ---
    players_in_match       = @participations.map(&:player).uniq
    @available_players_mvp = players_in_match.sort_by(&:full_name)
    if @match.mvp.present?
      mvp_p = @match.mvp
      @mvp_total_awards = Match.where(mvp_id: mvp_p.id).count
      @mvp_win_rate     = mvp_p.total_matches.to_i > 0 ?
                            ((mvp_p.total_wins.to_f / mvp_p.total_matches) * 100).round(1) : nil
    end

    # --- Disponibles para alta (simple / múltiple), ordenados por rendimiento ---
    @available_players = Player.where.not(id: players_in_match.map(&:id))
                               .includes(profile_photo_attachment: :blob)
                               .to_a

    # Orden: win rate (o 50 si N/A), luego partidos, luego nombre
    wr_val = ->(pl) { pl.respond_to?(:win_rate_pct) ? (pl.win_rate_pct || 50.0) : (wr.call(pl) ? (wr.call(pl) * 100).round(1) : 50.0) }
    @available_players.sort_by! { |pl| [-wr_val.call(pl), -pl.total_matches.to_i, pl.full_name] }
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
