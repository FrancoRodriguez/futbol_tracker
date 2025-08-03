class AddMvpToMatches < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:matches, :mvp_id)
      add_column :matches, :mvp_id, :bigint
    end
  end
end
