class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :title, null: false
      t.text :description
      t.integer :priority, null: false, default: 2
      t.integer :status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.jsonb :repos, null: false, default: []
      t.jsonb :branches, null: false, default: {}
      t.jsonb :pr_urls, null: false, default: {}
      t.string :honeybadger_fault_id
      t.string :honeybadger_project_key
      t.integer :attempt_count, null: false, default: 0
      t.integer :max_attempts, null: false, default: 3
      t.datetime :waiting_since

      t.timestamps
    end

    add_index :projects, :status
    add_index :projects, :priority
    add_index :projects, :honeybadger_fault_id, unique: true, where: "honeybadger_fault_id IS NOT NULL"
  end
end
