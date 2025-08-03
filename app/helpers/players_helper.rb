module PlayersHelper
  def build_chart_data(participations)
    balance = 0
    dates = []
    balance_cumulative = []

    participations.each do |participation|
      match = participation.match
      next if match.win_id.nil?

      if match.win.name == 'Empate'
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

end
