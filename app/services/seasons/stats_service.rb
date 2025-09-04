# frozen_string_literal: true
# Calcula métricas por temporada sin tocar la BD (solo lectura).
# Uso:
#   stats = Seasons::StatsService.call(season: @season, top_n: 5, min_matches: 3)
#
# Devuelve un hash con:
#   :summary
#   :player_rankings
#   :teams
#   :equilibrium
#   :synergies
#
module Seasons
  class StatsService
    DEFAULT_TOP_N = 5
    DEFAULT_MIN_MATCHES = 3
    DRAW_VALUES = %w[draw empate tie].freeze
    DEFAULT_RATING_SCALE = 10.0

    def self.call(...)
      new(...).call
    end

    def initialize(season:, top_n: DEFAULT_TOP_N, min_matches: DEFAULT_MIN_MATCHES, rating_scale: DEFAULT_RATING_SCALE)
      @season      = season
      @top_n       = top_n
      @min_matches = min_matches
      @rating_scale = rating_scale.to_f
    end

    def call
      {
        summary: summary_stats,
        player_rankings: player_rankings,
        teams: team_stats,
        equilibrium: equilibrium_index,
        synergies: synergies_and_rivalries
      }
    end

    private

    attr_reader :season, :top_n, :min_matches

    def matches_scope
      @matches_scope ||= Match
                           .where(season_id: season.id)
                           .includes(:home_team, :away_team, :participations)
    end

    def summary_stats
      matches = matches_scope
      total   = matches.size

      draws = matches.count { |m| draw_match?(m) }
      wins_by_team = matches.reject { |m| draw_match?(m) }
                            .group_by(&:win_id)
                            .transform_values(&:count)
                            .tap { |h| h.delete(nil) }

      {
        matches: total,
        draws: draws,
        wins_by_team_id: wins_by_team, # { team_id => count }
        # por si quieres W/D/L globales (no por equipo):
        global_wins: wins_by_team.values.sum,
        global_losses: total - draws - wins_by_team.values.sum
      }
    end

    # ---------- Player rankings desde player_stats ----------
    def player_rankings
      stats = PlayerStat.where(season_id: season.id).includes(:player)

      {
        mvps: stats.order(mvp_awards_count: :desc).limit(top_n).map { |s| expose_player_stat(s) },

        best_win_rate: stats.where("total_matches >= ?", min_matches)
                            .where.not(win_rate_cached: nil)
                            .order(win_rate_cached: :desc)
                            .limit(top_n).map { |s| expose_player_stat(s) },

        most_matches: stats.order(total_matches: :desc).limit(top_n).map { |s| expose_player_stat(s) },

        streaks: {
          best_win:  stats.order(streak_best_win: :desc, total_matches: :desc).limit(top_n).map { |s| expose_player_stat(s).merge(best_win: s.streak_best_win) },
          best_loss: stats.order(streak_best_loss: :desc, total_matches: :desc).limit(top_n).map { |s| expose_player_stat(s).merge(best_loss: s.streak_best_loss) },
          current:   stats.order(streak_current: :desc, total_matches: :desc).limit(top_n).map { |s| expose_player_stat(s).merge(current: s.streak_current) },
        }
      }
    end

    def expose_player_stat(s)
      {
        player_id: s.player_id,
        player_name: safe_player_name(s.player),
        total_matches: s.total_matches,
        total_wins: s.total_wins,
        win_rate: s.win_rate_cached&.to_f,
        mvps: s.mvp_awards_count
      }
    end

    def safe_player_name(player)
      player.full_name
    end

    # ---------- Teams: balance, victorias, jugadores más usados ----------
    def team_stats
      matches = matches_scope

      team_ids = matches.flat_map { |m| [m.home_team_id, m.away_team_id] }.compact.uniq
      return { teams: [], wins_by_team_id: {}, top_players_by_team: {} } if team_ids.empty?

      wins_by_team_id = matches.reject { |m| draw_match?(m) }
                               .group_by(&:win_id)
                               .transform_values(&:count)
                               .tap { |h| h.delete(nil) }

      balance = team_ids.map do |team_id|
        played = matches.select { |m| [m.home_team_id, m.away_team_id].include?(team_id) }
        wins   = played.count { |m| !draw_match?(m) && m.win_id == team_id }
        losses = played.count { |m| !draw_match?(m) && m.win_id && m.win_id != team_id }
        draws  = played.count { |m| draw_match?(m) }

        {
          team_id: team_id,
          team_name: team_name(team_id),
          played: played.size,
          wins: wins,
          draws: draws,
          losses: losses
        }
      end.sort_by { |h| [-h[:wins], h[:losses]] }

      top_players_by_team = top_players_for_teams(team_ids)

      {
        teams: balance,
        wins_by_team_id: wins_by_team_id,
        top_players_by_team: top_players_by_team # { team_id => [ { player_id, player_name, appearances } ] }
      }
    end

    def team_name(id)
      @team_cache ||= {}
      @team_cache[id] ||= Team.find_by(id: id)&.name || "Equipo ##{id}"
    end

    def top_players_for_teams(team_ids)
      # participations.team_id guarda el equipo del jugador en ese match
      rows = Participation.joins(:match)
                          .where(matches: { season_id: season.id }, team_id: team_ids)
                          .group(:team_id, :player_id)
                          .count # => { [team_id, player_id] => apariciones }

      grouped = Hash.new { |h, k| h[k] = [] }
      rows.each do |(team_id, player_id), appearances|
        grouped[team_id] << {
          player_id: player_id,
          player_name: safe_player_name(Player.find_by(id: player_id)),
          appearances: appearances
        }
      end

      # ordena y limita top_n por equipo
      grouped.transform_values do |arr|
        arr.sort_by { |h| -h[:appearances] }.first(top_n)
      end
    end

    # ---------- Índice de equilibrio (promedio diferencia rating medio por match) ----------
    def equilibrium_index
      diffs = []

      matches_scope.each do |m|
        parts = m.participations
        next if parts.blank?
        home_avg = avg_rating_for(parts, m.home_team_id)
        away_avg = avg_rating_for(parts, m.away_team_id)
        next if home_avg.nil? || away_avg.nil?
        diffs << (home_avg - away_avg).abs
      end

      gap = diffs.empty? ? 0.0 : (diffs.sum.to_f / diffs.size)

      {
        matches_with_data: diffs.size,
        avg_rating_gap: gap.round(3),
        pct_of_scale: ((gap / @rating_scale) * 100.0).round(1), # ← 0–100%
        rating_scale: @rating_scale
      }
    end

    def avg_rating_for(parts, team_id)
      return nil if team_id.blank?
      team_parts = parts.select { |p| p.team_id == team_id }
      return nil if team_parts.empty?
      ratings = team_parts.map { |p| (p.rating || 0).to_f }
      return nil if ratings.empty?
      ratings.sum / ratings.size
    end

    # ---------- Sinergias (duplas) y rivalidades (némesis) ----------
    def synergies_and_rivalries
      # Prepara estructura por match y equipo => jugadores
      by_match_team = Hash.new { |h, k| h[k] = [] } # { [match_id, team_id] => [player_id, ...] }
      win_team_by_match = {}

      matches_scope.each do |m|
        win_team_by_match[m.id] = m.win_id
        m.participations.each do |p|
          next if p.team_id.blank?
          by_match_team[[m.id, p.team_id]] << p.player_id
        end
      end

      # Duplas (misma camiseta)
      duo_stats = Hash.new { |h, k| h[k] = { games: 0, wins: 0 } } # { [a,b] => {games:, wins:} } con a<b
      by_match_team.each do |(match_id, team_id), players|
        players.uniq.combination(2).each do |a, b|
          key = a < b ? [a, b] : [b, a]
          duo_stats[key][:games] += 1
          duo_stats[key][:wins]  += 1 if win_team_by_match[match_id] == team_id
        end
      end

      duos = duo_stats.map do |(a, b), h|
        next if h[:games] < min_matches
        {
          a_id: a, a_name: name_for(a),
          b_id: b, b_name: name_for(b),
          games: h[:games],
          wins:  h[:wins],
          win_rate: (h[:wins].to_f / h[:games]).round(3)
        }
      end.compact.sort_by { |h| [-h[:win_rate], -h[:games]] }.first(top_n)

      # Némesis (rivales: camisetas opuestas)
      nemesis_stats = Hash.new { |h, k| h[k] = { games: 0, wins_a: 0 } } # { [a,b] => {games:, wins_a:} } jugador a vs b
      matches_scope.each do |m|
        team_players = {}
        m.participations.each do |p|
          team_players[p.team_id] ||= []
          team_players[p.team_id] << p.player_id
        end
        next if team_players.keys.size < 2

        t_ids = team_players.keys
        t_ids.combination(2).each do |t1, t2|
          p1s = team_players[t1].uniq
          p2s = team_players[t2].uniq
          p1s.each do |a|
            p2s.each do |b|
              next if a == b
              key = [a, b]
              nemesis_stats[key][:games] += 1
              nemesis_stats[key][:wins_a] += 1 if m.win_id == t1
            end
          end
          # y al revés (b vs a)
          p2s.each do |a|
            p1s.each do |b|
              next if a == b
              key = [a, b]
              nemesis_stats[key][:games] += 1
              nemesis_stats[key][:wins_a] += 1 if m.win_id == t2
            end
          end
        end
      end

      nemeses = nemesis_stats.map do |(a, b), h|
        next if h[:games] < min_matches
        {
          a_id: a, a_name: name_for(a),
          b_id: b, b_name: name_for(b),
          games: h[:games],
          wins_for_a: h[:wins_a],
          win_rate_for_a: (h[:wins_a].to_f / h[:games]).round(3)
        }
      end.compact.sort_by { |h| [h[:win_rate_for_a], -h[:games]] }.first(top_n) # peores (más bajas) primero => ordenar asc por win_rate

      {
        best_duos: duos,
        nemeses: nemeses
      }
    end

    def name_for(player_id)
      @players_cache ||= {}
      @players_cache[player_id] ||= begin
                                      p = Player.find_by(id: player_id)
                                      safe_player_name(p)
                                    end
    end

    def draw_match?(m)
      return true  if m.win_id.nil? && DRAW_VALUES.include?(m.result.to_s.downcase)
      return true  if m.win_id.nil? && m.result.blank?
      return false if m.win_id.present?
      DRAW_VALUES.include?(m.result.to_s.downcase)
    end
  end
end
