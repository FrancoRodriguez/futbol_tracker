class MatchParticipationsController < ApplicationController
  before_action :set_match
  before_action :set_participation, only: [ :destroy ]

  def destroy
    @participation.destroy
    redirect_to match_path(@match), notice: "Participación eliminada exitosamente."
  end

  def update
    if @participation.update(participation_params)
      flash[:notice] = "Participación actualizada con éxito."
      redirect_to match_path(@match)
    else
      flash[:alert] = "No se pudo actualizar la participación."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def participation_params
    params.require(:participation).permit(:goals, :team_id)
  end

  def set_match
    @match = Match.find(params[:match_id])
  end

  def set_participation
    @participation = @match.participations.find(params[:id])
  end
end
