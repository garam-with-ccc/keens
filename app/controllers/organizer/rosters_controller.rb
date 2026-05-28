module Organizer
  class RostersController < BaseController
    def show
      @camp = current_user.organized_camps.find(params[:camp_id])
      @writers = @camp.writers.order(:email).includes(:writer_profile)
      @sessions_by_writer = @camp.session_assignments
        .includes(:camp_session, :writer)
        .group_by(&:writer_id)
    end
  end
end
