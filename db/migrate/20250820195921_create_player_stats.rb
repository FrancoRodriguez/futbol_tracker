class CreatePlayerStats < ActiveRecord::Migration[7.2]
  def change
    create_table :player_stats do |t|
      t.references :player, null: false, foreign_key: true
      t.references :season, null: true, foreign_key: true
      t.integer :total_matches, null: false, default: 0
      t.integer :total_wins,    null: false, default: 0
      t.decimal :win_rate_cached, precision: 6, scale: 4
      t.integer :streak_current,   null: false, default: 0
      t.integer :streak_best_win,  null: false, default: 0
      t.integer :streak_best_loss, null: false, default: 0
      t.integer :mvp_awards_count, null: false, default: 0
      t.timestamps
    end

    add_index :player_stats, [ :player_id, :season_id ],
              unique: true, name: "idx_player_stats_player_season"
  end
end
