module SeasonsHelper
  # pct: 0..100 (más bajo = más parejo)
  def equilibrium_badge(pct)
    case pct
    when 0..2   then ["Muy parejo",   "success"]
    when 2..5   then ["Parejo",       "primary"]
    when 5..10  then ["Desbalance leve", "warning"]
    else             ["Desbalanceado", "danger"]
    end
  end
end
