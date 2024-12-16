class CreatePlayers < ActiveRecord::Migration[7.2]
  def change
    create_table :players do |t|
      t.string :name
      t.string :nickname
      t.string :contact_info
      t.decimal :rating, default: 0

      t.timestamps
    end
  end
end
