require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid project" do
    project = projects(:queued_critical)
    assert project.valid?
  end

  test "requires title" do
    project = Project.new(title: nil)
    assert_not project.valid?
    assert_includes project.errors[:title], "can't be blank"
  end

  test "requires positive max_attempts" do
    project = projects(:queued_critical)
    project.max_attempts = 0
    assert_not project.valid?
  end

  test "requires non-negative attempt_count" do
    project = projects(:queued_critical)
    project.attempt_count = -1
    assert_not project.valid?
  end

  test "honeybadger_fault_id uniqueness" do
    duplicate = Project.new(
      title: "Duplicate",
      honeybadger_fault_id: projects(:queued_critical).honeybadger_fault_id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:honeybadger_fault_id], "has already been taken"
  end

  test "honeybadger_fault_id allows multiple nils" do
    project = Project.new(title: "No HB", honeybadger_fault_id: nil)
    project.valid?
    assert_empty project.errors[:honeybadger_fault_id]
  end

  test "active scope excludes done and failed" do
    active = Project.active
    assert_not_includes active, projects(:done)
    assert_not_includes active, projects(:failed)
    assert_includes active, projects(:working)
  end

  test "queued_by_priority returns critical before normal" do
    queue = Project.queued_by_priority
    critical_idx = queue.index(projects(:queued_critical))
    normal_idx = queue.index(projects(:queued_normal))
    assert critical_idx < normal_idx
  end

  test "next_available returns highest priority queued project" do
    assert_equal projects(:queued_critical), Project.next_available
  end

  test "increment_attempt marks failed when max reached" do
    project = projects(:failed)
    project.update!(attempt_count: 2, status: :working)
    project.increment_attempt!
    assert project.failed?
    assert_equal 3, project.attempt_count
  end

  test "has_unread_replies detects unread" do
    assert projects(:waiting_input).has_unread_replies?
    assert_not projects(:done).has_unread_replies?
  end

  test "needs_human includes waiting_input pr_review and staging" do
    needs = Project.needs_human
    assert_includes needs, projects(:waiting_input)
    assert_not_includes needs, projects(:queued_critical)
    assert_not_includes needs, projects(:working)
    assert_not_includes needs, projects(:done)
    assert_not_includes needs, projects(:failed)
  end

  test "MAX_HUMAN_PENDING defaults to 5" do
    assert_equal 5, Project::MAX_HUMAN_PENDING
  end
end
