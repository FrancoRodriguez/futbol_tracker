class AddVideoUrlToMatch < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:matches, :video_url)
      add_column :matches, :video_url, :string
    end
  end
end
