require "test_helper"

class OrganizerCampFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @organizer = User.create!(email: "organizer@example.com", role: "organizer")
    sign_in_as(@organizer)
  end

  test "organizer creates a camp, adds a session, assigns a writer, and views the session" do
    # Create the camp
    assert_difference -> { Camp.count }, 1 do
      post organizer_camps_path, params: {
        camp: {
          name: "Spring House Camp",
          start_date: "2026-06-01",
          end_date: "2026-06-03",
          brief: "Pop / R&B with a folk edge.",
          target_artist: "Sabrina Carpenter"
        }
      }
    end
    camp = Camp.last
    assert_equal @organizer.id, camp.organizer_id
    assert_redirected_to organizer_camp_path(camp)

    # Add a session and assign a writer by email — creates a new User
    assert_difference -> { CampSession.count }, 1 do
      assert_difference -> { User.where(role: "writer").count }, 1 do
        assert_difference -> { SessionAssignment.count }, 1 do
          post organizer_camp_sessions_path(camp), params: {
            camp_session: {
              title: "Day 1 / Room A",
              room: "Studio A",
              starts_at: "2026-06-01T10:00",
              ends_at: "2026-06-01T15:00",
              writer_emails: "alice@example.com"
            }
          }
        end
      end
    end

    sess = CampSession.last
    assert_redirected_to organizer_camp_session_path(camp, sess)
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Day 1 \/ Room A/
    assert_select "li", text: /alice@example.com/

    # Roster page lists the writer
    get organizer_camp_roster_path(camp)
    assert_response :success
    assert_select "li", text: /alice@example.com/
  end

  test "organizer cannot view another organizer's camp" do
    other = User.create!(email: "other@example.com", role: "organizer")
    other_camp = other.organized_camps.create!(
      name: "Not yours",
      start_date: Date.current, end_date: Date.current + 1
    )

    get organizer_camp_path(other_camp)
    assert_response :not_found
  end

  test "writer cannot reach organizer admin pages" do
    sign_out_helper!
    writer = User.create!(email: "writer@example.com", role: "writer")
    sign_in_as(writer)

    get organizer_camps_path
    assert_redirected_to me_path
    assert_equal "Only organizers can access that page.", flash[:alert]

    camp = @organizer.organized_camps.create!(
      name: "Closed Door",
      start_date: Date.current, end_date: Date.current + 1
    )
    get organizer_camp_path(camp)
    assert_redirected_to me_path
  end

  test "unauthenticated user is redirected to sign-in" do
    sign_out_helper!
    get organizer_camps_path
    assert_redirected_to sign_in_path
  end

  test "session form rejects ends_at <= starts_at" do
    camp = @organizer.organized_camps.create!(
      name: "Validation camp",
      start_date: Date.current, end_date: Date.current + 1
    )
    assert_no_difference -> { CampSession.count } do
      post organizer_camp_sessions_path(camp), params: {
        camp_session: {
          starts_at: "2026-06-01T10:00",
          ends_at: "2026-06-01T09:00"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_select "li", text: /must be after the start time/i
  end

  private

  def sign_in_as(user)
    perform_enqueued_jobs do
      post sign_in_path, params: { email: user.email }
    end
    token = extract_token_from_last_email
    post consume_magic_link_path(token: token)
  end

  def sign_out_helper!
    delete sign_out_path
    reset!
  end

  def extract_token_from_last_email
    mail = ActionMailer::Base.deliveries.last
    body = mail.multipart? ? mail.parts.map { |p| p.body.to_s }.join("\n") : mail.body.to_s
    match = body.match(%r{/sign_in/magic/([A-Za-z0-9_\-]+)})
    match[1]
  end
end
