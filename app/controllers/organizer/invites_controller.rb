module Organizer
  class InvitesController < BaseController
    def index
      @invites = OrganizerInvite.includes(:user, :invited_by).recent.limit(50)
    end

    def create
      email = params.dig(:organizer_invite, :email).to_s.strip.downcase
      name  = params.dig(:organizer_invite, :name).to_s.strip

      if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        redirect_to organizer_invites_path,
          alert: "Enter a valid organizer email." and return
      end

      user = User.find_or_initialize_by(email: email)
      user.role = "organizer"
      user.name = name if name.present? && user.name.blank?
      user.save!

      invite, token = OrganizerInvite.issue!(user: user, invited_by: current_user)
      OrganizerInviteMailer.invitation(invite, token).deliver_later

      redirect_to organizer_invites_path,
        notice: "Invite sent to #{user.email}."
    end
  end
end
