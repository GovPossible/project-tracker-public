require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "index shows active projects" do
    get projects_url
    assert_response :success
    assert_select "a", projects(:working).title
  end

  test "index filters by status" do
    get projects_url(status: "done")
    assert_response :success
  end

  test "index search returns matching projects" do
    get projects_url(q: "GL posting")
    assert_response :success
    assert_select "a", projects(:working).title
  end

  test "index search with status filter" do
    get projects_url(q: "license", status: "queued")
    assert_response :success
    assert_select "a", projects(:queued_normal).title
  end

  test "index empty search returns all active" do
    get projects_url(q: "")
    assert_response :success
    assert_select "a", projects(:working).title
  end

  test "index search no match shows empty state" do
    get projects_url(q: "zzzznotfound")
    assert_response :success
    assert_select "div", "No projects found."
  end

  test "show displays project" do
    get project_url(projects(:working))
    assert_response :success
    assert_select "h1", projects(:working).title
  end

  test "new renders form" do
    get new_project_url
    assert_response :success
    assert_select "form"
  end

  test "create saves valid project" do
    assert_difference("Project.count") do
      post projects_url, params: {project: {title: "Test project", priority: "normal", source: "manual"}}
    end
    assert_redirected_to project_url(Project.last)
  end

  test "create saves project with file_urls" do
    urls = ["https://res.cloudinary.com/test/raw/upload/v1/spec.pdf", "https://res.cloudinary.com/test/image/upload/v1/mockup.png"]
    assert_difference("Project.count") do
      post projects_url, params: {project: {title: "With files", priority: "normal", source: "manual", file_urls: urls}}
    end
    assert_equal urls, Project.last.file_urls
  end

  test "create strips blank file_urls" do
    assert_difference("Project.count") do
      post projects_url, params: {project: {title: "Blank files", priority: "normal", source: "manual", file_urls: ["", "https://res.cloudinary.com/test/raw/upload/v1/spec.pdf", ""]}}
    end
    assert_equal ["https://res.cloudinary.com/test/raw/upload/v1/spec.pdf"], Project.last.file_urls
  end

  test "create rejects invalid project" do
    assert_no_difference("Project.count") do
      post projects_url, params: {project: {title: ""}}
    end
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_project_url(projects(:working))
    assert_response :success
    assert_select "form"
  end

  test "update saves changes" do
    project = projects(:working)
    patch project_url(project), params: {project: {title: "Updated title"}}
    assert_redirected_to project_url(project)
    assert_equal "Updated title", project.reload.title
  end

  test "add_reply creates dashboard reply" do
    project = projects(:working)
    assert_difference("Reply.count") do
      post add_reply_project_url(project), params: {body: "Please use the existing helper"}
    end
    assert_redirected_to project_url(project)
    reply = Reply.last
    assert_equal "dashboard", reply.channel
    assert_equal "Admin (dashboard)", reply.from_address
    assert_equal "Please use the existing helper", reply.body
    assert_not reply.read
  end

  test "add_reply creates reply with image_urls" do
    project = projects(:working)
    assert_difference("Reply.count") do
      post add_reply_project_url(project), params: {body: "See screenshot", image_urls: ["https://res.cloudinary.com/test/image/upload/v1/test.png"]}
    end
    reply = Reply.last
    assert_equal ["https://res.cloudinary.com/test/image/upload/v1/test.png"], reply.image_urls
    assert_equal "See screenshot", reply.body
  end

  test "add_reply creates reply with image_urls only" do
    project = projects(:working)
    assert_difference("Reply.count") do
      post add_reply_project_url(project), params: {body: "", image_urls: ["https://res.cloudinary.com/test/image/upload/v1/test.png"]}
    end
    reply = Reply.last
    assert_equal ["https://res.cloudinary.com/test/image/upload/v1/test.png"], reply.image_urls
    assert_nil reply.body
  end

  test "add_reply transitions pr_review to waiting_input" do
    project = projects(:pr_review)
    post add_reply_project_url(project), params: {body: "Changes requested"}
    assert_redirected_to project_url(project)
    assert_equal "waiting_input", project.reload.status
  end

  test "nudge creates Admin reply on waiting_input project" do
    project = projects(:waiting_input)
    assert_difference("Reply.count") do
      post nudge_project_url(project)
    end
    assert_redirected_to project_url(project)
    reply = Reply.last
    assert_equal "dashboard", reply.channel
    assert_equal "Admin (dashboard)", reply.from_address
    assert_equal "Please continue working on this.", reply.body
  end

  test "show displays waiting on badge for waiting_input project" do
    project = projects(:waiting_input)
    # Agent reply makes it "waiting on you"
    project.replies.create!(channel: :dashboard, from_address: "Agent", body: "Question for you", received_at: Time.current, read: false)
    get project_url(project)
    assert_response :success
    assert_select "span", "Waiting on you"
  end

  test "show displays waiting on agent badge when Admin replied last" do
    project = projects(:waiting_input)
    project.replies.create!(channel: :dashboard, from_address: "Admin (dashboard)", body: "My answer", received_at: Time.current, read: false)
    get project_url(project)
    assert_response :success
    assert_select "span", "Waiting on agent"
  end

  test "destroy deletes project" do
    project = projects(:queued_normal)
    assert_difference("Project.count", -1) do
      delete project_url(project)
    end
    assert_redirected_to projects_url
  end
end
