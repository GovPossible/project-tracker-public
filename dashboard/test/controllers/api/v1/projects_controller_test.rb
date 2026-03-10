require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "rejects unauthenticated requests" do
    get next_available_api_v1_projects_url
    assert_response :unauthorized
  end

  test "rejects invalid api key" do
    get next_available_api_v1_projects_url, headers: {"Authorization" => "Bearer wrong-key"}
    assert_response :unauthorized
  end

  test "next_available returns highest priority queued project" do
    get next_available_api_v1_projects_url, headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal projects(:queued_critical).id, json["id"]
  end

  test "next_available returns null when queue empty" do
    Project.queued.destroy_all
    get next_available_api_v1_projects_url, headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["project"]
  end

  test "waiting_with_replies returns waiting projects with unread replies" do
    get waiting_with_replies_api_v1_projects_url, headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert json.any? { |p| p["id"] == projects(:waiting_input).id }
  end

  test "show returns project" do
    get api_v1_project_url(projects(:working)), headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal projects(:working).title, json["title"]
  end

  test "create saves valid project" do
    assert_difference("Project.count") do
      post api_v1_projects_url, headers: api_headers,
        params: {project: {title: "API project", priority: "normal", source: "honeybadger", honeybadger_fault_id: "hb_new"}}.to_json
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "API project", json["title"]
  end

  test "create rejects invalid project" do
    assert_no_difference("Project.count") do
      post api_v1_projects_url, headers: api_headers,
        params: {project: {title: ""}}.to_json
    end
    assert_response :unprocessable_entity
  end

  test "update changes project fields" do
    project = projects(:working)
    patch api_v1_project_url(project), headers: api_headers,
      params: {project: {status: "pr_review", branches: {erp: "claude/gl-refactor"}}}.to_json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "pr_review", json["status"]
  end

  test "human_pending_count returns count and limit" do
    get human_pending_count_api_v1_projects_url, headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("count")
    assert json.key?("limit")
    assert json.key?("blocked")
    assert_equal Project::MAX_HUMAN_PENDING, json["limit"]
    assert_equal Project.needs_human.count, json["count"]
  end

  test "human_pending_count blocked is true when at limit" do
    # Create enough projects to hit the limit
    (Project::MAX_HUMAN_PENDING - Project.needs_human.count).times do |i|
      Project.create!(title: "Staging #{i}", status: :staging, priority: :normal, source: :manual)
    end
    get human_pending_count_api_v1_projects_url, headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert json["blocked"]
  end
end
