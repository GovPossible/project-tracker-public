class CreateRepos < ActiveRecord::Migration[8.1]
  def change
    create_table :repos do |t|
      t.string :name, null: false
      t.string :github_url, null: false
      t.string :local_path
      t.string :ruby_version
      t.string :gemset
      t.string :setup_status, default: "pending", null: false
      t.text :setup_log
      t.string :framework
      t.string :test_command

      t.timestamps
    end

    add_index :repos, :name, unique: true
  end
end
