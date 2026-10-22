# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin account backups' do
  let(:role)    { UserRole.find_by(name: 'Admin') }
  let(:user)    { Fabricate(:user, role: role) }
  let(:scopes)  { 'admin:read:accounts admin:write:accounts' }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }
  let(:member)  { Fabricate(:user) }
  let(:account) { member.account }

  describe 'GET /api/v1/admin/accounts/:id/backup' do
    subject { get "/api/v1/admin/accounts/#{account.id}/backup", headers: headers }

    it_behaves_like 'forbidden for wrong scope', 'read read:accounts admin:write admin:write:accounts'
    it_behaves_like 'forbidden for wrong role', ''

    it 'answers 200 none when there is no backup' do
      subject

      expect(response).to have_http_status(200)
      expect(response.parsed_body).to eq('state' => 'none')
    end

    context 'with an unprocessed backup' do
      before { Fabricate(:backup, user: member, processed: false) }

      it 'answers pending' do
        subject

        expect(response.parsed_body).to eq('state' => 'pending')
      end
    end

    context 'with a processed backup' do
      before do
        Fabricate(:backup, user: member, processed: true,
                           dump: attachment_fixture('elite-assets.tar.gz'))
      end

      it 'answers ready with size and fetch path', :aggregate_failures do
        subject

        expect(response.parsed_body).to include(
          'state' => 'ready',
          'path' => "/api/v1/admin/accounts/#{account.id}/backup/download"
        )
        expect(response.parsed_body['size']).to be_positive
      end
    end

    context 'when the account is remote' do
      let(:account) { Fabricate(:account, domain: 'example.org') }

      it 'answers 404' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/admin/accounts/:id/backup' do
    subject { post "/api/v1/admin/accounts/#{account.id}/backup", headers: headers }

    it_behaves_like 'forbidden for wrong scope', 'read read:accounts admin:read admin:read:accounts'
    it_behaves_like 'forbidden for wrong role', ''

    it 'creates a backup and enqueues the worker with admin_requested', :aggregate_failures do
      expect { subject }.to change { member.backups.count }.by(1)

      expect(response).to have_http_status(202)
      expect(response.parsed_body).to eq('state' => 'pending')
      expect(BackupWorker).to have_enqueued_sidekiq_job(member.backups.last.id, { 'admin_requested' => true })
    end

    context 'when a backup was created in the last 24 hours' do
      before { Fabricate(:backup, user: member, created_at: 2.hours.ago) }

      it 'answers 429 and creates nothing', :aggregate_failures do
        expect { subject }.to_not(change { member.backups.count })

        expect(response).to have_http_status(429)
      end
    end

    context 'when the latest backup is older than 24 hours' do
      before { Fabricate(:backup, user: member, created_at: 25.hours.ago) }

      it 'creates a new one' do
        subject

        expect(response).to have_http_status(202)
      end
    end
  end

  describe 'GET /api/v1/admin/accounts/:id/backup/download' do
    subject { get "/api/v1/admin/accounts/#{account.id}/backup/download", headers: headers }

    it_behaves_like 'forbidden for wrong scope', 'read read:accounts admin:write admin:write:accounts'

    it 'answers 404 without a ready backup' do
      subject

      expect(response).to have_http_status(404)
    end

    context 'with a processed backup' do
      before do
        Fabricate(:backup, user: member, processed: true,
                           dump: attachment_fixture('elite-assets.tar.gz'))
      end

      it 'streams the dump', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(response.headers['Content-Disposition']).to start_with('attachment')
        expect(response.body.bytesize).to eq(member.backups.last.dump_file_size)
      end
    end
  end
end
