class Player < ApplicationRecord
  include PlayerRankings

  has_many :player_stats, dependent: :destroy
  has_many :participations, dependent: :destroy
  has_many :matches, through: :participations
  has_many :mvp_matches, class_name: "Match", foreign_key: "mvp_id"
  has_one_attached :profile_photo

  after_save :clear_global_stats_cache

  MIN_MATCHES = 5

  # Estructura para el widget "Jugador del mes"
  ResultRow = Struct.new(:player, :wins, :total_matches, :mvp_count, :position, :tie, keyword_init: true)

  def clear_global_stats_cache
    Rails.cache.delete("stats:top_mvp")
    Rails.cache.delete("stats:top_winners")
    Rails.cache.delete("stats:win_ranking")
    Rails.cache.delete("stats:mvp_ranking")
    (Player.all.pluck(:id)).compact.uniq.each do |id|
      Rails.cache.delete("player:#{id}:stats")
    end
  end

  def full_name
    nickname.present? ? "#{name} (#{nickname})" : name
  end

  def full_name_with_win
    "#{full_name} - #{win_rate}"
  end

  def total_matches
    return self[:total_matches].to_i if has_attribute?(:total_matches)

    participations.count
  end

  def total_wins
    return self[:total_wins].to_i if has_attribute?(:total_wins)

    participations
      .joins(:match)
      .where("participations.team_id = matches.win_id")
      .count
  end

  # Participaciones pasadas (orden DESC para paginar)
  def past_participations
    participations
      .includes(:match)
      .joins(:match)
      .where("matches.date <= ?", Date.today)
      .order("matches.date DESC")
  end

  # Participaciones cronológicas (ASC) para gráficos
  def chronological_participations
    participations
      .includes(:match)
      .joins(:match)
      .where("matches.date <= ?", Date.today)
      .order("matches.date ASC")
  end

  def stats_cache
    Rails.cache.fetch("player:#{id}:stats", expires_in: 12.hours) do
      compute_stats
    end
  end

  def results_count
    stats_cache[:results_count]
  end

  def chart_data
    stats_cache[:chart_data]
  end

  def win_rate
    return stats_cache[:win_rate].to_f if stats_cache[:win_rate].is_a?(Integer)

    stats_cache[:win_rate].to_f
  end

  # Top MVP de la temporada (usa player_stats.mvp_awards_count)
  def self.top_mvp(season: nil)
    if season
      Player.joins(:player_stats)
            .where(player_stats: { season_id: season.id })
            .select("players.*, player_stats.mvp_awards_count AS mvp_count")
            .order("player_stats.mvp_awards_count DESC, players.name ASC")
            .first
    else
      # Fallback global (si alguna vez lo usas fuera de dashboard)
      joins(:mvp_matches)
        .group("players.id")
        .order(Arel.sql("COUNT(matches.id) DESC"))
        .select("players.*, COUNT(matches.id) AS mvp_count")
        .first
    end
  end

  # Top del último mes dentro de la temporada dada (season ACTIVA)
  # Devuelve array de ResultRow con: player, wins, total_matches, mvp_count, position, tie
  def self.top_last_month(positions: 3, season:)
    return [] unless season

    from = [ 30.days.ago.to_date, season.starts_on ].max
    to   = [ Date.current,        season.ends_on ].min
    return [] if from > to

    # Ganados por jugador en la ventana (solo finalizados)
    wins_by_player = Participation.joins(:match)
                                  .where(matches: { date: from..to })
                                  .where("participations.team_id = matches.win_id")
                                  .group(:player_id)
                                  .order(Arel.sql("COUNT(*) DESC"))
                                  .limit(positions)
                                  .count # => { player_id => wins }

    return [] if wins_by_player.empty?

    player_ids       = wins_by_player.keys
    players_by_id    = Player.where(id: player_ids).index_by(&:id)
    stats_by_player  = PlayerStat.where(player_id: player_ids, season_id: season.id).index_by(&:player_id)

    # Construimos filas base
    rows = wins_by_player.map do |pid, wins|
      ps = stats_by_player[pid]
      ResultRow.new(
        player:        players_by_id[pid],
        wins:          wins.to_i,
        total_matches: ps&.total_matches.to_i,
        mvp_count:     ps&.mvp_awards_count.to_i,
        position:      nil,   # se completa abajo
        tie:           false  # se completa abajo
      )
    end

    # Orden estable: más wins primero, luego nombre
    rows.sort_by! { |r| [ -r.wins, r.player.name.to_s ] }

    # Asignar posición con empates (misma cantidad de wins comparten posición)
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

    # Marcar empate si comparte wins con vecino anterior o siguiente
    rows.each_with_index do |r, idx|
      prev_same = idx > 0              && rows[idx - 1].wins == r.wins
      next_same = idx < rows.size - 1  && rows[idx + 1].wins == r.wins
      r.tie = prev_same || next_same
    end

    rows
  end

  def self.win_ranking(season: nil)
    cache_key = "stats:win_ranking:#{season&.id || 'global'}"

    Rails.cache.fetch(cache_key, expires_in: 12.hours) do
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
        CASE
          WHEN COALESCE(player_stats.total_matches,0) >= #{Player::MIN_MATCHES}
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
  end

  def self.top_winners(limit: 3, season: nil)
    win_ranking(season: season).first(limit)
  end

  def self.mvp_ranking
    Rails.cache.fetch("stats:mvp_ranking", expires_in: 12.hours) do
      joins(:mvp_matches)
         .select("players.*, COUNT(matches.id) AS mvp_count")
         .group("players.id")
         .order("mvp_count DESC")
    end
  end

  # 1 = win, 0 = loss (empates excluidos)
  def last_results(limit = 8)
    rows = Match.joins(:participations)
                .where(participations: { player_id: id })
                .where.not("matches.result ~* ?", '^\\s*(\\d+)-\\1\\s*$') # excluye empates
                .order(date: :desc)
                .limit(limit)
                .select("matches.win_id, participations.team_id")

    rows.map { |r| r.win_id == r.team_id ? 1 : 0 }
  end


  # positivo: racha de victorias; negativo: racha de derrotas
  def current_streak
    series = last_results(100) # 100 para cubrir rachas largas
    return 0 if series.empty?
    first = series.first
    run   = series.take_while { |x| x == first }.size
    first == 1 ? run : -run
  end

  private

  def compute_stats
    results = { victories: 0, defeats: 0, draws: 0 }
    balance = 0
    dates = []
    cumulative = []

    chronological_participations.each do |participation|
      match = participation.match
      next if match.win_id.nil?

      if match.win.name == "Empate"
        results[:draws] += 1
        # balance no cambia
      elsif match.win_id == participation.team_id
        results[:victories] += 1
        balance += 1
      else
        results[:defeats] += 1
        balance -= 1
      end

      dates << match.date.strftime("%Y-%m-%d")
      cumulative << balance
    end

    total = results.values.sum
    win_rate = total >= MIN_MATCHES ? (results[:victories].to_f / total * 100).round(2) : "En evaluación"

    {
      results_count: results,
      chart_data: { dates: dates, balance: cumulative },
      win_rate: win_rate
    }
  end
end
