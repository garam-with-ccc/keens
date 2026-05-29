class CampsController < ApplicationController
  def show
    @camp = Camp.find_by(id: params[:id])

    if @camp.nil? || !@camp.member?(current_user)
      render plain: "Not found", status: :not_found and return
    end

    @sessions = @camp.camp_sessions
      .where(id: current_user.session_assignments.select(:camp_session_id))
      .includes(session_assignments: { writer: :writer_profile })
      .chronological

    @feed_token = current_user.ensure_calendar_feed_token!
  end
end
