require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "should get root dashboard" do
    get root_url
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "shows status counts" do
    get root_url
    assert_response :success
  end

  test "shows waiting projects" do
    get root_url
    assert_select "a", projects(:waiting_input).title
  end
end
