class Match < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :players, through: :participations
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  belongs_to :win, class_name: 'Team', optional: true
  belongs_to :mvp, class_name: 'Player', optional: true
  has_and_belongs_to_many :players
  accepts_nested_attributes_for :participations, allow_destroy: true

  after_create :create_participations

  validates :result, format: { with: /\A\d+-\d+\z/, message: "debe tener el formato 'X-Y'" }, allow_blank: true

  private

  def create_participations
    players.each do |player|
      participations.create(player: player)
    end
  end
end
