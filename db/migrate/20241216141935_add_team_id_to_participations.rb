class AddTeamIdToParticipations < ActiveRecord::Migration[7.2]
  def change
    add_column :participations, :team_id, :integer
  end
end
