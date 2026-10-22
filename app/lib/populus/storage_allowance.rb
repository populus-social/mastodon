# frozen_string_literal: true

require 'net/http'

# populus.social storage allowance (#1983): asks account-service whether a
# local member's principal account is over its combined storage allowance.
# The contract is GET /internal/storage-allowance?service=feed&pseudonym=<username>
# (#1981). Quota is a business limit, so every failure answers "not over":
# a missing figure must not stop a member's upload.
module Populus
  module StorageAllowance
    CACHE_TTL = 60.seconds
    TIMEOUT = 2
    ERROR_MESSAGE = 'Your storage allowance is used up. Delete media to upload more.'

    module_function

    def enabled?
      ENV['POPULUS_STORAGE_ALLOWANCE_URL'].present?
    end

    def over?(username)
      return false unless enabled? && username.present?

      key = username.to_s.downcase
      Rails.cache.fetch("populus:storage_allowance:#{key}", expires_in: CACHE_TTL) { lookup(key) }
    end

    def lookup(username)
      uri = URI.parse(ENV.fetch('POPULUS_STORAGE_ALLOWANCE_URL'))
      uri.query = URI.encode_www_form(service: 'feed', pseudonym: username)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV.fetch('POPULUS_STORAGE_ALLOWANCE_KEY', '')}"
      response = http.request(request)

      unless response.is_a?(Net::HTTPOK)
        Rails.logger.warn("storage allowance: failing open, status #{response.code}")
        return false
      end

      JSON.parse(response.body)['over'] == true
    rescue StandardError => e
      Rails.logger.warn("storage allowance: failing open, #{e.class}: #{e.message}")
      false
    end
  end
end
