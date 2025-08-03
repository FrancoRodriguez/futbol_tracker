class CreateTeams < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:teams)
      create_table :teams do |t|
        t.string :name

        t.timestamps
      end
    end
  end
end
