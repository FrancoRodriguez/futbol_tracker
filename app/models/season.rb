class Season < ApplicationRecord
  validates :name, :starts_on, :ends_on, presence: true
  validate  :dates_make_sense

  scope :active, -> { where(active: true).limit(1) }
  scope :for_date, ->(date) { where("starts_on <= ? AND ends_on >= ?", date, date) }

  def self.for_date!(date)
    for_date(date).first
  end

  def range
    (starts_on..ends_on)
  end

  def self.first_one
    Season.order(:created_at).first
  end

  def activate_exclusively!
    transaction do
      Season.where.not(id: id).update_all(active: false, updated_at: Time.current)
      update!(active: true)
    end
  end

  private

  def dates_make_sense
    errors.add(:ends_on, "must be after starts_on") if starts_on && ends_on && ends_on < starts_on
  end
end
