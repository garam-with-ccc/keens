class WriterInvitesController < ApplicationController
  allow_unauthenticated_access

  # GET /invite/:token — confirmation page (never consumes the invite on a GET)
  def show
    @token = params[:token].to_s
    @invite = WriterInvite.find_live_by_token(@token)

    if @invite.nil?
      render :invalid, status: :unprocessable_entity
    end
  end

  # POST /invite/:token — accept invite, sign user in, redirect to camp schedule
  def create
    token = params[:token].to_s
    invite = WriterInvite.find_live_by_token(token)

    if invite.nil?
      @token = token
      render :invalid, status: :unprocessable_entity and return
    end

    ActiveRecord::Base.transaction do
      invite.accept!
      invite.camp.memberships.find_or_create_by!(user: invite.user)
    end

    sign_in(invite.user)
    redirect_to camp_path(invite.camp), notice: "Welcome to #{invite.camp.name}."
  end
end
