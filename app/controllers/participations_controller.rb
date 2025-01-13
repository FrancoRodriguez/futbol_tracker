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
