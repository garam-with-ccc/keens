class MeController < ApplicationController
  def show
    @user = current_user
    @writer_camps = @user.writer_camps unless @user.organizer?
  end
end
