class RenameExistingBugfixPriorityToLow < ActiveRecord::Migration[8.1]
  # Priority enum changed: "bugfix" (0) → "critical" (0)
  # Honeybadger-sourced projects that were created as bugfix (0) should become low (3)
  # since Honeybadger faults now default to low priority.
  def up
    execute <<~SQL
      UPDATE projects SET priority = 3
      WHERE source = 1 AND priority = 0
    SQL
  end

  def down
    execute <<~SQL
      UPDATE projects SET priority = 0
      WHERE source = 1 AND priority = 3
    SQL
  end
end
