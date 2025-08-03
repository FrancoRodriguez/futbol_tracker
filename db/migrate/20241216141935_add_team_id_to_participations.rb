class AddTeamIdToParticipations < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:participations, :team_id)
      add_column :participations, :team_id, :integer
    end
  end
end
