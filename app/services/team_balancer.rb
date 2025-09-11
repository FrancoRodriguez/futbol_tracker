# app/services/team_balancer.rb
class TeamBalancer
  CAP_MATCHES     = 20
  LOW_CONF_WEIGHT = 3

  ROLE_ORDER = %w[GK DEF MID ATT].freeze
  BASE_FORMATION = { 'GK' => 1, 'DEF' => 3, 'MID' => 2, 'ATT' => 1 }.freeze # 7 por equipo

  def initialize(players)
    @players = Array(players).compact
  end

  def call
    pool = @players.shuffle # rompe empates deterministas
    return [pool, []] if pool.size <= 2

    sizes = team_sizes(pool.size) # [a, b] ordenado asc
    targets_a = role_targets_for_team_size(sizes[0])
    targets_b = role_targets_for_team_size(sizes[1])

    assign_with_roles(pool, sizes, targets_a, targets_b)
  end

  private

  # ========= Fuerza / win-rate =========
  def strength(p)
    matches = p.total_matches.to_i
    if matches.zero?
      0.5 * LOW_CONF_WEIGHT
    else
      weight = [matches, CAP_MATCHES].min
      (p.total_wins.to_f / matches.to_f) * weight
    end
  end

  # ========= Tamaños por equipo =========
  def team_sizes(n)
    a = n / 2
    b = n - a
    [a, b].sort
  end

  # Para n!=7, repartimos manteniendo proporciones (siempre 1 GK mientras haya >0 plazas)
  def role_targets_for_team_size(n)
    return BASE_FORMATION.dup if n >= 7

    targets = { 'GK' => (n >= 1 ? 1 : 0), 'DEF' => 0, 'MID' => 0, 'ATT' => 0 }
    rem = [n - targets['GK'], 0].max

    # Proporciones DEF:MID:ATT = 3:2:1 (total 6)
    ratios = { 'DEF' => 3, 'MID' => 2, 'ATT' => 1 }
    alloc_float = ratios.transform_values { |v| rem * (v / 6.0) }
    base = alloc_float.transform_values(&:floor)
    leftover = rem - base.values.sum

    # Reparte los restos por mayor fracción
    alloc_float.map { |k, f| [k, f - base[k]] }
               .sort_by { |(_, frac)| -frac }
               .first(leftover)
      &.each { |(k, _)| base[k] += 1 }

    targets.merge!(base)
    targets
  end

  # ========= Preferencias por rol =========
  # 2 = primaria, 1 = secundaria, 0 = no preferido
  def pref_score_for(player, role_key)
    pp_key = player.primary_position&.key
    return 2 if pp_key == role_key

    # secundarias = posiciones - primaria
    sec_keys = player.positions.map(&:key) - [pp_key].compact
    return 1 if sec_keys.include?(role_key)

    0
  end

  # ========= Asignación por roles con equilibrio de fuerza =========
  def assign_with_roles(pool, sizes, targets_a, targets_b)
    used_ids = {}
    team_a, team_b = [], []
    sa = 0.0
    sb = 0.0

    # Índice rápido de strength para no recalcular
    strength_by_id = pool.index_by(&:id).transform_values { |p| strength(p) }

    # Por cada rol, rellenamos las cuotas alternando hacia el equipo más débil
    ROLE_ORDER.each do |role|
      need_a = targets_a[role].to_i
      need_b = targets_b[role].to_i

      while need_a.positive? || need_b.positive?
        candidates = pool.reject { |p| used_ids[p.id] }
                         .map { |p| [p, pref_score_for(p, role), strength_by_id[p.id]] }
        break if candidates.empty?

        # Orden: mayor preferencia (2>1>0), luego mayor fuerza
        candidates.sort_by! { |(_, pref, str)| [-pref, -str] }
        picked, pref, picked_str = candidates.first

        # Decide equipo: el que aún necesita este rol y está más débil
        pick_for_a = need_a.positive? && (!need_b.positive? || sa <= sb)
        if pick_for_a
          team_a << picked
          sa += picked_str
          need_a -= 1
        elsif need_b.positive?
          team_b << picked
          sb += picked_str
          need_b -= 1
        else
          # Si ninguno necesita, salimos
          break
        end

        used_ids[picked.id] = true
      end
    end

    # Rellenar vacantes restantes (si team size > suma de cuotas o faltó gente de rol)
    fill_remaining!(team_a, sizes[0], pool, used_ids, sa, strength_by_id)
    fill_remaining!(team_b, sizes[1], pool, used_ids, sb, strength_by_id)

    [team_a, team_b]
  end

  def fill_remaining!(team, size_needed, pool, used_ids, team_strength, strength_by_id)
    return if team.size >= size_needed

    remaining = pool.reject { |p| used_ids[p.id] }
                    .sort_by { |p| -strength_by_id[p.id] }

    remaining.each do |p|
      break if team.size >= size_needed
      team << p
      used_ids[p.id] = true
    end
  end
end
