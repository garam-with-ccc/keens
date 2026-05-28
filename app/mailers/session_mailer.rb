class SessionMailer < ApplicationMailer
  def magic_link(user, token, magic_link)
    @user = user
    @sign_in_url = magic_link_url(token: token)
    @expires_at = magic_link.expires_at

    mail to: user.email, subject: "Your sign-in link for Keens"
  end
end
