class Match < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :players, through: :participations
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  belongs_to :win, class_name: "Team", optional: true
  belongs_to :mvp, class_name: "Player", optional: true
  belongs_to :season, optional: true
  has_and_belongs_to_many :players
  accepts_nested_attributes_for :participations, allow_destroy: true

  after_create :create_participations
  after_commit :rebuild_player_stats_if_result_changed, if: :saved_change_to_win_id?

  validates :result, format: { with: /\A\d+-\d+\z/, message: "debe tener el formato 'X-Y'" }, allow_blank: true

  def participants
    participations.includes(:player).map(&:player).uniq
  end

  private

  def create_participations
    players.each do |player|
      participations.create(player: player)
    end
  end

  def rebuild_player_stats_if_result_changed
    Stats::RebuildForMatchJob.perform_later(id)
  end
end
