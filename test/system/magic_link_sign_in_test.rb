require "application_system_test_case"

class MagicLinkSignInSystemTest < ApplicationSystemTestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "writer signs in via emailed magic link and lands on /me" do
    visit "/sign_in"
    assert_text "Sign in"

    fill_in "Email address", with: "writer@example.com"
    click_button "Send sign-in link"

    assert_text "Check your email"
    assert_text "writer@example.com"

    mail = ActionMailer::Base.deliveries.last
    assert mail, "no sign-in email was delivered"
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    token = body[%r{/sign_in/magic/([A-Za-z0-9_\-]+)}, 1]
    assert token.present?, "magic-link token not found in email body"

    visit "/sign_in/magic/#{token}"
    click_button "Sign in to Keens"

    assert_text "You're signed in"
    assert_text "writer@example.com"
    assert_text "writer" # role
  end
end
