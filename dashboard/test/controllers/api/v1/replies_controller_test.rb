require "test_helper"

class Api::V1::RepliesControllerTest < ActionDispatch::IntegrationTest
  test "index returns unread replies" do
    project = projects(:waiting_input)
    get api_v1_project_replies_url(project), headers: api_headers
    assert_response :success
    json = JSON.parse(response.body)
    assert json.any? { |r| r["id"] == replies(:unread_email).id }
    assert json.none? { |r| r["read"] == true }
  end

  test "create saves reply" do
    project = projects(:working)
    assert_difference("Reply.count") do
      post api_v1_project_replies_url(project), headers: api_headers,
        params: {reply: {channel: "email", from_address: "karl@test.com", body: "Looks good", received_at: Time.current.iso8601}}.to_json
    end
    assert_response :created
  end

  test "mark_read marks all unread replies as read" do
    project = projects(:waiting_input)
    assert project.replies.unread.exists?
    patch mark_read_api_v1_project_replies_url(project), headers: api_headers
    assert_response :success
    assert_not project.replies.unread.exists?
  end
end
