# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Populus::StorageAllowance do
  let(:url) { 'http://account-service.test:8081/internal/storage-allowance' }

  before do
    Rails.cache.clear
    stub_const('ENV', ENV.to_hash.merge('POPULUS_STORAGE_ALLOWANCE_URL' => url, 'POPULUS_STORAGE_ALLOWANCE_KEY' => 'k'))
  end

  def stub_lookup(body: nil, status: 200)
    stub_request(:get, url).with(query: { service: 'feed', pseudonym: 'alice' }, headers: { 'Authorization' => 'Bearer k' })
                           .to_return(status: status, body: body)
  end

  describe '.over?' do
    it 'is true when the contract says over' do
      stub_lookup(body: '{"over":true,"remaining_bytes":0}')
      expect(described_class.over?('Alice')).to be true
    end

    it 'is false when the contract says under' do
      stub_lookup(body: '{"over":false,"remaining_bytes":10}')
      expect(described_class.over?('alice')).to be false
    end

    it 'fails open on null figures, a missing key, errors and timeouts' do
      stub_lookup(body: '{"over":null}')
      expect(described_class.over?('alice')).to be false
      Rails.cache.clear
      stub_lookup(body: '{}')
      expect(described_class.over?('alice')).to be false
      Rails.cache.clear
      stub_lookup(status: 401, body: '')
      expect(described_class.over?('alice')).to be false
      Rails.cache.clear
      stub_request(:get, url).with(query: hash_including({})).to_timeout
      expect(described_class.over?('alice')).to be false
    end

    it 'is false without a lookup when the switch is off' do
      stub_const('ENV', ENV.to_hash.except('POPULUS_STORAGE_ALLOWANCE_URL'))
      expect(described_class.over?('alice')).to be false
    end
  end
end
