class AddFileUrlsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :file_urls, :jsonb, default: [], null: false
  end
end
