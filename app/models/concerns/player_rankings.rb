module PlayerRankings
  extend ActiveSupport::Concern

  Result = Struct.new(:player, :total_matches, :victories, :mvp_count, :position, :tie, keyword_init: true)

  class_methods do
    def top_for_period(range, positions: 3, cache: Rails.cache)
      cache.fetch([ "players:top_for_period", range.begin.to_date, range.end.to_date, "pos:#{positions}" ], expires_in: 12.hours) do
        rows = find_by_sql([ SQL_RANKED, range.begin, range.end, range.begin, range.end ])

        rows.select { |r| r.read_attribute("position").to_i <= positions }
            .sort_by { |r| [
              r.read_attribute("position").to_i,
              -r.read_attribute("victories").to_i,
              -r.read_attribute("mvp_count").to_i,
              -r.read_attribute("total_matches").to_i,
              r.id
            ] }
            .map { |r| to_result(r) }
      end
    end

    def top_last_month(positions: 3, today: Time.zone.today, cache: Rails.cache)
      last  = today.last_month
      range = last.beginning_of_month..last.end_of_month
      top_for_period(range, positions: positions, cache: cache)
    end

    private

    # OJO: usar ? en vez de $1..$4
    SQL_RANKED = <<-SQL.squish
      WITH base AS (
        SELECT
          p.*,
          COUNT(*) AS total_matches,
          SUM( (pa.team_id = m.win_id)::int ) AS victories,
          COALESCE(mc.mvp_count, 0) AS mvp_count
        FROM players p
        JOIN participations pa ON pa.player_id = p.id
        JOIN matches m ON m.id = pa.match_id
        LEFT JOIN (
          SELECT mvp_id, COUNT(*) AS mvp_count
          FROM matches
          WHERE date BETWEEN ? AND ? AND mvp_id IS NOT NULL
          GROUP BY mvp_id
        ) mc ON mc.mvp_id = p.id
        WHERE m.date BETWEEN ? AND ?
        GROUP BY p.id, mc.mvp_count
      )
      SELECT
        *,
        DENSE_RANK() OVER (ORDER BY victories DESC, mvp_count DESC, total_matches DESC) AS position,
        (COUNT(*) OVER (PARTITION BY victories, mvp_count, total_matches)) > 1 AS tie
      FROM base
    SQL

    def to_result(row)
      Result.new(
        player:        row,
        total_matches: row.read_attribute("total_matches").to_i,
        victories:     row.read_attribute("victories").to_i,
        mvp_count:     row.read_attribute("mvp_count").to_i,
        position:      row.read_attribute("position").to_i,
        tie:           ActiveModel::Type::Boolean.new.cast(row.read_attribute("tie"))
      )
    end
  end
end
