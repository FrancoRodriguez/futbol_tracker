class AddIndexesToPlayerPositionsAndParticipations < ActiveRecord::Migration[7.2]
  def change
    unless index_exists?(:player_positions, [ :position_id, :player_id ])
      add_index :player_positions, [ :position_id, :player_id ],
                name: "index_player_positions_on_position_and_player"
    end

    unless index_exists?(:participations, :player_id)
      add_index :participations, :player_id
    end

    unless index_exists?(:participations, :match_id)
      add_index :participations, :match_id
    end
  end
end
