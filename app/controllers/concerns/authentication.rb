module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :signed_in?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = current_session&.user
  end

  def current_session
    @current_session ||= begin
      session_id = cookies.signed[:session_id]
      Session.find_by(id: session_id) if session_id
    end
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    return if signed_in?

    redirect_to sign_in_path, alert: "Sign in to continue."
  end

  def sign_in(user)
    session_record = user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    cookies.signed.permanent[:session_id] = {
      value: session_record.id,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
    @current_user = user
    @current_session = session_record
  end

  def sign_out
    current_session&.destroy
    cookies.delete(:session_id)
    @current_user = nil
    @current_session = nil
  end
end
