# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth Passwords' do
  describe 'GET /auth/password/edit' do
    context 'with invalid reset_password_token' do
      it 'redirects to #new' do
        get edit_user_password_path, params: { reset_password_token: 'some_invalid_value' }

        expect(response)
          .to redirect_to new_user_password_path
      end
    end
  end

  describe 'PUT /auth/password' do
    let(:user) { Fabricate(:user) }
    let(:password) { 'reset0password' }

    context 'with invalid reset_password_token' do
      it 'renders reset password and retains password' do
        put user_password_path, params: { user: { password: password, password_confirmation: password, reset_password_token: 'some_invalid_value' } }

        expect(response.body)
          .to include(I18n.t('auth.set_new_password'))

        expect(User.find(user.id))
          .to be_present
          .and be_external_or_valid_password(user.password)
      end
    end
  end

  describe 'when OMNIAUTH_ONLY is set' do
    it 'rejects the forgot-password request path' do
      ClimateControl.modify OMNIAUTH_ONLY: 'true' do
        get new_user_password_path
      end

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq I18n.t('auth.omniauth_only_password_disabled')
    end

    it 'rejects the reset-confirmation path even with a valid token' do
      user = Fabricate(:user)
      token = user.send_reset_password_instructions

      ClimateControl.modify OMNIAUTH_ONLY: 'true' do
        get edit_user_password_path, params: { reset_password_token: token }
      end

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq I18n.t('auth.omniauth_only_password_disabled')
    end
  end
end
