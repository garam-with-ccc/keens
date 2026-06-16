require "test_helper"

class OrganizerInviteFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @organizer = User.create!(email: "founder@example.com", role: "organizer", name: "Original Organizer")
  end

  test "happy path: existing organizer invites a new organizer, recipient accepts and lands on organizer camps" do
    sign_in_as(@organizer)

    fresh_email = "newceo@example.com"
    assert_nil User.find_by(email: fresh_email)

    assert_difference -> { User.where(role: "organizer").count }, 1 do
      assert_difference -> { OrganizerInvite.count }, 1 do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          perform_enqueued_jobs do
            post organizer_invites_path, params: {
              organizer_invite: { email: fresh_email, name: "New CEO" }
            }
          end
        end
      end
    end
    assert_redirected_to organizer_invites_path

    invited = User.find_by!(email: fresh_email)
    assert_equal "organizer", invited.role
    assert_equal "New CEO", invited.name

    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.subject, "organize on Keens"
    assert_equal [ fresh_email ], mail.to

    token = extract_organizer_invite_token_from_last_email
    assert token.present?

    reset!

    get organizer_invite_path(token: token)
    assert_response :success
    assert_select "form[action=?]", consume_organizer_invite_path(token: token)

    post consume_organizer_invite_path(token: token)
    assert_redirected_to organizer_camps_path

    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Your camps/i
  end

  test "promotes an existing writer to organizer when invited" do
    sign_in_as(@organizer)
    existing = User.create!(email: "writer@example.com", role: "writer", name: "Wanda Writer")

    assert_no_difference -> { User.count } do
      assert_difference -> { OrganizerInvite.count }, 1 do
        perform_enqueued_jobs do
          post organizer_invites_path, params: {
            organizer_invite: { email: existing.email }
          }
        end
      end
    end

    assert_equal "organizer", existing.reload.role
    assert_equal "Wanda Writer", existing.name

    token = extract_organizer_invite_token_from_last_email
    reset!
    post consume_organizer_invite_path(token: token)
    assert_redirected_to organizer_camps_path
  end

  test "invite token can only be used once" do
    sign_in_as(@organizer)
    perform_enqueued_jobs do
      post organizer_invites_path, params: { organizer_invite: { email: "single@example.com" } }
    end
    token = extract_organizer_invite_token_from_last_email

    reset!
    post consume_organizer_invite_path(token: token)
    assert_redirected_to organizer_camps_path

    reset!
    post consume_organizer_invite_path(token: token)
    assert_response :unprocessable_entity
    assert_select "h1", text: /Invite expired or already used/i
  end

  test "expired invite token is rejected" do
    sign_in_as(@organizer)
    perform_enqueued_jobs do
      post organizer_invites_path, params: { organizer_invite: { email: "tardy@example.com" } }
    end
    token = extract_organizer_invite_token_from_last_email

    reset!
    travel (OrganizerInvite::DEFAULT_LIFETIME + 1.minute) do
      post consume_organizer_invite_path(token: token)
      assert_response :unprocessable_entity
      assert_select "h1", text: /Invite expired or already used/i
    end
  end

  test "fake organizer-invite token is rejected on show" do
    get organizer_invite_path(token: "not-a-real-token")
    assert_response :unprocessable_entity
    assert_select "h1", text: /Invite expired or already used/i
  end

  test "non-organizers cannot access the organizer invites admin pages" do
    writer = User.create!(email: "writer@example.com", role: "writer")
    sign_in_as(writer)

    get organizer_invites_path
    assert_redirected_to me_path

    assert_no_difference -> { OrganizerInvite.count } do
      post organizer_invites_path, params: { organizer_invite: { email: "sneaky@example.com" } }
    end
  end

  test "organizer invites admin form rejects invalid email" do
    sign_in_as(@organizer)
    assert_no_difference -> { OrganizerInvite.count } do
      post organizer_invites_path, params: { organizer_invite: { email: "not-an-email" } }
    end
    assert_redirected_to organizer_invites_path
    follow_redirect!
    assert_select "[role=alert]", text: /valid organizer email/i
  end

  test "random sign-in does not become organizer" do
    perform_enqueued_jobs do
      post sign_in_path, params: { email: "random@example.com" }
    end
    user = User.find_by!(email: "random@example.com")
    assert_equal "writer", user.role
  end

  test "bootstrap allow-list promotes brand-new users to organizer" do
    ENV["KEENS_BOOTSTRAP_ORGANIZER_EMAILS"] = "ceo@keens.example, partner@example.com"

    perform_enqueued_jobs do
      post sign_in_path, params: { email: "ceo@keens.example" }
    end
    assert_equal "organizer", User.find_by!(email: "ceo@keens.example").role

    perform_enqueued_jobs do
      post sign_in_path, params: { email: "outsider@example.com" }
    end
    assert_equal "writer", User.find_by!(email: "outsider@example.com").role
  ensure
    ENV.delete("KEENS_BOOTSTRAP_ORGANIZER_EMAILS")
  end

  test "bootstrap allow-list does NOT downgrade or upgrade existing users" do
    User.create!(email: "alreadywriter@example.com", role: "writer")
    ENV["KEENS_BOOTSTRAP_ORGANIZER_EMAILS"] = "alreadywriter@example.com"

    perform_enqueued_jobs do
      post sign_in_path, params: { email: "alreadywriter@example.com" }
    end

    assert_equal "writer", User.find_by!(email: "alreadywriter@example.com").role,
      "Existing users are not promoted by the allow-list — they must go through the invite flow."
  ensure
    ENV.delete("KEENS_BOOTSTRAP_ORGANIZER_EMAILS")
  end

  private

  def sign_in_as(user)
    perform_enqueued_jobs do
      post sign_in_path, params: { email: user.email }
    end
    token = extract_magic_link_token_from_last_email
    post consume_magic_link_path(token: token)
  end

  def extract_magic_link_token_from_last_email
    mail = ActionMailer::Base.deliveries.last
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    match = body.match(%r{/sign_in/magic/([A-Za-z0-9_\-]+)})
    match[1]
  end

  def extract_organizer_invite_token_from_last_email
    mail = ActionMailer::Base.deliveries.last
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    match = body.match(%r{/organizer-invite/([A-Za-z0-9_\-]+)})
    match && match[1]
  end
end
