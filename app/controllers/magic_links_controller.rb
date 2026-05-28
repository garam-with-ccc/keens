class MagicLinksController < ApplicationController
  allow_unauthenticated_access

  # GET /sign_in/magic/:token
  # Shows a confirmation page with a POST button. We never consume the token on
  # a GET request so that email scanners and link previewers cannot burn it.
  def show
    @token = params[:token].to_s
    @magic_link = MagicLink.find_live_by_token(@token)

    if @magic_link.nil?
      render :invalid, status: :unprocessable_entity
    end
  end

  # POST /sign_in/magic/:token
  # Consumes a still-live token (single-use, time-limited) and creates a session.
  def create
    token = params[:token].to_s
    magic_link = MagicLink.find_live_by_token(token)

    if magic_link.nil?
      @token = token
      render :invalid, status: :unprocessable_entity and return
    end

    ActiveRecord::Base.transaction do
      magic_link.consume!
    end

    sign_in(magic_link.user)
    redirect_to me_path, notice: "Signed in."
  end
end
