class Player < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :matches, through: :participations
  has_many :mvp_matches, class_name: 'Match', foreign_key: 'mvp_id'
  has_one_attached :profile_photo

  after_save :clear_global_stats_cache

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
    "#{full_name} - #{win_rate}%"
  end

  def total_matches
    participations.count
  end

  def total_wins
    participations
      .joins(:match)
      .where('participations.team_id = matches.win_id')
      .count
  end

  # Participaciones pasadas (orden DESC para paginar)
  def past_participations
    participations
      .includes(:match)
      .joins(:match)
      .where('matches.date <= ?', Date.today)
      .order('matches.date DESC')
  end

  # Participaciones cronológicas (ASC) para gráficos
  def chronological_participations
    participations
      .includes(:match)
      .joins(:match)
      .where('matches.date <= ?', Date.today)
      .order('matches.date ASC')
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
    stats_cache[:win_rate]
  end

  def self.top_mvp
    Rails.cache.fetch("stats:top_mvp", expires_in: 12.hours) do
      joins(:mvp_matches)
        .group('players.id')
        .order('COUNT(matches.id) DESC')
        .first
    end
  end

  def self.win_ranking
    Rails.cache.fetch("stats:win_ranking", expires_in: 12.hours) do
      joins(participations: :match)
        .where.not('matches.result ~* ?', '^\s*(\d+)-\1\s*$') # Excluir empates
        .select(
          <<~SQL.squish
          players.*,
          COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) AS total_wins,
          COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END) AS total_losses,
          (COUNT(CASE WHEN participations.team_id = matches.win_id THEN 1 END) -
           COUNT(CASE WHEN participations.team_id != matches.win_id THEN 1 END)) AS win_diff,
          COUNT(*) AS total_matches
        SQL
      )
        .group('players.id')
        .order('win_diff DESC, total_matches DESC')
    end
  end

  def self.top_winners(limit = 3)
    win_ranking.first(limit)
  end

  def self.mvp_ranking
    Rails.cache.fetch("stats:mvp_ranking", expires_in: 12.hours) do
      joins(:mvp_matches)
         .select('players.*, COUNT(matches.id) AS mvp_count')
         .group('players.id')
         .order('mvp_count DESC')
    end
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

      if match.win.name == 'Empate'
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
    win_rate = total.zero? ? 0 : (results[:victories].to_f / total * 100).round(2)

    {
      results_count: results,
      chart_data: { dates: dates, balance: cumulative },
      win_rate: win_rate
    }
  end
end
