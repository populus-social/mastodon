# frozen_string_literal: true

class Auth::PasswordsController < Devise::PasswordsController
  skip_before_action :check_self_destruct!
  before_action :redirect_invalid_reset_token, only: :edit, unless: :reset_password_token_is_valid?

  prepend_before_action :reject_password_auth!, only: [:new, :create, :edit, :update]

  layout 'auth'

  def update
    super do |resource|
      if resource.errors.empty?
        resource.session_activations.destroy_all

        resource.revoke_access!
      end
    end
  end

  private

  def redirect_invalid_reset_token
    redirect_to new_password_path(resource_name), flash: { error: t('auth.invalid_reset_password_token') }
  end

  def reset_password_token_is_valid?
    resource_class.with_reset_password_token(params[:reset_password_token]).present?
  end

  def reject_password_auth!
    return unless ENV['OMNIAUTH_ONLY'] == 'true'

    redirect_to new_user_session_path, alert: I18n.t('auth.omniauth_only_password_disabled')
  end
end
