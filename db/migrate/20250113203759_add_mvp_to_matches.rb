class AddMvpToMatches < ActiveRecord::Migration[7.2]
  def change
    add_column :matches, :mvp_id, :bigint
  end
end
