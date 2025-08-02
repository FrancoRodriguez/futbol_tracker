class Player < ApplicationRecord
  has_many :participations
  has_many :matches, through: :participations
  has_and_belongs_to_many :matches
  has_many :mvp_matches, class_name: 'Match', foreign_key: 'mvp_id'
  has_one_attached :profile_photo

  def full_name
    return self.name + " (" + self.nickname + ")" if self.nickname.present?

    self.name
  end

  def total_matches
    participations.count
  end

  def total_wins
    participations.joins(:match).where('participations.team_id = matches.win_id').count
  end
end
