module PlayersHelper
  ICON_BY_KEY = {
    "GK"  => "fa-hand-paper",   # Portero
    "DEF" => "fa-shield-alt",   # Defensa
    "MID" => "fa-compass",      # Mediocampista
    "ATT" => "fa-bullseye"      # Delantero
  }.freeze

  COLOR_BY_KEY = {
    "GK"  => "bg-purple",
    "DEF" => "bg-primary",
    "MID" => "bg-success",
    "ATT" => "bg-danger"
  }.freeze

  COLOR_BY_KEY_TEXT = {
    "GK"  => "text-info",
    "DEF" => "text-primary",
    "MID" => "text-success",
    "ATT" => "text-danger"
  }.freeze

  ABBR_BY_KEY = {
    "GK"  => "GK",
    "DEF" => "DEF",
    "MID" => "MID",
    "ATT" => "ATT"
  }.freeze

  def build_chart_data(participations)
    balance = 0
    dates = []
    balance_cumulative = []

    participations.each do |participation|
      match = participation.match
      next if match.win_id.nil?

      if match.win.name == "Empate"
        # empate: no cambia el balance
      elsif match.win_id == participation.team_id
        balance += 1
      else
        balance -= 1
      end

      dates << match.date.strftime("%Y-%m-%d")
      balance_cumulative << balance
    end

    { dates: dates, balance: balance_cumulative }
  end

  def chip_for_position(pos, primary: false)
    key   = pos.key
    icon  = ICON_BY_KEY[key] || "fa-tag"
    abbr  = ABBR_BY_KEY[key] || pos.name.first(3).upcase
    klass = COLOR_BY_KEY[key] || "bg-secondary"

    text = primary ? "#{pos.name} · P" : pos.name

    content_tag :span,
                class: "badge #{klass} rounded-pill me-1",
                title: primary ? "Posición principal" : "Posición secundaria",
                data: { bs_toggle: "tooltip" } do
      safe_join([
                  content_tag(:i, "", class: "fas #{icon} me-1"),
                  content_tag(:span, text, class: "d-none d-sm-inline"),
                  content_tag(:span, (primary ? "#{abbr}·P" : abbr), class: "d-inline d-sm-none")
                ])
    end
  end

  def positions_chips_for(player, max_secondary: 2)
    chips = []
    if (pp = player.primary_position)
      chips << chip_for_position(pp, primary: true)
    end

    secs = player.secondary_positions.to_a
    secs.first(max_secondary).each { |pos| chips << chip_for_position(pos) }

    if secs.size > max_secondary
      rest = secs.drop(max_secondary)
      list = rest.map { |p| "- #{p.name}" }.join("\n")

      chips << content_tag(:button, "+#{rest.size}",
                           type: "button",
                           class: "badge bg-secondary rounded-pill",
                           data: {
                             bs_toggle: "popover",
                             bs_container: "body",
                             bs_trigger: "focus",
                             bs_placement: "top",
                             bs_title: "Otras posiciones",
                             bs_content: list
                           })
    end

    safe_join(chips)
  end

  def position_icon_tag(position, extra_classes: "")
    return "".html_safe unless position

    key   = position.key
    icon  = ICON_BY_KEY[key] || "fa-tag"
    color = COLOR_BY_KEY_TEXT[key] || "text-secondary"
    content_tag(:i, "", class: "fas #{icon} #{color} #{extra_classes}")
  end
end
