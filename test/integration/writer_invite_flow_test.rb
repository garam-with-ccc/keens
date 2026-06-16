require "test_helper"

class WriterInviteFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @organizer = User.create!(email: "organizer@example.com", role: "organizer", name: "Olivia Organizer")
    @camp = @organizer.organized_camps.create!(
      name: "Spring House Camp",
      start_date: Date.new(2026, 6, 1),
      end_date: Date.new(2026, 6, 3),
      brief: "Pop / R&B with a folk edge.",
      target_artist: "Sabrina Carpenter"
    )
    @session = @camp.camp_sessions.create!(
      title: "Day 1 / Room A",
      room: "Studio A",
      starts_at: Time.zone.local(2026, 6, 1, 10, 0),
      ends_at:   Time.zone.local(2026, 6, 1, 13, 0)
    )
  end

  test "end-to-end: organizer invites a fresh writer, writer follows the link, lands on schedule" do
    sign_in_as(@organizer)

    fresh_email = "newwriter@example.com"
    assert_nil User.find_by(email: fresh_email), "writer should not exist yet"

    # Organizer sends the invite from the roster page
    assert_difference -> { User.count }, 1 do
      assert_difference -> { CampMembership.count }, 1 do
        assert_difference -> { WriterInvite.count }, 1 do
          assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
            perform_enqueued_jobs do
              post organizer_camp_writer_invites_path(@camp), params: {
                writer_invite: { name: "Nora Writer", email: fresh_email }
              }
            end
          end
        end
      end
    end
    assert_redirected_to organizer_camp_roster_path(@camp)

    writer = User.find_by!(email: fresh_email)
    assert_equal "writer", writer.role
    assert_equal "Nora Writer", writer.name

    # The roster page shows the writer
    follow_redirect!
    assert_response :success
    assert_select "li", text: /newwriter@example.com/

    # Email contains the invite link with the right subject
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.subject, @camp.name
    assert_equal [ fresh_email ], mail.to

    token = extract_invite_token_from_last_email
    assert token.present?, "invite token missing from email body"

    # Switch to the writer's session (fresh browser — no organizer cookies)
    reset!

    # GET the invite link — confirmation page, invite still live
    get writer_invite_path(token: token)
    assert_response :success
    assert_select "form[action=?]", consume_writer_invite_path(token: token)

    # Accept the invite — sign in + redirect to camp dashboard
    post consume_writer_invite_path(token: token)
    assert_redirected_to camp_path(@camp)

    follow_redirect!
    assert_response :success
    assert_select "h1", text: /#{@camp.name}/
    assert_select "p[role=status]", text: /Welcome to #{@camp.name}/

    # Empty-schedule branch is fine (no session yet)
    assert_select "p", text: /hasn't assigned you to any sessions yet/

    # Now assign the writer to the session and reload the dashboard
    @session.session_assignments.create!(writer: writer)
    get camp_path(@camp)
    assert_response :success
    assert_select "ol[data-testid=writer-schedule] li", count: 1
    assert_select "ol[data-testid=writer-schedule] li", text: /Day 1 \/ Room A/
    assert_select "ol[data-testid=writer-schedule] li", text: /Studio A/

    # iCal feed is reachable with the writer's calendar feed token, no cookies needed
    feed_token = writer.reload.calendar_feed_token
    assert feed_token.present?, "feed token should have been provisioned on dashboard render"

    reset!
    get camp_schedule_path(@camp, token: feed_token, format: :ics)
    assert_response :success
    assert_includes response.content_type, "text/calendar"
    body = response.body
    assert_includes body, "BEGIN:VCALENDAR"
    assert_includes body, "END:VCALENDAR"
    assert_includes body, "SUMMARY:Day 1 / Room A"
    assert_includes body, "LOCATION:Studio A"
  end

  test "invite token can only be used once" do
    writer = User.create!(email: "twouse@example.com", role: "writer")
    @camp.memberships.create!(user: writer)
    invite, token = WriterInvite.issue!(camp: @camp, user: writer, invited_by: @organizer)

    post consume_writer_invite_path(token: token)
    assert_redirected_to camp_path(@camp)

    reset!
    post consume_writer_invite_path(token: token)
    assert_response :unprocessable_entity
    assert_select "h1", text: /Invite expired or already used/i

    invite.reload
    assert invite.accepted?
  end

  test "invalid invite token shows expired page" do
    get writer_invite_path(token: "not-a-real-token")
    assert_response :unprocessable_entity
    assert_select "h1", text: /Invite expired or already used/i
  end

  test "camp schedule (.ics) refuses an unknown or missing token" do
    writer = User.create!(email: "feed@example.com", role: "writer")
    @camp.memberships.create!(user: writer)

    get camp_schedule_path(@camp, format: :ics)
    assert_response :not_found

    get camp_schedule_path(@camp, token: "nope", format: :ics)
    assert_response :not_found
  end

  test "camp dashboard refuses access to a non-member" do
    outsider = User.create!(email: "outsider@example.com", role: "writer")
    sign_in_as(outsider)
    get camp_path(@camp)
    assert_response :not_found
  end

  test "organizer invite form rejects an invalid email" do
    sign_in_as(@organizer)
    assert_no_difference -> { WriterInvite.count } do
      post organizer_camp_writer_invites_path(@camp), params: {
        writer_invite: { email: "not-an-email" }
      }
    end
    assert_redirected_to organizer_camp_roster_path(@camp)
    follow_redirect!
    assert_select "[role=alert]", text: /valid writer email/i
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

  def extract_invite_token_from_last_email
    mail = ActionMailer::Base.deliveries.last
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    match = body.match(%r{/invite/([A-Za-z0-9_\-]+)})
    match && match[1]
  end
end
