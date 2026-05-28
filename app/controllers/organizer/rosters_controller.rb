module Organizer
  class RostersController < BaseController
    def show
      @camp = current_user.organized_camps.find(params[:camp_id])
      @writers = @camp.roster.includes(:writer_profile)
      @sessions_by_writer = @camp.session_assignments
        .includes(:camp_session, :writer)
        .group_by(&:writer_id)
      @pending_invites = @camp.writer_invites.live.includes(:user).order(:created_at)
    end
  end
end
