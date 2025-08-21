# app/services/stats/win_rate_reader.rb
module Stats
  class WinRateReader
    def initialize(min_matches: Player::MIN_MATCHES, season: nil, exclude_match: nil)
      @min_matches   = min_matches
      @season        = season        # Season o nil (global)
      @exclude_match = exclude_match # Match opcional: resta el PJ en curso si está sin finalizar
    end

    # players: Array<Player>
    # => { player_id => { tm:, tw:, wr:, eligible: } }
    def call(players:)
      ids   = players.map(&:id)
      result      = {}
      missing_ids = []

      # 1) Primer intento: leer de player_stats (rápido) cuando haya season/global
      stats = PlayerStat.where(player_id: ids, season_id: @season&.id).index_by(&:player_id)

      players.each do |pl|
        s = stats[pl.id]
        if s && (s.total_matches.to_i > 0 || s.win_rate_cached.present?)
          tm = s.total_matches.to_i
          tw = s.total_wins.to_i

          # Ajuste: si el partido actual está sin finalizar y el jugador participa, restamos 1 PJ
          if @exclude_match&.respond_to?(:unfinished?) &&
             @exclude_match.unfinished? &&
             @exclude_match.participations.any? { |p| p.player_id == pl.id }
            tm = [ tm - 1, 0 ].max
          end

          wr = tm.positive? ? (tw.to_f / tm) : nil
          result[pl.id] = { tm: tm, tw: tw, wr: wr, eligible: tm >= @min_matches }
        else
          missing_ids << pl.id
        end
      end

      # 2) Fallback si no hay fila en player_stats: agregados desde Participation (misma season/global)
      if missing_ids.any?
        rel = Participation.joins(:match).where(player_id: missing_ids)
        rel = rel.where(matches: { date: @season.starts_on..@season.ends_on }) if @season
        rel = rel.where.not(matches: { win_id: nil }) # sólo finalizados

        rows = rel.group("participations.player_id")
                  .select('participations.player_id AS pid,
                           COUNT(DISTINCT participations.match_id) AS tm,
                           SUM(CASE WHEN participations.team_id = matches.win_id THEN 1 ELSE 0 END) AS tw')
        tmp = rows.index_by { |r| r.pid.to_i }

        missing_ids.each do |pid|
          r  = tmp[pid]
          tm = r&.tm.to_i
          tw = r&.tw.to_i
          wr = tm.positive? ? (tw.to_f / tm) : nil
          result[pid] = { tm: tm, tw: tw, wr: wr, eligible: tm >= @min_matches }
        end
      end

      # 3) NUEVO: si hay season y el jugador no alcanza el mínimo,
      #    intenta usar los ÚLTIMOS @min_matches de la temporada ANTERIOR.
      if @season
        prev = previous_season_for(@season)
        if prev
          players.each do |pl|
            st = result[pl.id]
            next if st[:eligible] # ya cumple en la temporada actual

            # Trae los últimos @min_matches partidos finalizados de la season anterior
            last_scope = Participation.includes(:match)
                                      .joins(:match)
                                      .where(player_id: pl.id, matches: { date: prev.starts_on..prev.ends_on })
                                      .where.not(matches: { win_id: nil })
                                      .order("matches.date DESC")
                                      .limit(@min_matches)
            last = last_scope.to_a
            next unless last.size >= @min_matches # si no llega a 5, no usamos fallback

            wins = last.count { |p| p.team_id == p.match.win_id }
            st[:tm] = @min_matches
            st[:tw] = wins
            st[:wr] = wins.to_f / @min_matches
            st[:eligible] = true
          end
        end
      end

      # 4) Asegura clave para todos
      players.each { |pl| result[pl.id] ||= { tm: 0, tw: 0, wr: nil, eligible: false } }
      result
    end

    private

    def previous_season_for(season)
      Season.where("ends_on < ?", season.starts_on).order(ends_on: :desc).first
    end
  end
end
