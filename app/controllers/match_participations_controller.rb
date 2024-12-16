class MatchParticipationsController < ApplicationController
  before_action :set_match
  before_action :set_participation, only: [:destroy]

  def destroy
    @participation.destroy
    redirect_to match_path(@match), notice: 'Participación eliminada exitosamente.'
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def set_participation
    @participation = @match.participations.find(params[:id])
  end
end
