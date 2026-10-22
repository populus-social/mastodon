# frozen_string_literal: true

class BackupWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', backtrace: true, retry: 5, dead: false

  sidekiq_retries_exhausted do |msg|
    backup_id = msg['args'].first

    ActiveRecord::Base.connection_pool.with_connection do
      backup = Backup.find(backup_id)
      backup.destroy
    rescue ActiveRecord::RecordNotFound
      true
    end
  end

  def perform(backup_id, options = {})
    backup = Backup.find_by(id: backup_id)
    return true if backup&.user.nil?

    user = backup.user

    BackupService.new.call(backup)

    user.backups.where.not(id: backup.id).destroy_all
    # Admin-requested backups (#1984) reach the member through the portal.
    UserMailer.backup_ready(user, backup).deliver_later unless options['admin_requested']
  end
end
