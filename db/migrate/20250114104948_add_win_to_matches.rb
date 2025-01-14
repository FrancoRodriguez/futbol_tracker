class AddWinToMatches < ActiveRecord::Migration[7.2]
  def change
    add_reference :matches, :win, foreign_key: { to_table: :teams }
  end
end
