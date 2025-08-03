class CreatePlayers < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:players)
      create_table :players do |t|
        t.string :name
        t.string :nickname
        t.string :contact_info
        t.decimal :rating, default: 0

        t.timestamps
      end
    end
  end
end
