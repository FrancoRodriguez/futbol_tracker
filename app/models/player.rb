# app/models/player.rb
class Player < ApplicationRecord
  MIN_MATCHES = 5

  has_many :player_stats, dependent: :destroy
  has_many :participations, dependent: :destroy
  has_many :matches, through: :participations
  has_many :mvp_matches, class_name: "Match", foreign_key: "mvp_id"
  has_many :player_positions, dependent: :destroy
  has_many :positions, through: :player_positions
  has_one_attached :profile_photo

  attr_accessor :primary_position_id

  after_save :sync_primary_position

  # ===== Value Objects =====
  ResultRow = Struct.new(:player, :wins, :total_matches, :mvp_count, :position, :tie, keyword_init: true)
  StatsRow  = Struct.new(:total_matches, :total_wins, :total_losses, :total_draws,
                         :win_rate_pct, :streak_current, :mvp_count, keyword_init: true)

  # ===== Utilidades de nombre =====
  def full_name
    nickname.present? ? "#{name} (#{nickname})" : name
  end

  def full_name_with_win
    "#{full_name} - #{(win_rate_pct_for&.round(1) || 0)}%"
  end

  def primary_position
    player_positions.find_by(primary: true)&.position
  end
  # ======== SHOW DEL JUGADOR ========

  def stats_for(season: Season.first_one)
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

  def draws_count_for(season: nil)
    rel = Match.joins(:participations)
               .where(participations: { player_id: id })
               .where("matches.date <= ?", Time.zone.today)
               .where.not(result: nil)
    rel = rel.where(date: season.starts_on..season.ends_on) if season
    rel.where("matches.result ~* ?", '^\\s*(\\d+)-\\1\\s*$').count
  end

  def participations_in(season: nil)
    rel = participations.joins(:match).includes(:match, :team)
                        .where("matches.date <= ?", Time.zone.today)
                        .where.not(matches: { result: nil })
    rel = rel.where(matches: { date: season.starts_on..season.ends_on }) if season
    rel.order("matches.date DESC")
  end

  def chart_data_for(season: nil)
    rel = participations.joins(:match)
    rel = rel.where(matches: { date: season.starts_on..season.ends_on }) if season
    rel = rel.where("matches.date <= ?", Time.zone.today)
             .where.not(matches: { result: nil })
             .includes(:match)
             .order("matches.date ASC")

    balance, dates, serie = 0, [], []

    rel.each do |p|
      m = p.match
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

  # ======== RANKING (usa player_stats) ========

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

  def self.top_last_month(positions: 3, season:)
    return [] unless season
    month = Date.current.prev_month
    from  = [ month.beginning_of_month, season.starts_on ].max
    to    = [ month.end_of_month,       season.ends_on ].min
    return [] if from > to

    base = Participation.joins(:match)
                        .where(matches: { date: from..to })
                        .where.not(matches: { result: nil })

    wins_by_player  = base.where("participations.team_id = matches.win_id").group(:player_id).count
    games_by_player = base.group(:player_id).count
    return [] if wins_by_player.empty?

    mvps_by_player  = Match.where(date: from..to).where.not(result: nil)
                           .where.not(mvp_id: nil).group(:mvp_id).count

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

    rows.sort_by! { |r| [ -r.wins, -r.total_matches, r.player.name.to_s ] }
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

  # ===== Compatibilidad / fallbacks =====

  def total_matches
    return self[:stat_total_matches].to_i if has_attribute?(:stat_total_matches)
    return self[:total_matches].to_i       if has_attribute?(:total_matches)
    participations.joins(:match)
                  .where("matches.date <= ?", Time.zone.today)
                  .where.not(matches: { result: nil })
                  .count
  end

  def total_wins
    return self[:total_wins].to_i if has_attribute?(:total_wins)
    participations.joins(:match)
                  .where("matches.date <= ?", Time.zone.today)
                  .where.not(matches: { result: nil })
                  .where("participations.team_id = matches.win_id")
                  .count
  end

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

  def win_rate(season: Season.first_one)
    stats_for(season: season).win_rate_pct || 0
  end

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

  # ===== Sinergias (Mejor compañero / Némesis) =====

  # API principal para la vista
  def synergy_for(season: nil, min_matches: 5)
    {
      best_teammate: best_teammate_stats(season: season, min_matches: min_matches),
      worst_teammate: worst_teammate_stats(season: season, min_matches: min_matches),
      nemesis:       nemesis_stats(season: season, min_matches: min_matches)
    }
  end

  def best_teammate(season: nil, min_matches: 3)
    best_teammate_stats(season: season, min_matches: min_matches)&.dig(:player)
  end

  def best_teammate_win_rate(season: nil, min_matches: 3)
    best_teammate_stats(season: season, min_matches: min_matches)&.dig(:win_rate)
  end

  def nemesis(season: nil, min_matches: 3)
    nemesis_stats(season: season, min_matches: min_matches)&.dig(:player)
  end

  def nemesis_win_rate(season: nil, min_matches: 3)
    nemesis_stats(season: season, min_matches: min_matches)&.dig(:win_rate)
  end

  def worst_teammate(season: nil, min_matches: 3)
    worst_teammate_stats(season: season, min_matches: min_matches)&.dig(:player)
  end

  def worst_teammate_loss_rate(season: nil, min_matches: 3)
    worst_teammate_stats(season: season, min_matches: min_matches)&.dig(:loss_rate)
  end

  def worst_teammate_losses(season: nil, min_matches: 3)
    worst_teammate_stats(season: season, min_matches: min_matches)&.dig(:losses)
  end

  def sync_primary_position
    return unless primary_position_id.present?
    player_positions.update_all(primary: false)
    player_positions.find_by(position_id: primary_position_id)&.update(primary: true)
  end

  private

  # Útil para full_name_with_win cuando no quieras pasar season
  def win_rate_pct_for(season: nil)
    stats_for(season: season).win_rate_pct
  end

  def best_teammate_stats(season:, min_matches:)
    rows = teammate_matrix(season: season)
    pick_best(rows, min_matches)
  end

  def nemesis_stats(season:, min_matches:)
    rows = opponent_matrix(season: season)
    pick_worst(rows, min_matches)
  end

  def pick_best(rows, min_matches)
    row = rows.select { _1[:total] >= min_matches }
              .max_by { |r| [ r[:win_rate], r[:total] ] }
    hydrate_row(row)
  end

  def pick_worst(rows, min_matches)
    row = rows.select { _1[:total] >= min_matches }
              .min_by { |r| [ r[:win_rate], -r[:total] ] }
    hydrate_row(row)
  end

  def hydrate_row(row)
    return nil unless row
    mate = Player.find_by(id: row[:player_id])
    return nil unless mate
    { player: mate, total: row[:total], wins: row[:wins], win_rate: row[:win_rate] }
  end

  # ---------- Matrices ----------
  def teammate_matrix(season:)
    sql  = base_pair_sql(season: season, same_team: true)
    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    rows.map do |r|
      total = r["total"].to_i
      wins  = r["wins"].to_i
      { player_id: r["other_player_id"].to_i, total:, wins:, win_rate: rate(wins, total) }
    end
  end

  def opponent_matrix(season:)
    sql  = base_pair_sql(season: season, same_team: false)
    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    rows.map do |r|
      total = r["total"].to_i
      wins  = r["wins"].to_i
      { player_id: r["other_player_id"].to_i, total:, wins:, win_rate: rate(wins, total) }
    end
  end

  # ---------- SQL ----------
  def win_case_sql_for_p1
    # Tu esquema actual tiene win_id
    if Match.column_names.include?("win_id")
      "CASE WHEN m.win_id = p1.team_id THEN 1 ELSE 0 END"
    else
      "0" # fallback seguro si cambias esquema
    end
  end

  def base_pair_sql(season:, same_team:)
    season_sql, season_params = season_sql_filter(season)
    comparator = same_team ? "p2.team_id = p1.team_id" : "p2.team_id <> p1.team_id"
    win_case   = win_case_sql_for_p1

    raw_sql = <<-SQL.squish
      SELECT
        p2.player_id AS other_player_id,
        COUNT(*)     AS total,
        SUM(#{win_case}) AS wins
      FROM participations p1
      INNER JOIN matches m ON m.id = p1.match_id
      INNER JOIN participations p2
        ON p2.match_id = p1.match_id
       AND p2.player_id <> p1.player_id
       AND #{comparator}
      WHERE p1.player_id = ?
        AND m.date <= ?
        AND m.result IS NOT NULL
        #{season_sql}
      GROUP BY p2.player_id
    SQL

    params = [ id, Time.zone.today, *season_params ]
    ActiveRecord::Base.send(:sanitize_sql_array, [ raw_sql, *params ])
  end

  def season_sql_filter(season)
    return [ "", [] ] unless season
    [ "AND m.date BETWEEN ? AND ?", [ season.starts_on, season.ends_on ] ]
  end

  def rate(wins, total)
    return 0.0 if total.to_i <= 0
    ((wins.to_f / total.to_f) * 100).round(1)
  end

  # Peor compañero (mismo equipo, más derrotas juntos) ---
  def worst_teammate_stats(season:, min_matches:)
    rows = teammate_matrix(season: season) # [{player_id:, total:, wins:, win_rate:}]
    # Enriquecemos con pérdidas y loss_rate
    rows = rows.map do |r|
      losses    = r[:total] - r[:wins]
      loss_rate = rate(losses, r[:total])
      r.merge(losses:, loss_rate:)
    end

    row = rows
            .select { _1[:total] >= min_matches }
            .max_by { |r| [ r[:losses], r[:total], -r[:win_rate] ] } # +muestra, desempate por peor win_rate
    return nil unless row

    mate = Player.find_by(id: row[:player_id])
    return nil unless mate
    { player: mate, total: row[:total], wins: row[:wins], losses: row[:losses],
      win_rate: row[:win_rate], loss_rate: row[:loss_rate] }
  end
end
