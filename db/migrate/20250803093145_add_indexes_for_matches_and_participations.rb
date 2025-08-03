class AddIndexesForMatchesAndParticipations < ActiveRecord::Migration[7.2]
  def change
    add_index :matches, :date
    add_index :matches, :result
    add_index :participations, :team_id
  end
end
