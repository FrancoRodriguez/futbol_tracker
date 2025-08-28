class CreatePositions < ActiveRecord::Migration[7.2]
  def change
    create_table :positions do |t|
      t.string :key,  null: false  # "GK", "DEF", "MID", "ATT"
      t.string :name, null: false  # Portero, Defensa, Mediocampista, Delantero
      t.integer :sort_order, default: 0, null: false
      t.timestamps
    end
    add_index :positions, :key, unique: true

    create_table :player_positions do |t|
      t.references :player,   null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true
      t.boolean :primary, default: false, null: false
      t.timestamps
    end

    add_index :player_positions, [:player_id, :position_id], unique: true
  end
end
