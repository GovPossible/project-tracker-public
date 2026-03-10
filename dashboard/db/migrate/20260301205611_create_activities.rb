class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.references :project, null: false, foreign_key: true
      t.string :action
      t.text :details

      t.timestamps
    end
  end
end
