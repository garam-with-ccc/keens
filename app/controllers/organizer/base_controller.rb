module Organizer
  class BaseController < ApplicationController
    before_action :require_organizer

    private

    def require_organizer
      return if current_user&.organizer?

      respond_to do |format|
        format.html { redirect_to me_path, alert: "Only organizers can access that page." }
        format.any  { head :forbidden }
      end
    end
  end
end
