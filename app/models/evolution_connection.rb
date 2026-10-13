# frozen_string_literal: true

class EvolutionConnection < ApplicationRecord
  belongs_to :account

  STATUSES = %w[disconnected connected error].freeze

  encrypts :api_key if Chatwoot.encryption_configured?

  validates :base_url, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :account_id, uniqueness: true

  def api_key_last4
    value = api_key.to_s
    return if value.blank?

    value[-4, 4]
  end
end
