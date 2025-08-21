module Stats
  class Calculator
    def initialize(player:, season: nil)
      @player = player
      @season = season
    end

    def call
      rel = Participation.joins(:match).where(player_id: @player.id)

      if @season.present?
        rel = rel.where(matches: { date: @season.starts_on..@season.ends_on })
      end

      # Solo partidos con resultado (ganador definido)
      finished = rel.where.not(matches: { win_id: nil })

      total_matches = finished.distinct.count(:match_id)
      total_wins    = finished.where("participations.team_id = matches.win_id").count
      wr            = total_matches.positive? ? (total_wins.to_f / total_matches) : nil
      mvp_count     = Match.where(mvp_id: @player.id).where.not(win_id: nil)
      mvp_count     = mvp_count.where(date: @season.range) if @season.present?
      mvp_count     = mvp_count.count

      streaks = compute_streaks(finished)

      {
        total_matches: total_matches,
        total_wins: total_wins,
        win_rate_cached: wr,
        mvp_awards_count: mvp_count,
        streak_current: streaks[:current],
        streak_best_win: streaks[:best_win],
        streak_best_loss: streaks[:best_loss]
      }
    end

    private

    def compute_streaks(finished_scope)
      rows = finished_scope.
        select("matches.date AS date, (participations.team_id = matches.win_id) AS win").
        order("matches.date ASC")

      current = 0
      best_win = 0
      best_loss = 0

      rows.each do |r|
        win = ActiveRecord::Type::Boolean.new.cast(r.win)
        if win
          current = current.positive? ? current + 1 : 1
          best_win = [ best_win, current ].max
        else
          current = current.negative? ? current - 1 : -1
          best_loss = [ best_loss, -current ].max
        end
      end

      { current: current, best_win: best_win, best_loss: best_loss }
    end
  end
end
