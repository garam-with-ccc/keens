require "test_helper"

class MagicLinkSignInTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "happy path: request magic link, follow it, land on /me signed in" do
    assert_difference -> { User.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        perform_enqueued_jobs do
          post sign_in_path, params: { email: "writer@example.com" }
        end
      end
    end

    assert_redirected_to sign_in_sent_path(email: "writer@example.com")
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Check your email/i

    user = User.find_by!(email: "writer@example.com")
    assert_equal "writer", user.role

    token = extract_token_from_last_email
    assert token.present?

    get magic_link_path(token: token)
    assert_response :success
    assert_select "form[action=?]", consume_magic_link_path(token: token)

    post consume_magic_link_path(token: token)
    assert_redirected_to me_path
    follow_redirect!
    assert_response :success
    assert_select "dd", text: "writer@example.com"
    assert_equal 1, user.sessions.count
  end

  test "token reuse is rejected after first consumption" do
    User.create!(email: "writer@example.com")
    perform_enqueued_jobs do
      post sign_in_path, params: { email: "writer@example.com" }
    end
    token = extract_token_from_last_email

    post consume_magic_link_path(token: token)
    assert_redirected_to me_path

    # Use a fresh session — same browser, but token is already burned.
    reset!
    post consume_magic_link_path(token: token)
    assert_response :unprocessable_entity
    assert_select "h1", text: /Link expired or already used/i

    get me_path
    assert_redirected_to sign_in_path
  end

  test "expired token is rejected" do
    User.create!(email: "writer@example.com")
    perform_enqueued_jobs do
      post sign_in_path, params: { email: "writer@example.com" }
    end
    token = extract_token_from_last_email

    travel (MagicLink::DEFAULT_LIFETIME + 1.minute) do
      post consume_magic_link_path(token: token)
      assert_response :unprocessable_entity
      assert_select "h1", text: /Link expired or already used/i
    end
  end

  test "/me requires authentication and bounces to sign_in" do
    get me_path
    assert_redirected_to sign_in_path
  end

  test "invalid email format is rejected with no link issued" do
    assert_no_difference -> { MagicLink.count } do
      post sign_in_path, params: { email: "not-an-email" }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /valid email/i
  end

  test "sign_in_sent without email param bounces back to sign_in" do
    get sign_in_sent_path
    assert_redirected_to sign_in_path
  end

  test "sign-out clears the session and protects /me again" do
    user = User.create!(email: "writer@example.com")
    perform_enqueued_jobs do
      post sign_in_path, params: { email: user.email }
    end
    token = extract_token_from_last_email
    post consume_magic_link_path(token: token)

    delete sign_out_path
    assert_redirected_to root_path

    get me_path
    assert_redirected_to sign_in_path
  end

  private

  def extract_token_from_last_email
    mail = ActionMailer::Base.deliveries.last
    assert mail, "no email was delivered"
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    match = body.match(%r{/sign_in/magic/([A-Za-z0-9_\-]+)})
    assert match, "magic-link URL not found in email body: #{body[0, 400]}"
    match[1]
  end
end
