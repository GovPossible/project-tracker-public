require "test_helper"

class Api::V1::ReposControllerTest < ActionDispatch::IntegrationTest
  test "index returns all repos" do
    get "/api/v1/repos", headers: api_headers
    assert_response :success
    repos = JSON.parse(response.body)
    assert repos.length >= 2
    names = repos.map { |r| r["name"] }
    assert_includes names, "erp"
    assert_includes names, "commportal-v2"
  end

  test "show returns repo" do
    get "/api/v1/repos/#{repos(:erp).id}", headers: api_headers
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal "erp", data["name"]
    assert_equal "ready", data["setup_status"]
  end

  test "pending_setup returns only pending/failed repos" do
    get "/api/v1/repos/pending_setup", headers: api_headers
    assert_response :success
    repos = JSON.parse(response.body)
    statuses = repos.map { |r| r["setup_status"] }
    statuses.each do |s|
      assert_includes %w[pending failed], s
    end
  end

  test "update changes setup_status" do
    repo = repos(:pending_repo)
    patch "/api/v1/repos/#{repo.id}", headers: api_headers,
      params: {repo: {setup_status: "ready", local_path: "/home/deploy/workspace/new-app"}}.to_json
    assert_response :success
    repo.reload
    assert_equal "ready", repo.setup_status
    assert_equal "/home/deploy/workspace/new-app", repo.local_path
  end

  test "update records setup_log" do
    repo = repos(:pending_repo)
    patch "/api/v1/repos/#{repo.id}", headers: api_headers,
      params: {repo: {setup_status: "failed", setup_log: "clone failed: permission denied"}}.to_json
    assert_response :success
    assert_equal "clone failed: permission denied", repo.reload.setup_log
  end

  test "unauthorized without api key" do
    get "/api/v1/repos"
    assert_response :unauthorized
  end
end
