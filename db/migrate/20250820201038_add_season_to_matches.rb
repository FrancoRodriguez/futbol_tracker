class AddSeasonToMatches < ActiveRecord::Migration[7.2]
  def change
    add_reference :matches, :season, foreign_key: true, index: true
  end
end
