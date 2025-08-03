class AddIndexesForMatchesAndParticipations < ActiveRecord::Migration[7.2]
  def change
    unless index_exists?(:matches, :date)
      add_index :matches, :date
    end

    unless index_exists?(:matches, :result)
      add_index :matches, :result
    end

    unless index_exists?(:participations, :team_id)
      add_index :participations, :team_id
    end
  end
end
