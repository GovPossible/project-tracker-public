class AddImageUrlsToReplies < ActiveRecord::Migration[8.1]
  def change
    add_column :replies, :image_urls, :jsonb, default: [], null: false
    change_column_null :replies, :body, true
  end
end
