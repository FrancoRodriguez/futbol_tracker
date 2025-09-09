class Match < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :players, through: :participations

  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  belongs_to :win,  class_name: "Team",   optional: true
  belongs_to :mvp,  class_name: "Player", optional: true
  belongs_to :season, optional: true

  accepts_nested_attributes_for :participations, allow_destroy: true

  after_create :create_participations
  after_commit :rebuild_player_stats_if_outcome_changed, on: :update, if: :outcome_changed?

  validates :result, format: { with: /\A\d+-\d+\z/, message: "debe tener el formato 'X-Y'" }, allow_blank: true

  def participants
    participations.includes(:player).map(&:player).uniq
  end

  private

  def create_participations
    players.each { |player| participations.create(player:) }
  end

  def outcome_changed?
    saved_change_to_win_id? || saved_change_to_mvp_id? || saved_change_to_result?
  end

  def rebuild_player_stats_if_outcome_changed
    Rails.logger.info("[Stats] RebuildForMatchJob enqueued for match=#{id} (changes: #{previous_changes.slice('win_id','mvp_id','result')})")
    Stats::RebuildForMatchJob.perform_later(id)
  end
end
