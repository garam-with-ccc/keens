class OrganizerInviteMailer < ApplicationMailer
  def invitation(invite, token)
    @invite = invite
    @invited_by = invite.invited_by
    @user = invite.user
    @accept_url = organizer_invite_url(token: token)
    @expires_at = invite.expires_at

    mail to: @user.email, subject: "You're invited to organize on Keens"
  end
end
