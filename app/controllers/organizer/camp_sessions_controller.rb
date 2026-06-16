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
      invited_count = 0

      ActiveRecord::Base.transaction do
        @camp_session.save!
        invited_count = assign_writers!(@camp_session, @writer_emails)
      end

      redirect_to organizer_camp_session_path(@camp, @camp_session),
        notice: session_saved_notice("Session created.", invited_count)
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
      invited_count = 0

      ActiveRecord::Base.transaction do
        @camp_session.update!(camp_session_params)
        invited_count = assign_writers!(@camp_session, @writer_emails) if @writer_emails.present?
      end

      redirect_to organizer_camp_session_path(@camp, @camp_session),
        notice: session_saved_notice("Session updated.", invited_count)
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
      invited = 0
      emails.each do |email|
        result = WriterInviter.invite!(
          camp: @camp,
          email: email,
          invited_by: current_user,
          skip_if_live: true
        )
        next if result.invalid?

        camp_session.session_assignments.find_or_create_by!(writer: result.writer)
        invited += 1 if result.invited?
      end
      invited
    end

    def session_saved_notice(base_message, invited_count)
      return base_message if invited_count.zero?

      "#{base_message} #{invited_count} #{'invite'.pluralize(invited_count)} sent."
    end
  end
end
