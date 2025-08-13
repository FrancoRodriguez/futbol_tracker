# db/migrate/20250813150100_create_duel_votes.rb
class CreateDuelVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :duel_votes do |t|
      t.references :match,  null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true # ganador predicho
      t.string  :voter_key, null: false                    # hash del UUID en cookie
      t.string  :ip
      t.string  :user_agent
      t.timestamps
    end

    add_index :duel_votes, [:match_id, :voter_key], unique: true
  end
end
