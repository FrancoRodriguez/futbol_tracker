class CreateSeasons < ActiveRecord::Migration[7.2]
  def change
    create_table :seasons do |t|
      t.string  :name,     null: false
      t.date    :starts_on, null: false
      t.date    :ends_on,   null: false
      t.boolean :active,    null: false, default: false
      t.timestamps
    end
    add_index :seasons, :active
    add_index :seasons, [ :starts_on, :ends_on ]
  end
end
