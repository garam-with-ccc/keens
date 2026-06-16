class WriterInviter
  Result = Struct.new(:writer, :invite, :token, :status, keyword_init: true) do
    def invited?
      status == :invited
    end

    def already_invited?
      status == :already_invited
    end

    def invalid?
      status == :invalid
    end
  end

  def self.invite!(camp:, email:, invited_by:, name: nil, skip_if_live: false)
    email = email.to_s.strip.downcase
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      return Result.new(status: :invalid)
    end

    writer = User.find_or_initialize_by(email: email)
    writer.role = "writer" if writer.new_record? && writer.role.blank?
    writer.name = name if name.present? && writer.name.blank?
    writer.save!

    camp.memberships.find_or_create_by!(user: writer)

    if skip_if_live
      existing = camp.writer_invites.live.find_by(user_id: writer.id)
      if existing
        return Result.new(writer: writer, invite: existing, status: :already_invited)
      end
    end

    invite, token = WriterInvite.issue!(camp: camp, user: writer, invited_by: invited_by)
    WriterInviteMailer.invitation(invite, token).deliver_later
    Result.new(writer: writer, invite: invite, token: token, status: :invited)
  end
end
