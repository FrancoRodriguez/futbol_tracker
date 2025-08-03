class AddTeamsToMatches < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:matches, :home_team_id)
      add_reference :matches, :home_team, foreign_key: { to_table: :teams }
    end

    unless column_exists?(:matches, :away_team_id)
      add_reference :matches, :away_team, foreign_key: { to_table: :teams }
    end
  end
end
