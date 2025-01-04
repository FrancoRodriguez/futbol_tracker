class Participation < ApplicationRecord
  belongs_to :player
  belongs_to :match
  belongs_to :team

  validates :goals, numericality: { greater_than_or_equal_to: 0 }
  validates :assists, numericality: { greater_than_or_equal_to: 0 }

  after_update :update_participation_rating, :update_player_rating

  private

  # Calcula la calificación de la participación y la limita a un máximo de 10
  def update_participation_rating
    calification = goals * 2
    average_calification = [calification, 10].min

    update_column(:rating, average_calification.round(2)) if rating != average_calification
  end

  # Recalcula la calificación promedio del jugador basada en las calificaciones de todas sus participaciones
  def update_player_rating
    return if player.participations.empty?

    # Promedio de las calificaciones existentes de las participaciones
    total_rating = player.participations.sum(:rating)
    average_rating = total_rating.to_f / player.participations.count

    # Limitar el promedio a un máximo de 10
    average_rating = [average_rating, 10].min

    player.update_column(:rating, average_rating.round(2)) if player.rating != average_rating
  end
end
