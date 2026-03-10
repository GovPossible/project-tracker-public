class CreateReplies < ActiveRecord::Migration[8.1]
  def change
    create_table :replies do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :channel, null: false
      t.string :from_address
      t.text :body, null: false
      t.datetime :received_at, null: false
      t.boolean :read, null: false, default: false

      t.timestamps
    end

    add_index :replies, [:project_id, :read]
  end
end
