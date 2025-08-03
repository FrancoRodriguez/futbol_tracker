class AddWinToMatches < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:matches, :win_id)
      add_reference :matches, :win, foreign_key: { to_table: :teams }
    end
  end
end
