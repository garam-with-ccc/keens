module Organizer
  class WriterInvitesController < BaseController
    before_action :set_camp

    def create
      result = WriterInviter.invite!(
        camp: @camp,
        email: params.dig(:writer_invite, :email),
        name: params.dig(:writer_invite, :name),
        invited_by: current_user
      )

      if result.invalid?
        redirect_to organizer_camp_roster_path(@camp),
          alert: "Enter a valid writer email."
      else
        redirect_to organizer_camp_roster_path(@camp),
          notice: "Invite sent to #{result.writer.email}."
      end
    end

    private

    def set_camp
      @camp = current_user.organized_camps.find(params[:camp_id])
    end
  end
end
