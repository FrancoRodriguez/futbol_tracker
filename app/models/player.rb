# app/models/player.rb
class Player < ApplicationRecord
  MIN_MATCHES = 5

  # Asociaciones
  has_many :player_stats, dependent: :destroy
  has_many :participations, dependent: :destroy
  has_many :matches, through: :participations
  has_many :mvp_matches, class_name: "Match", foreign_key: "mvp_id"
  has_one_attached :profile_photo

  # ===== Value Objects =====
  # Para "Jugador del mes" (dashboard)
  ResultRow = Struct.new(:player, :wins, :total_matches, :mvp_count, :position, :tie, keyword_init: true)

  # Para show del jugador (temporada/global)
  StatsRow  = Struct.new(:total_matches, :total_wins, :total_losses, :total_draws,
                         :win_rate_pct, :streak_current, :mvp_count, keyword_init: true)

  # ===== Utilidades de nombre =====
  def full_name
    nickname.present? ? "#{name} (#{nickname})" : name
  end

  def full_name_with_win
    "#{full_name} - #{(win_rate_pct_for&.round(1) || 0)}%"
  end

  # ======== SHOW DEL JUGADOR (usa player_stats + mínimos cálculos) ========

  # Devuelve las estadísticas persistidas para la season dada (o global si season=nil)
  def stats_for(season: nil)
    ps = season ? player_stats.find_by(season_id: season.id) : player_stats.find_by(season_id: nil)
    return StatsRow.new(total_matches: 0, total_wins: 0, total_losses: 0, total_draws: 0,
                        win_rate_pct: nil, streak_current: 0, mvp_count: 0) unless ps

    draws  = draws_count_for(season: season)
    losses = [ ps.total_matches.to_i - ps.total_wins.to_i - draws, 0 ].max
    wr_pct = if ps.total_matches.to_i >= MIN_MATCHES && ps.win_rate_cached.present?
               (ps.win_rate_cached.to_f * 100).round(1)
    end

    StatsRow.new(
      total_matches:  ps.total_matches.to_i,
      total_wins:     ps.total_wins.to_i,
      total_losses:   losses,
      total_draws:    draws,
      win_rate_pct:   wr_pct,
      streak_current: ps.streak_current.to_i,
      mvp_count:      ps.mvp_awards_count.to_i
    )
  end

  # Empates del jugador (filtrado por season si aplica)
  def draws_count_for(season: nil)
    rel = Match.joins(:participations).where(participations: { player_id: id })
    rel = rel.where(date: season.starts_on..season.ends_on) if season
    rel.where("matches.result ~* ?", '^\\s*(\\d+)-\\1\\s*$').count
  end

  # Participaciones filtradas por season (para historial en el show)
  def participations_in(season: nil)
    rel = participations.joins(:match).includes(:match, :team)
                        .where("matches.date <= ?", Date.today)
    rel = rel.where(matches: { date: season.starts_on..season.ends_on }) if season
    rel.order("matches.date DESC")
  end

  # Serie de balance para el gráfico del show (W +1, L -1, empate 0)
  def chart_data_for(season: nil)
    rel = participations.joins(:match)
    rel = rel.where(matches: { date: season.starts_on..season.ends_on }) if season
    rel = rel.where("matches.date <= ?", Date.today)
             .includes(:match)
             .order("matches.date ASC")

    balance = 0
    dates   = []
    serie   = []

    rel.each do |p|
      m = p.match
      next if m.win_id.nil?
      if m.result&.match?(/^\s*(\d+)-\1\s*$/)
        # draw => sin cambio
      elsif m.win_id == p.team_id
        balance += 1
      else
        balance -= 1
      end
      dates << m.date.strftime("%Y-%m-%d")
      serie << balance
    end

    { dates: dates, balance: serie }
  end

  # ======== RANKING (usa filas de player_stats) ========

  # Ranking basado en player_stats (season=nil => GLOBAL)
  def self.win_ranking(season: nil)
    sid_sql =
      if season
        sanitize_sql_array([ "player_stats.season_id = ?", season.id ])
      else
        "player_stats.season_id IS NULL"
      end

    select_sql = <<~SQL.squish
      players.*,
      COALESCE(player_stats.total_matches, 0) AS stat_total_matches,
      COALESCE(player_stats.total_wins,    0) AS stat_total_wins,
      GREATEST(COALESCE(player_stats.total_matches,0) - COALESCE(player_stats.total_wins,0), 0) AS stat_total_losses,
      (COALESCE(player_stats.total_wins,0) * 2 - COALESCE(player_stats.total_matches,0)) AS stat_win_diff,
      player_stats.streak_current AS stat_streak_current,
      CASE
        WHEN COALESCE(player_stats.total_matches,0) >= #{MIN_MATCHES}
             AND player_stats.win_rate_cached IS NOT NULL
        THEN ROUND(player_stats.win_rate_cached * 100.0, 1)
        ELSE NULL
      END AS stat_win_rate_pct
    SQL

    joins("LEFT JOIN player_stats ON player_stats.player_id = players.id AND #{sid_sql}")
      .select(select_sql)
      .where("COALESCE(player_stats.total_matches, 0) > 0")
      .includes(profile_photo_attachment: :blob)
      .order(Arel.sql("stat_win_diff DESC, stat_total_matches DESC, players.name ASC"))
      .to_a
  end

  # Atajos para las columnas calculadas del ranking
  def stat_total_matches;  self[:stat_total_matches]  || 0 end
  def stat_total_wins;     self[:stat_total_wins]     || 0 end
  def stat_total_losses;   self[:stat_total_losses]   || 0 end
  def stat_win_diff;       self[:stat_win_diff]       || 0 end
  def stat_win_rate_pct;   self[:stat_win_rate_pct]       end
  def stat_streak_current; self[:stat_streak_current]     end
  def mvp_count; self[:mvp_count].to_i; end

  def self.top_winners(limit: 3, season: nil)
    win_ranking(season: season).first(limit)
  end

  # Top MVP usando player_stats (por season o sumado global)
  def self.top_mvp(season: nil)
    if season
      joins(:player_stats)
        .where(player_stats: { season_id: season.id })
        .select("players.*, player_stats.mvp_awards_count AS mvp_count")
        .order("player_stats.mvp_awards_count DESC, players.name ASC")
        .first
    else
      joins(:player_stats)
        .select("players.*, SUM(player_stats.mvp_awards_count) AS mvp_count")
        .group("players.id")
        .order("SUM(player_stats.mvp_awards_count) DESC, players.name ASC")
        .first
    end
  end

  # "Jugador del mes" (dentro de la season dada)
  def self.top_last_month(positions: 3, season:)
    return [] unless season
    month = Date.current.prev_month
    from  = [month.beginning_of_month, season.starts_on].max
    to    = [month.end_of_month,       season.ends_on].min
    return [] if from > to

    base = Participation.joins(:match).where(matches: { date: from..to })

    wins_by_player  = base.where("participations.team_id = matches.win_id").group(:player_id).count
    games_by_player = base.group(:player_id).count
    return [] if wins_by_player.empty?

    mvps_by_player  = Match.where(date: from..to).where.not(mvp_id: nil).group(:mvp_id).count

    players_by_id = Player.where(id: wins_by_player.keys).index_by(&:id)

    rows = wins_by_player.keys.map do |pid|
      ResultRow.new(
        player:        players_by_id[pid],
        wins:          wins_by_player[pid].to_i,
        total_matches: games_by_player[pid].to_i,
        mvp_count:     mvps_by_player[pid].to_i,
        position:      nil,
        tie:           false
      )
    end

    rows.sort_by! { |r| [-r.wins, -r.total_matches, r.player.name.to_s] }
    rows = rows.first(positions)

    last_wins = nil
    last_pos  = 0
    rows.each_with_index do |r, idx|
      if r.wins == last_wins
        r.position = last_pos
      else
        r.position = idx + 1
        last_pos   = r.position
        last_wins  = r.wins
      end
    end
    rows.each_with_index do |r, idx|
      prev_same = idx > 0             && rows[idx - 1].wins == r.wins
      next_same = idx < rows.size - 1 && rows[idx + 1].wins == r.wins
      r.tie = prev_same || next_same
    end
    rows
  end

  # ===== Compatibilidad/fallbacks usados en otras vistas =====

  # Estos dos se usan en algunos parciales viejos;
  # si el objeto viene del ranking con SELECT de stat_*, devolvemos esos valores.
  def total_matches
    return self[:stat_total_matches].to_i if has_attribute?(:stat_total_matches)
    return self[:total_matches].to_i       if has_attribute?(:total_matches)
    participations.count
  end

  def total_wins
    return self[:total_wins].to_i if has_attribute?(:total_wins)
    participations.joins(:match).where("participations.team_id = matches.win_id").count
  end

  # Racha “histórica” (global) por compat; el ranking ya trae stat_streak_current
  def last_results(limit = 100)
    rows = Match.joins(:participations)
                .where(participations: { player_id: id })
                .where.not("matches.result ~* ?", '^\\s*(\\d+)-\\1\\s*$')
                .order(date: :desc)
                .limit(limit)
                .select("matches.win_id, participations.team_id")
    rows.map { |r| r.win_id == r.team_id ? 1 : 0 }
  end

  def current_streak
    series = last_results(100)
    return 0 if series.empty?
    run = series.take_while { |x| x == series.first }.size
    series.first == 1 ? run : -run
  end

  def win_rate(season: nil)
    season ||= Season.active.first
    stats_for(season: season).win_rate_pct || 0
  end

  # Ranking de MVPs usando stats persistidas.
  # season=nil => GLOBAL (suma todas las seasons)
  def self.mvp_ranking(season: nil)
    if season
      joins(:player_stats)
        .where(player_stats: { season_id: season.id })
        .where("player_stats.mvp_awards_count > 0")
        .select("players.*, player_stats.mvp_awards_count AS mvp_count")
        .order("player_stats.mvp_awards_count DESC, players.name ASC")
    else
      joins(:player_stats)
        .select("players.*, COALESCE(SUM(player_stats.mvp_awards_count), 0) AS mvp_count")
        .group("players.id")
        .having("COALESCE(SUM(player_stats.mvp_awards_count), 0) > 0")
        .order("mvp_count DESC, players.name ASC")
    end
  end

  private

  # Útil para full_name_with_win cuando no quieras pasar season
  def win_rate_pct_for(season: nil)
    stats_for(season: season).win_rate_pct
  end
end
