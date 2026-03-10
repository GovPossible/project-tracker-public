require "test_helper"

class Api::V1::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "create logs activity on project" do
    project = projects(:working)
    assert_difference("Activity.count") do
      post api_v1_project_activities_url(project), headers: api_headers,
        params: {activity: {action: "commit", details: "Fixed the thing"}}.to_json
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "commit", json["action"]
  end

  test "create rejects missing action" do
    project = projects(:working)
    assert_no_difference("Activity.count") do
      post api_v1_project_activities_url(project), headers: api_headers,
        params: {activity: {action: "", details: "no action"}}.to_json
    end
    assert_response :unprocessable_entity
  end
end
