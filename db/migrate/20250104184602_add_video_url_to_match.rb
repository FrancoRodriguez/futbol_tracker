class AddVideoUrlToMatch < ActiveRecord::Migration[7.2]
  def change
    add_column :matches, :video_url, :string
  end
end
