require 'rails_helper'

RSpec.describe Captain::Conversation::HumanHandoffLock do
  let(:conversation) { create(:conversation) }

  describe '.lock! / .locked? / .clear!' do
    it 'sets, reads and clears the sticky handoff lock' do
      expect(described_class.locked?(conversation)).to be(false)

      described_class.lock!(conversation, reason: 'customer asked for human', category: 'customer_request')

      conversation.reload
      expect(described_class.locked?(conversation)).to be(true)
      expect(conversation.additional_attributes[described_class::LOCK_KEY]).to be_present
      expect(conversation.additional_attributes[described_class::REASON_KEY]).to eq('customer asked for human')
      expect(conversation.additional_attributes[described_class::CATEGORY_KEY]).to eq('customer_request')

      described_class.clear!(conversation)

      conversation.reload
      expect(described_class.locked?(conversation)).to be(false)
      expect(conversation.additional_attributes).not_to have_key(described_class::LOCK_KEY)
    end
  end
end
