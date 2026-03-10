require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "valid activity" do
    activity = activities(:working_started)
    assert activity.valid?
  end

  test "requires action" do
    activity = Activity.new(project: projects(:working), action: nil)
    assert_not activity.valid?
    assert_includes activity.errors[:action], "can't be blank"
  end

  test "recent scope orders by created_at desc" do
    activities = Activity.recent
    assert_equal activities.first.created_at, activities.maximum(:created_at)
  end
end
