class OrganizerInvitesController < ApplicationController
  allow_unauthenticated_access

  # GET /organizer-invite/:token
  def show
    @token = params[:token].to_s
    @invite = OrganizerInvite.find_live_by_token(@token)

    if @invite.nil?
      render :invalid, status: :unprocessable_entity
    end
  end

  # POST /organizer-invite/:token
  def create
    token = params[:token].to_s
    invite = OrganizerInvite.find_live_by_token(token)

    if invite.nil?
      @token = token
      render :invalid, status: :unprocessable_entity and return
    end

    invite.accept!
    sign_in(invite.user)
    redirect_to organizer_camps_path, notice: "Welcome — you're set up as an organizer."
  end
end
