# app/controllers/duel_votes_controller.rb
class DuelVotesController < ApplicationController
  protect_from_forgery with: :exception

  def create
    match  = Match.find(params[:match_id])
    player = Player.find(params.require(:player_id))
    key    = duel_voter_key

    vote = DuelVote.find_or_initialize_by(match:, voter_key: key)
    vote.player     = player
    vote.ip         = request.remote_ip
    vote.user_agent = request.user_agent
    vote.save!

    render json: duel_stats_json(match), status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Datos inválidos" }, status: :unprocessable_entity
  end

  private

  def duel_stats_json(match)
    counts = DuelVote.where(match_id: match.id).group(:player_id).count
    home = match.home_team
    away = match.away_team
    a_pl = @featured_by_team&.dig(home&.id) || featured_for_team(match, home)
    b_pl = @featured_by_team&.dig(away&.id) || featured_for_team(match, away)

    a_id = a_pl&.id
    b_id = b_pl&.id
    a_ct = a_id ? counts[a_id].to_i : 0
    b_ct = b_id ? counts[b_id].to_i : 0
    tot  = a_ct + b_ct
    a_pc = tot.positive? ? ((a_ct * 100.0 / tot).round(1)) : 0.0
    b_pc = tot.positive? ? (100.0 - a_pc).round(1) : 0.0

    {
      a_player_id: a_id, b_player_id: b_id,
      a_count: a_ct, b_count: b_ct, total: tot,
      a_pct: a_pc, b_pct: b_pc,
      your_choice: DuelVote.find_by(match_id: match.id, voter_key: duel_voter_key)&.player_id
    }
  end

  # por si este controller se usa fuera de MatchesController
  def featured_for_team(match, team)
    return nil unless team
    parts = match.participations.includes(:player).where(team_id: team.id)
    players = parts.map(&:player)
    players.max_by do |pl|
      rating   = (pl.respond_to?(:rating) && pl.rating.present?) ? pl.rating.to_f : 0.0
      win_rate = pl.total_matches.to_i > 0 ? (pl.total_wins.to_f / pl.total_matches.to_f) : 0.5
      matches  = pl.total_matches.to_i
      [rating, win_rate, matches]
    end
  end
end
