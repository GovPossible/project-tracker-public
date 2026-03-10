require "test_helper"

class ReposControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "index lists repos" do
    get repos_url
    assert_response :success
    assert_select "a", repos(:erp).name
  end

  test "show displays repo" do
    get repo_url(repos(:erp))
    assert_response :success
    assert_select "h1", repos(:erp).name
  end

  test "new renders form" do
    get new_repo_url
    assert_response :success
    assert_select "form"
  end

  test "create saves valid repo" do
    assert_difference("Repo.count") do
      post repos_url, params: {repo: {name: "my-app", github_url: "https://github.com/org/my-app", framework: "rails"}}
    end
    assert_redirected_to repo_url(Repo.last)
    assert_equal "pending", Repo.last.setup_status
  end

  test "create rejects invalid repo" do
    assert_no_difference("Repo.count") do
      post repos_url, params: {repo: {name: ""}}
    end
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_repo_url(repos(:erp))
    assert_response :success
    assert_select "form"
  end

  test "update saves changes" do
    repo = repos(:erp)
    patch repo_url(repo), params: {repo: {ruby_version: "3.3.0"}}
    assert_redirected_to repo_url(repo)
    assert_equal "3.3.0", repo.reload.ruby_version
  end

  test "destroy deletes repo" do
    repo = repos(:pending_repo)
    assert_difference("Repo.count", -1) do
      delete repo_url(repo)
    end
    assert_redirected_to repos_url
  end

  test "retry_setup resets status to pending" do
    repo = repos(:erp)
    repo.update!(setup_status: "failed", setup_log: "something broke")
    post retry_setup_repo_url(repo)
    assert_redirected_to repo_url(repo)
    assert_equal "pending", repo.reload.setup_status
    assert_nil repo.setup_log
  end
end
