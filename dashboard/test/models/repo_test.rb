require "test_helper"

class RepoTest < ActiveSupport::TestCase
  test "valid repo" do
    repo = Repo.new(name: "test-app", github_url: "https://github.com/org/test-app")
    assert repo.valid?
  end

  test "requires name" do
    repo = Repo.new(github_url: "https://github.com/org/test")
    assert_not repo.valid?
    assert_includes repo.errors[:name], "can't be blank"
  end

  test "requires github_url" do
    repo = Repo.new(name: "test")
    assert_not repo.valid?
    assert_includes repo.errors[:github_url], "can't be blank"
  end

  test "name must be unique" do
    repo = Repo.new(name: repos(:erp).name, github_url: "https://github.com/org/other")
    assert_not repo.valid?
    assert_includes repo.errors[:name], "has already been taken"
  end

  test "defaults to pending status" do
    repo = Repo.new(name: "test-app", github_url: "https://github.com/org/test-app")
    assert_equal "pending", repo.setup_status
  end

  test "ready scope returns only ready repos" do
    ready = Repo.ready
    assert_includes ready, repos(:erp)
    assert_includes ready, repos(:commportal)
    assert_not_includes ready, repos(:pending_repo)
  end

  test "pending_setup scope returns pending and failed repos" do
    pending = Repo.pending_setup
    assert_includes pending, repos(:pending_repo)
    assert_not_includes pending, repos(:erp)
  end

  test "status predicates" do
    assert repos(:erp).ready?
    assert repos(:pending_repo).pending?
    assert_not repos(:erp).pending?
  end
end
