module Organizer
  class WriterInvitesController < BaseController
    before_action :set_camp

    def create
      email = params.dig(:writer_invite, :email).to_s.strip.downcase
      name  = params.dig(:writer_invite, :name).to_s.strip

      if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        redirect_to organizer_camp_roster_path(@camp),
          alert: "Enter a valid writer email." and return
      end

      writer = User.find_or_initialize_by(email: email)
      writer.role = "writer" if writer.new_record? && writer.role.blank?
      writer.name = name if name.present? && writer.name.blank?
      writer.save!

      @camp.memberships.find_or_create_by!(user: writer)

      invite, token = WriterInvite.issue!(
        camp: @camp,
        user: writer,
        invited_by: current_user
      )
      WriterInviteMailer.invitation(invite, token).deliver_later

      redirect_to organizer_camp_roster_path(@camp),
        notice: "Invite sent to #{writer.email}."
    end

    private

    def set_camp
      @camp = current_user.organized_camps.find(params[:camp_id])
    end
  end
end
