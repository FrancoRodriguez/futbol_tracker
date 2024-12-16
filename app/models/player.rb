class Player < ApplicationRecord
  has_many :participations
  has_many :matches, through: :participations
  has_and_belongs_to_many :matches

  def full_name
    return self.name + " (" + self.nickname + ")" if self.nickname.present?

    self.name
  end
end
