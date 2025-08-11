class TeamBalancer
  CAP_MATCHES = 20
  LOW_CONF_WEIGHT = 3   # peso pequeño para jugadores sin datos

  def initialize(players)
    @players = players
  end

  def call
    pool  = @players # <- sin filtrar
    return [pool, []] if pool.size <= 2

    sizes = team_sizes(pool.size)
    best_split_for_sizes(pool, sizes)
  end

  private

  # fuerza = win_rate * peso(matches cappeado)
  # para sin datos: win_rate 0.5 con peso pequeño
  def strength(p)
    matches = p.total_matches.to_i
    if matches.zero?
      0.5 * LOW_CONF_WEIGHT
    else
      weight = [matches, CAP_MATCHES].min
      (p.total_wins.to_f / matches.to_f) * weight
    end
  end

  def team_sizes(n)
    a = n / 2
    b = n - a
    [a, b].sort
  end

  def best_split_for_sizes(pool, sizes)
    weights = pool.map { |p| [p, strength(p)] }
    candidates = sizes.map { |k| best_subset_of_size(weights, k) }
    candidates.min_by { |c| c[:diff] }.values_at(:team_a, :team_b)
  end

  def best_subset_of_size(weights, k)
    total = weights.sum { |(_, w)| w }
    target = total / 2.0
    best = { diff: Float::INFINITY, team_a: [], team_b: [] }

    weights.combination(k).each do |combo|
      sum_a = combo.sum { |(_, w)| w }
      diff  = (target - sum_a).abs
      next unless diff < best[:diff]

      team_a_players = combo.map(&:first)
      team_b_players = (weights - combo).map(&:first)
      best = { diff:, team_a: team_a_players, team_b: team_b_players }
    end

    best
  end
end
