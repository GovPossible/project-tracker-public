require "test_helper"

class Api::V1::WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "mailgun creates reply from inbound email" do
    project = projects(:waiting_input)
    assert_difference("Reply.count") do
      post api_v1_webhooks_mailgun_url, params: {
        sender: "user@example.com",
        subject: "[Project ##{project.id}] Re: Question about map",
        "stripped-text": "Use Mapbox please",
        timestamp: "1234567890",
        token: "test",
        signature: ""
      }
    end
    assert_response :success
    reply = Reply.last
    assert_equal "email", reply.channel
    assert_equal "Use Mapbox please", reply.body
    assert_equal project.id, reply.project_id
  end

  test "mailgun ignores email without project tag" do
    assert_no_difference("Reply.count") do
      post api_v1_webhooks_mailgun_url, params: {
        sender: "user@example.com",
        subject: "Random email",
        "stripped-text": "Hello",
        timestamp: "1234567890",
        token: "test",
        signature: ""
      }
    end
    assert_response :success
  end

  test "github pull_request_review creates reply" do
    project = projects(:pr_review)
    payload = {
      review: {
        state: "changes_requested",
        body: "Please fix the N+1 query",
        user: {login: "copilot"}
      },
      pull_request: {html_url: "https://github.com/example-org/erp/pull/99"}
    }.to_json

    assert_difference("Reply.count") do
      post api_v1_webhooks_github_url,
        params: payload,
        headers: {"X-GitHub-Event" => "pull_request_review", "Content-Type" => "application/json"}
    end
    assert_response :success
    reply = Reply.last
    assert_equal "github", reply.channel
    assert_equal "copilot", reply.from_address
    assert_includes reply.body, "Changes requested"
    assert_includes reply.body, "Please fix the N+1 query"
    assert_equal "waiting_input", project.reload.status
  end

  test "github pull_request_review_comment creates reply" do
    project = projects(:pr_review)
    payload = {
      comment: {
        body: "This variable is unused",
        path: "app/models/user.rb",
        line: 42,
        user: {login: "reviewer"}
      },
      pull_request: {html_url: "https://github.com/example-org/erp/pull/99"}
    }.to_json

    assert_difference("Reply.count") do
      post api_v1_webhooks_github_url,
        params: payload,
        headers: {"X-GitHub-Event" => "pull_request_review_comment", "Content-Type" => "application/json"}
    end
    assert_response :success
    reply = Reply.last
    assert_equal "github", reply.channel
    assert_equal "reviewer", reply.from_address
    assert_includes reply.body, "This variable is unused"
    assert_includes reply.body, "app/models/user.rb:42"
  end

  test "github issue_comment on PR creates reply" do
    project = projects(:pr_review)
    payload = {
      action: "created",
      issue: {
        pull_request: {html_url: "https://github.com/example-org/erp/pull/99"}
      },
      comment: {
        body: "LGTM overall",
        user: {login: "karl"}
      }
    }.to_json

    assert_difference("Reply.count") do
      post api_v1_webhooks_github_url,
        params: payload,
        headers: {"X-GitHub-Event" => "issue_comment", "Content-Type" => "application/json"}
    end
    assert_response :success
    reply = Reply.last
    assert_equal "github", reply.channel
    assert_equal "karl", reply.from_address
    assert_equal "LGTM overall", reply.body
  end

  test "github webhook transitions staging to waiting_input" do
    project = projects(:staging)
    payload = {
      review: {
        state: "changes_requested",
        body: "One more fix needed",
        user: {login: "copilot"}
      },
      pull_request: {html_url: "https://github.com/example-org/erp/pull/100"}
    }.to_json

    post api_v1_webhooks_github_url,
      params: payload,
      headers: {"X-GitHub-Event" => "pull_request_review", "Content-Type" => "application/json"}
    assert_response :success
    assert_equal "waiting_input", project.reload.status
  end

  test "github webhook with unknown PR URL returns 200" do
    payload = {
      review: {state: "approved", body: "Looks good", user: {login: "someone"}},
      pull_request: {html_url: "https://github.com/example-org/erp/pull/9999"}
    }.to_json

    assert_no_difference("Reply.count") do
      post api_v1_webhooks_github_url,
        params: payload,
        headers: {"X-GitHub-Event" => "pull_request_review", "Content-Type" => "application/json"}
    end
    assert_response :success
  end

  test "github webhook with invalid signature returns 401" do
    ENV["GITHUB_WEBHOOK_SECRET"] = "test-secret"
    payload = {review: {state: "approved", body: "ok", user: {login: "x"}}, pull_request: {html_url: "https://github.com/example-org/erp/pull/99"}}.to_json

    post api_v1_webhooks_github_url,
      params: payload,
      headers: {
        "X-GitHub-Event" => "pull_request_review",
        "Content-Type" => "application/json",
        "X-Hub-Signature-256" => "sha256=invalid"
      }
    assert_response :unauthorized
  ensure
    ENV.delete("GITHUB_WEBHOOK_SECRET")
  end

  test "twilio creates reply from inbound SMS" do
    project = projects(:waiting_input)
    project.activities.create!(action: "sms_sent", details: "Sent SMS")

    assert_difference("Reply.count") do
      post api_v1_webhooks_twilio_url, params: {
        From: "+15551234567",
        Body: "Yes, go ahead"
      }
    end
    assert_response :success
    reply = Reply.last
    assert_equal "sms", reply.channel
    assert_equal "Yes, go ahead", reply.body
  end
end
