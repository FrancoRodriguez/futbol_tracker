require "digest"

class DuelVotesController < ApplicationController
  protect_from_forgery with: :exception

  def create
    match  = Match.find(params[:match_id])
    key    = duel_voter_key
    player = Player.find(params.require(:player_id))

    # si ya votó, no permitimos cambiar
    if (existing = DuelVote.find_by(match: match, voter_key: key))
      return render json: duel_stats_json(match).merge(
        error: "already_voted",
        your_choice: existing.player_id
      ), status: :conflict
    end

    DuelVote.create!(
      match: match,
      player: player,
      voter_key: key,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )

    render json: duel_stats_json(match).merge(your_choice: player.id), status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Datos inválidos" }, status: :unprocessable_entity
  end

  private

  def duel_stats_json(match)
    home = match.home_team
    away = match.away_team
    a    = featured_for_team(match, home)
    b    = featured_for_team(match, away)

    counts = DuelVote.where(match_id: match.id, player_id: [a&.id, b&.id]).group(:player_id).count
    a_ct   = a ? counts[a.id].to_i : 0
    b_ct   = b ? counts[b.id].to_i : 0
    tot    = a_ct + b_ct
    a_pct  = tot.positive? ? (a_ct * 100.0 / tot).round(1) : 50.0
    b_pct  = tot.positive? ? (100.0 - a_pct).round(1)      : 50.0

    {
      a_player_id: a&.id, b_player_id: b&.id,
      a_count: a_ct, b_count: b_ct, total: tot,
      a_pct: a_pct, b_pct: b_pct
    }
  end

  def featured_for_team(match, team)
    return nil unless team
    players = match.participations.includes(:player).where(team_id: team.id).map(&:player)
    return nil if players.empty?

    # mismo criterio que en el show: mejor win rate con mínimos
    min_matches = Player::MIN_MATCHES
    wr = ->(pl) { pl.total_matches.to_i > 0 ? (pl.total_wins.to_f / pl.total_matches.to_f) : nil }
    eligible    = players.select { |pl| pl.total_matches.to_i >= min_matches && wr.call(pl) }
    with_match  = players.select { |pl| wr.call(pl) }
    pool        = eligible.presence || with_match.presence || players
    pool.max_by { |pl| [wr.call(pl) || -1.0, pl.total_matches.to_i] }
  end
end
