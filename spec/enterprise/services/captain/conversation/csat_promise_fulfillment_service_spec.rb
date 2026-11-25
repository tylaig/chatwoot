require 'rails_helper'

RSpec.describe Captain::Conversation::CsatPromiseFulfillmentService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, csat_survey_enabled: true) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }

  describe '#perform' do
    it 'sends CSAT when the assistant promised stars below' do
      result = described_class.new(
        conversation: conversation,
        content: 'Por nada! Se puder, avalie o atendimento nas estrelinhas logo abaixo.'
      ).perform

      expect(result).to eq(:sent)
      expect(conversation.messages.where(content_type: :input_csat)).to exist
    end

    it 'skips when the message does not promise a rating' do
      result = described_class.new(
        conversation: conversation,
        content: 'O GTA 6 só roda no Xbox Series X|S.'
      ).perform

      expect(result).to eq(:skipped)
      expect(conversation.messages.where(content_type: :input_csat)).not_to exist
    end

    it 'skips when CSAT was already sent' do
      create(:message, conversation: conversation, content_type: :input_csat, content: 'Rate us')

      result = described_class.new(
        conversation: conversation,
        content: 'Avalie nas estrelinhas logo abaixo!'
      ).perform

      expect(result).to eq(:already_sent)
      expect(conversation.messages.where(content_type: :input_csat).count).to eq(1)
    end

    it 'skips when the inbox has CSAT disabled' do
      inbox.update!(csat_survey_enabled: false)

      result = described_class.new(
        conversation: conversation,
        content: 'Avalie nas estrelinhas logo abaixo!'
      ).perform

      expect(result).to eq(:skipped)
    end
  end
end
