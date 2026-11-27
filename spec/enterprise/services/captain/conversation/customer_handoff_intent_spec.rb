require 'rails_helper'

RSpec.describe Captain::Conversation::CustomerHandoffIntent do
  describe '.detected?' do
    it 'matches explicit human / refund / Procon requests' do
      expect(described_class.detected?('quero falar com um atendente')).to be(true)
      expect(described_class.detected?('preciso solicitar reembolso')).to be(true)
      expect(described_class.detected?('vou no Procon')).to be(true)
    end

    it 'ignores ordinary troubleshooting messages' do
      expect(described_class.detected?('Pronto')).to be(false)
      expect(described_class.detected?('o código não chegou')).to be(false)
      expect(described_class.detected?('como faço o login?')).to be(false)
    end
  end

  describe '.matching_message' do
    let(:conversation) { create(:conversation) }

    it 'returns the latest triggering customer message' do
      create(:message, conversation: conversation, message_type: :incoming, content: 'oi')
      match = create(:message, conversation: conversation, message_type: :incoming, content: 'quero reembolso agora')

      expect(described_class.matching_message(conversation)).to eq(match)
    end
  end
end
