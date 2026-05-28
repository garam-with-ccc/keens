require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "root renders the landing page" do
    get root_path
    assert_response :success
    assert_select "h1", text: "Keens Song Camp"
  end
end
