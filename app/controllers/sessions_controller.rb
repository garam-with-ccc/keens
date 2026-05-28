class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create sent]

  def new
    redirect_to me_path and return if signed_in?
  end

  def create
    email = params[:email].to_s.strip.downcase

    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = "Enter a valid email address."
      render :new, status: :unprocessable_entity and return
    end

    user = User.find_or_create_by!(email: email) do |u|
      u.role = "writer"
    end

    magic_link, token = MagicLink.issue!(
      user: user,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
    SessionMailer.magic_link(user, token, magic_link).deliver_later

    redirect_to sign_in_sent_path(email: email), status: :see_other
  end

  def sent
    @email = params[:email].to_s
    redirect_to sign_in_path and return if @email.blank?
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Signed out."
  end
end
