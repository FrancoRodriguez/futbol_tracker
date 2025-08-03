class CreateMatches < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:matches)
      create_table :matches do |t|
        t.date :date
        t.string :location
        t.string :result

        t.timestamps
      end
    end
  end
end
