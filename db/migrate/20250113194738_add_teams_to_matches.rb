class AddTeamsToMatches < ActiveRecord::Migration[7.2]
  def change
    add_reference :matches, :home_team, foreign_key: { to_table: :teams }
    add_reference :matches, :away_team, foreign_key: { to_table: :teams }
  end
end
