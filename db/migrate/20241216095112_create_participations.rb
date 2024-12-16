class CreateParticipations < ActiveRecord::Migration[7.2]
  def change
    create_table :participations do |t|
      t.references :player, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.integer :goals, default: 0
      t.integer :assists, default: 0
      t.decimal :rating, default: 0

      t.timestamps
    end
  end
end
