require "application_system_test_case"

# Captures a deterministic screenshot of the writer schedule view to attach to
# KEE-6. Saving the artifact under tmp/screenshots/ keeps it out of the repo
# (.gitignore already covers tmp/).
class WriterScheduleScreenshotTest < ApplicationSystemTestCase
  test "render writer schedule with a few sessions and save a screenshot" do
    organizer = User.create!(email: "olivia.organizer@keens.test", role: "organizer", name: "Olivia Organizer")
    camp = organizer.organized_camps.create!(
      name: "Spring House Camp 2026",
      start_date: Date.new(2026, 6, 1),
      end_date: Date.new(2026, 6, 3),
      brief: "Pop / R&B with a folk edge.",
      target_artist: "Sabrina Carpenter"
    )
    writer = User.create!(email: "nora.writer@keens.test", role: "writer", name: "Nora Writer")
    co1 = User.create!(email: "maya.linn@keens.test", role: "writer", name: "Maya Linn")
    co2 = User.create!(email: "sam.beck@keens.test", role: "writer", name: "Sam Beck")
    camp.memberships.create!(user: writer)

    sessions = [
      [ "Day 1 / Studio A", "Studio A", Time.zone.local(2026, 6, 1, 10, 0), Time.zone.local(2026, 6, 1, 13, 0), [ writer, co1 ] ],
      [ "Day 2 / Studio B", "Studio B", Time.zone.local(2026, 6, 2, 14, 0), Time.zone.local(2026, 6, 2, 17, 30), [ writer, co2 ] ],
      [ "Day 3 / Studio A", "Studio A", Time.zone.local(2026, 6, 3, 11, 0), Time.zone.local(2026, 6, 3, 14, 0), [ writer, co1, co2 ] ]
    ]
    sessions.each do |title, room, s, e, writers|
      sess = camp.camp_sessions.create!(title: title, room: room, starts_at: s, ends_at: e)
      writers.each { |w| sess.session_assignments.create!(writer: w); camp.memberships.find_or_create_by!(user: w) }
    end

    invite, token = WriterInvite.issue!(camp: camp, user: writer, invited_by: organizer)

    visit writer_invite_path(token: token)
    assert_text "You're invited to #{camp.name}"
    click_on "Accept and sign in as #{writer.email}"

    assert_text "Welcome to #{camp.name}"
    assert_selector "ol[data-testid='writer-schedule'] li", count: 3
    assert_text "Day 1 / Studio A"
    assert_text "Studio A"

    save_path = Rails.root.join("tmp/screenshots/writer_schedule.png")
    FileUtils.mkdir_p(save_path.dirname)
    page.save_screenshot(save_path.to_s)
    puts "[screenshot] saved: #{save_path}"
  end
end
