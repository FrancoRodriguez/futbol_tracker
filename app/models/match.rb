class Match < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :players, through: :participations
  has_many :goals, dependent: :destroy
  belongs_to :mvp, class_name: 'Player', optional: true
  has_and_belongs_to_many :players
  accepts_nested_attributes_for :participations, allow_destroy: true

  after_create :create_participations

  private

  def create_participations
    players.each do |player|
      participations.create(player: player)
    end
  end
end
