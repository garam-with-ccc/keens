module Organizer
  class CampsController < BaseController
    before_action :set_camp, only: %i[show edit update destroy]

    def index
      @camps = current_user.organized_camps.recent
    end

    def new
      @camp = current_user.organized_camps.build(start_date: Date.current, end_date: Date.current + 2)
    end

    def create
      @camp = current_user.organized_camps.build(camp_params)
      if @camp.save
        redirect_to organizer_camp_path(@camp), notice: "Camp created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @sessions = @camp.camp_sessions.chronological
    end

    def edit
    end

    def update
      if @camp.update(camp_params)
        redirect_to organizer_camp_path(@camp), notice: "Camp updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @camp.destroy
      redirect_to organizer_camps_path, notice: "Camp deleted.", status: :see_other
    end

    private

    def set_camp
      @camp = current_user.organized_camps.find(params[:id])
    end

    def camp_params
      params.require(:camp).permit(:name, :start_date, :end_date, :brief, :target_artist)
    end
  end
end
