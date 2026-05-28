class WriterInviteMailer < ApplicationMailer
  def invitation(invite, token)
    @invite = invite
    @camp = invite.camp
    @invited_by = invite.invited_by
    @user = invite.user
    @accept_url = writer_invite_url(token: token)
    @expires_at = invite.expires_at

    mail to: @user.email, subject: "You're invited to #{@camp.name} on Keens"
  end
end
