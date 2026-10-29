# == Schema Information
#
# Table name: channel_facebook_pages
#
#  id                :integer          not null, primary key
#  page_access_token :string           not null
#  user_access_token :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  instagram_id      :string
#  page_id           :string           not null
#
# Indexes
#
#  index_channel_facebook_pages_on_page_id                 (page_id)
#  index_channel_facebook_pages_on_page_id_and_account_id  (page_id,account_id) UNIQUE
#

class Channel::FacebookPage < ApplicationRecord
  include Channelable
  include Reauthorizable

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  if Chatwoot.encryption_configured?
    encrypts :page_access_token
    encrypts :user_access_token
  end

  self.table_name = 'channel_facebook_pages'

  validates :page_id, uniqueness: true, presence: true
  validates :instagram_id, uniqueness: true, allow_nil: true, allow_blank: true
  validate :ensure_instagram_id_not_taken_by_direct_channel

  after_create_commit :subscribe
  before_destroy :unsubscribe

  def name
    'Facebook'
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    # ref https://developers.facebook.com/docs/messenger-platform/reference/webhook-events
    Facebook::Messenger::Subscriptions.subscribe(
      access_token: page_access_token,
      subscribed_fields: %w[
        messages message_deliveries message_echoes message_reads standby messaging_handovers messaging_postbacks
      ]
    )
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def unsubscribe
    Facebook::Messenger::Subscriptions.unsubscribe(access_token: page_access_token)
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  private

  def ensure_instagram_id_not_taken_by_direct_channel
    return if instagram_id.blank?
    return unless Channel::Instagram.where(instagram_id: instagram_id).where.not(account_id: account_id).exists?

    errors.add(:instagram_id, 'já está vinculado a outra conta no sistema via Login Direto do Instagram')
  end
end
