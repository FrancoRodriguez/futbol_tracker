class ParticipationsController < ApplicationController
  before_action :set_match
  before_action :set_participation, only: [:edit, :update, :destroy]
  before_action :available_players, only: [:new]

  def new
    @participation = Participation.new
  end

  def edit; end

  def update
    if @participation.update(participation_params)
      redirect_to match_path(@match), notice: 'Participación actualizada con éxito.'
    else
      render :edit
    end
  end

  def create
    @participation = Participation.new(participation_params)
    player = Player.find(participation_params[:player_id])
    if @participation.save
      redirect_to @match, notice: "Jugador #{player.full_name} agregado al partido con éxito."
    else
      render :new
    end
  end

  def destroy
    @participation.destroy
    redirect_to @participation.match, notice: 'Participación eliminada con éxito.'
  end

  def bulk_create
    match = Match.find(params[:match_id])

    # Asegura equipos
    home = match.home_team || match.build_home_team(name: 'Equipo Blanco')
    away = match.away_team || match.build_away_team(name: 'Equipo Negro')
    match.save! if match.changed?

    home_ids = Array(params[:home_player_ids]).reject(&:blank?).map!(&:to_i)
    away_ids = Array(params[:away_player_ids]).reject(&:blank?).map!(&:to_i)

    # Evitar duplicados entre listas y existentes
    existing = match.participations.pluck(:player_id)
    overlap  = home_ids & away_ids
    home_ids -= overlap
    away_ids -= overlap

    to_create = []
    now = Time.current

    (home_ids - existing).each do |pid|
      to_create << { match_id: match.id, team_id: home.id, player_id: pid, created_at: now, updated_at: now }
    end
    (away_ids - existing).each do |pid|
      to_create << { match_id: match.id, team_id: away.id, player_id: pid, created_at: now, updated_at: now }
    end

    Participation.insert_all(to_create) if to_create.any?

    added = to_create.size
    msg = added.positive? ? "#{added} jugador#{'es' if added != 1} agregado#{'s' if added != 1}." : "No se agregaron jugadores."
    redirect_to match_path(match), notice: msg
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def set_participation
    @participation = Participation.find(params[:id])
  end

  def available_players
    @available_players = Player.where.not(id: Participation.where(match_id: @match.id)
                                                           .select(:player_id))
  end

  def participation_params
    params.require(:participation).permit(:match_id, :player_id, :team_id)
  end
end
