module Organizer
  class CampSessionsController < BaseController
    before_action :set_camp
    before_action :set_session, only: %i[show edit update destroy]

    def new
      default_start = default_starts_at
      @camp_session = @camp.camp_sessions.build(starts_at: default_start, ends_at: default_start + 3.hours)
      @writer_emails = ""
    end

    def create
      @camp_session = @camp.camp_sessions.build(camp_session_params)
      @writer_emails = params.dig(:camp_session, :writer_emails).to_s

      ActiveRecord::Base.transaction do
        @camp_session.save!
        assign_writers!(@camp_session, @writer_emails)
      end

      redirect_to organizer_camp_session_path(@camp, @camp_session), notice: "Session created."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
      @assignments = @camp_session.session_assignments.includes(:writer)
    end

    def edit
      @writer_emails = ""
    end

    def update
      @writer_emails = params.dig(:camp_session, :writer_emails).to_s

      ActiveRecord::Base.transaction do
        @camp_session.update!(camp_session_params)
        assign_writers!(@camp_session, @writer_emails) if @writer_emails.present?
      end

      redirect_to organizer_camp_session_path(@camp, @camp_session), notice: "Session updated."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @camp_session.destroy
      redirect_to organizer_camp_path(@camp), notice: "Session deleted.", status: :see_other
    end

    private

    def set_camp
      @camp = current_user.organized_camps.find(params[:camp_id])
    end

    def set_session
      @camp_session = @camp.camp_sessions.find(params[:id])
    end

    def camp_session_params
      params.require(:camp_session).permit(:title, :room, :starts_at, :ends_at)
    end

    def default_starts_at
      base = @camp.start_date.in_time_zone
      base.change(hour: 10)
    end

    def assign_writers!(camp_session, emails_blob)
      emails = emails_blob.to_s.split(/[\s,]+/).map { |e| e.strip.downcase }.reject(&:blank?).uniq
      emails.each do |email|
        next unless email.match?(URI::MailTo::EMAIL_REGEXP)

        writer = User.find_or_create_by!(email: email) do |u|
          u.role = "writer"
        end
        camp_session.session_assignments.find_or_create_by!(writer: writer)
      end
    end
  end
end
