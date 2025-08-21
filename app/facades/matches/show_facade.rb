# app/facades/matches/show_facade.rb
class Matches::ShowFacade
  attr_reader :participations, :teams,
              :team_win_percentages, :featured_by_team,
              :duel_a, :duel_b, :vs_label, :duel_a_pct, :duel_b_pct, :duel_total, :your_duel_choice,
              :mvp_total_awards, :mvp_win_rate,
              :available_players_mvp, :available_players, :win_rate_pct_by_player,
              :team_a, :team_b, :weather, :eligibles_by_team, :win_prob_source

  def initialize(match:, preview_autobalance: false, voter_key: nil, season: nil)
    @match  = match
    @season = season
    build!(preview_autobalance: preview_autobalance, voter_key: voter_key)
  end

  private

  def build!(preview_autobalance:, voter_key:)
    # Participaciones + equipos
    @participations = @match.participations.includes(player: { profile_photo_attachment: :blob })
    @teams          = [@match.home_team, @match.away_team].compact
    players_in_match = @participations.map(&:player).uniq

    # --- Win rates para jugadores del partido (lee de player_stats y hace fallback a participations)
    wr_map_match = Stats::WinRateReader
                     .new(season: @season, exclude_match: @match)
                     .call(players: players_in_match)

    # --- Destacados por equipo
    @featured_by_team = {}
    @teams.each do |team|
      team_players = @participations.select { |p| p.team_id == team.id }.map(&:player)
      next if team_players.empty?
      @featured_by_team[team.id] = pick_featured(team_players, wr_map_match)
    end

    # --- Probabilidades por equipo (SEASON) + conteo de elegibles
    @eligibles_by_team = {}
    @teams.each do |team|
      team_players = @participations.select { |p| p.team_id == team.id }.map(&:player)
      @eligibles_by_team[team.id] = team_players.count do |pl|
        s = wr_map_match[pl.id]
        s && s[:eligible] && s[:wr]
      end
    end

    strengths = Stats::TeamStrengthCalculator.new.call(match: @match, winrate_map: wr_map_match)
    @team_win_percentages = Stats::WinProbabilityCalculator.new.call(strengths)
    @win_prob_source = :season

    # --- Fallback a GLOBAL si no hay datos con la season seleccionada ---
    if @team_win_percentages.blank? && @season.present?
      wr_map_global = Stats::WinRateReader.new(season: nil, exclude_match: @match).call(players: players_in_match)

      # Recalcula elegibles por equipo con GLOBAL para diagnóstico
      @eligibles_by_team = {}
      @teams.each do |team|
        team_players = @participations.select { |p| p.team_id == team.id }.map(&:player)
        @eligibles_by_team[team.id] = team_players.count do |pl|
          s = wr_map_global[pl.id]
          s && s[:eligible] && s[:wr]
        end
      end

      strengths_global = Stats::TeamStrengthCalculator.new.call(match: @match, winrate_map: wr_map_global)
      @team_win_percentages = Stats::WinProbabilityCalculator.new.call(strengths_global)
      @win_prob_source = (@team_win_percentages.present? ? :global : :none)
    end

    # --- Duelo (VS)
    build_duel!(voter_key)

    # --- MVP
    build_mvp!(wr_map_match)

    # --- Listas y WR de TODOS (jugadores del match + disponibles), sin N+1
    build_available_lists!(players_in_match)

    # --- Clima
    @weather = WeatherService.new.forecast_for(@match.date)

    # --- Previsualización autobalance
    if preview_autobalance
      @team_a, @team_b = TeamBalancer.new(players_in_match).call
    end
  end

  # ========================= Helpers internos =========================

  # Elige destacado priorizando: mayor WR, luego más PJ, luego rating
  def pick_featured(players, wr_map)
    eligibles = players.select { |pl| wr_map[pl.id]&.dig(:eligible) && wr_map[pl.id][:wr] }
    with_wr   = players.select { |pl| wr_map[pl.id]&.dig(:wr) }

    pool = eligibles.presence || with_wr.presence || players
    pool.max_by do |pl|
      st = wr_map[pl.id] || {}
      [st[:wr] || -1.0, st[:tm] || 0, (pl.rating || 0).to_f]
    end
  end

  def build_duel!(voter_key)
    home, away = @match.home_team, @match.away_team
    return unless home && away
    return unless @featured_by_team[home.id] && @featured_by_team[away.id]

    @duel_a  = @featured_by_team[home.id]
    @duel_b  = @featured_by_team[away.id]
    @vs_label = "Mejor win rate (mín. #{Player::MIN_MATCHES} PJ)"

    counts = DuelVote.where(match_id: @match.id, player_id: [@duel_a.id, @duel_b.id])
                     .group(:player_id).count
    a_ct = counts.fetch(@duel_a.id, 0)
    b_ct = counts.fetch(@duel_b.id, 0)
    tot  = a_ct + b_ct

    if tot.positive?
      @duel_a_pct = (a_ct * 100.0 / tot).round(1)
      @duel_b_pct = (100.0 - @duel_a_pct).round(1)
    else
      @duel_a_pct = 50.0
      @duel_b_pct = 50.0
    end

    @duel_total       = tot
    @your_duel_choice = voter_key ? DuelVote.where(match_id: @match.id, voter_key: voter_key).pick(:player_id) : nil
  end

  def build_mvp!(wr_map_match)
    mvp_player = @match.try(:mvp) || Player.find_by(id: @match.mvp_id)
    return unless mvp_player

    # Conteo de MVPs (filtrado por season si aplica)
    rel = Match.where(mvp_id: mvp_player.id).where.not(win_id: nil)
    rel = rel.where(date: @season.starts_on..@season.ends_on) if @season
    @mvp_total_awards = rel.count

    # WR del MVP (si el MVP no está en el partido, léelo aparte)
    wr_map = wr_map_match[mvp_player.id] ? wr_map_match :
               Stats::WinRateReader.new(season: @season, exclude_match: @match).call(players: [mvp_player])

    tm = wr_map[mvp_player.id][:tm]
    tw = wr_map[mvp_player.id][:tw]
    @mvp_win_rate = (tm >= Player::MIN_MATCHES && tm.positive?) ? ((tw.to_f / tm) * 100).round(1) : nil
  end

  def build_available_lists!(players_in_match)
    # Para la lista de candidatos a MVP (solo orden alfabético)
    @available_players_mvp = players_in_match.sort_by { |pl| display_name(pl) }

    # Disponibles para alta
    @available_players = Player.where.not(id: players_in_match.map(&:id))
                               .includes(profile_photo_attachment: :blob)
                               .to_a

    # Mapa WR para TODOS (en partido + disponibles), restando el match en curso si aplica
    all_players = (players_in_match + @available_players).uniq
    wr_map_all  = Stats::WinRateReader
                    .new(season: @season, exclude_match: @match)
                    .call(players: all_players)

    # % para mostrar en la vista (nil si no elegible)
    wr_pct_if_eligible = ->(pl) do
      s = wr_map_all[pl.id]
      s&.dig(:eligible) && s[:wr] ? (s[:wr] * 100).round(1) : nil
    end

    # Orden de disponibles: mejor WR (si elegible), luego más PJ, luego nombre
    sort_wr = ->(pl) { wr_pct_if_eligible.call(pl) || 50.0 }
    @available_players.sort_by! do |pl|
      st = wr_map_all[pl.id]
      [-sort_wr.call(pl), -(st[:tm] || 0), display_name(pl)]
    end

    # Para que la vista pueda esconder el % si es nil
    @win_rate_pct_by_player = {}
    all_players.each { |pl| @win_rate_pct_by_player[pl.id] = wr_pct_if_eligible.call(pl) }
  end

  def display_name(pl)
    pl.respond_to?(:full_name) ? pl.full_name : (pl.name || "")
  end
end
