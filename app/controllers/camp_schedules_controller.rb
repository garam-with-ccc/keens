class CampSchedulesController < ApplicationController
  allow_unauthenticated_access only: :show

  # GET /camps/:camp_id/schedule.ics?token=...
  # Calendar apps fetch the feed without browser cookies, so we authenticate
  # via a per-user feed token in the query string. Treat the token as a
  # capability scoped to that user's calendar feed.
  def show
    token = params[:token].to_s
    user  = User.find_by(calendar_feed_token: token) if token.present?

    return head :not_found if user.nil?

    camp = Camp.find_by(id: params[:camp_id])
    return head :not_found if camp.nil? || !camp.member?(user)

    sessions = camp.camp_sessions
      .where(id: user.session_assignments.select(:camp_session_id))
      .chronological

    ics = CampScheduleIcal.new(camp: camp, user: user, sessions: sessions).to_s

    response.headers["Content-Disposition"] = "inline; filename=\"#{camp.name.parameterize}.ics\""
    render plain: ics, content_type: "text/calendar; charset=utf-8"
  end
end
