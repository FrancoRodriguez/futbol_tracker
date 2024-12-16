class Participation < ApplicationRecord
  belongs_to :player
  belongs_to :match
  belongs_to :team

  validates :goals, numericality: { greater_than_or_equal_to: 0 }
  validates :assists, numericality: { greater_than_or_equal_to: 0 }

  after_update :update_player_rating, :update_participation_rating

  private

  # Calcula la calificación de la participación y la limita a un máximo de 10
  def update_participation_rating
    calification = self.goals * 2 + self.assists * 1
    average_calification = [calification, 10].min

    # Evitar actualizar si la calificación no ha cambiado
    if self.rating != average_calification
      self.update_column(:rating, average_calification.round(2)) # Utilizamos update_column para evitar callbacks adicionales
    end
  end

  # Calcula la calificación promedio del jugador y la actualiza
  def update_player_rating
    # Solo actualizamos la calificación si es un jugador con participaciones
    return if player.participations.empty?

    # Sumar las calificaciones de todas las participaciones del jugador
    total_calification = player.participations.sum do |participation|
      participation.goals * 2 + participation.assists * 1
    end

    # Calcular el promedio de las calificaciones de las participaciones
    average_calification = total_calification.to_f / player.participations.count

    # Limitar el promedio a un máximo de 10
    average_calification = [average_calification, 10].min

    # Actualizar la calificación del jugador
    player.update(rating: average_calification.round(2))
  end

end
