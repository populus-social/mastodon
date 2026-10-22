# frozen_string_literal: true

# populus.social data download (#1984): account-service requests and fetches a
# member's own archive (BackupService) without the member signing in to
# Mastodon, which refuses them once they are in Sunset (#1945).
class Api::V1::Admin::AccountBackupsController < Api::BaseController
  include Authorization

  RATE_LIMIT_WINDOW = 24.hours

  before_action -> { authorize_if_got_token! :'admin:read', :'admin:read:accounts' }, only: [:show, :download]
  before_action -> { authorize_if_got_token! :'admin:write', :'admin:write:accounts' }, only: :create
  before_action :set_account
  before_action :require_local_account!

  after_action :verify_authorized

  # 200 always, so a 404 only ever means "this image has no such route".
  # `none` covers no backup, a vacuumed one and a failed one: both of the
  # latter delete the row.
  def show
    authorize @account, :show?
    backup = latest_backup

    render json: backup_state(backup)
  end

  def create
    authorize @account, :show?

    user = @account.user

    if user.backups.exists?(created_at: RATE_LIMIT_WINDOW.ago..)
      render json: { error: 'A backup was created in the last 24 hours' }, status: 429
      return
    end

    backup = user.backups.create!
    # The option rides in the job payload, so it survives every Sidekiq retry.
    BackupWorker.perform_async(backup.id, 'admin_requested' => true)

    render json: backup_state(backup), status: 202
  end

  def download
    authorize @account, :show?
    backup = latest_backup

    return render json: { error: 'No backup ready' }, status: 404 unless ready?(backup)

    send_file backup.dump.path,
              type: backup.dump_content_type || 'application/zip',
              filename: backup.dump_file_name,
              disposition: 'attachment'
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def require_local_account!
    raise ActiveRecord::RecordNotFound unless @account.local? && @account.user.present?
  end

  def latest_backup
    @account.user.backups.order(id: :desc).first
  end

  def ready?(backup)
    backup.present? && backup.processed? && backup.dump.present?
  end

  def backup_state(backup)
    return { state: 'none' } if backup.nil?
    return { state: 'pending' } unless ready?(backup)

    {
      state: 'ready',
      size: backup.dump_file_size,
      path: "/api/v1/admin/accounts/#{@account.id}/backup/download",
      created_at: backup.created_at.iso8601,
    }
  end
end
