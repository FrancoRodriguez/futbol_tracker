class CreateJoinTableMatchesPlayers < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:matches_players)
      create_join_table :matches, :players do |t|

        unless index_exists?(:matches_players, [:match_id, :player_id])
          t.index [:match_id, :player_id]
        end

        unless index_exists?(:matches_players, [:player_id, :match_id])
          t.index [:player_id, :match_id]
        end
      end
    end
  end
end
