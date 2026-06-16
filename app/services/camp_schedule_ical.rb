# Minimal RFC 5545 generator for a single writer's camp schedule. We hand-roll
# the output rather than pulling in the icalendar gem because the surface is
# small and we want predictable diffs in tests.
class CampScheduleIcal
  PRODID = "-//Keens Song Camp//Schedule//EN".freeze
  CRLF   = "\r\n".freeze

  def initialize(camp:, user:, sessions:)
    @camp = camp
    @user = user
    @sessions = sessions
  end

  def to_s
    lines = []
    lines << "BEGIN:VCALENDAR"
    lines << "VERSION:2.0"
    lines << "PRODID:#{PRODID}"
    lines << "CALSCALE:GREGORIAN"
    lines << "METHOD:PUBLISH"
    lines << fold("X-WR-CALNAME:#{escape_text(@camp.name)} — #{escape_text(@user.display_name)}")
    @sessions.each { |s| lines.concat(event_lines(s)) }
    lines << "END:VCALENDAR"
    lines.join(CRLF) + CRLF
  end

  private

  def event_lines(session)
    lines = []
    lines << "BEGIN:VEVENT"
    lines << "UID:keens-camp-session-#{session.id}@keens.app"
    lines << "DTSTAMP:#{ics_time(session.updated_at)}"
    lines << "DTSTART:#{ics_time(session.starts_at)}"
    lines << "DTEND:#{ics_time(session.ends_at)}"
    lines << fold("SUMMARY:#{escape_text(session.display_title)} — #{escape_text(@camp.name)}")
    lines << fold("LOCATION:#{escape_text(session.room)}") if session.room.present?
    desc = description_for(session)
    lines << fold("DESCRIPTION:#{escape_text(desc)}") if desc.present?
    lines << "END:VEVENT"
    lines
  end

  def description_for(session)
    co_writers = session.session_assignments
      .reject { |a| a.writer_id == @user.id }
      .map { |a| a.writer.display_name }
    return nil if co_writers.empty?

    "Co-writers: #{co_writers.join(', ')}"
  end

  def ics_time(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def escape_text(value)
    value.to_s
      .gsub("\\", "\\\\\\\\")
      .gsub("\n", "\\n")
      .gsub(",", "\\,")
      .gsub(";", "\\;")
  end

  # RFC 5545 lines must be wrapped at 75 octets with a CRLF + space.
  def fold(line)
    return line if line.bytesize <= 75

    parts = []
    remaining = line
    while remaining.bytesize > 75
      parts << remaining.byteslice(0, 75)
      remaining = remaining.byteslice(75, remaining.bytesize - 75)
    end
    parts << remaining
    parts.join("#{CRLF} ")
  end
end
