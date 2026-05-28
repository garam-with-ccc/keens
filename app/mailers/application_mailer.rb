class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Keens <no-reply@keens.local>")
  layout "mailer"
end
