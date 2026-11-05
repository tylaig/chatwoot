# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Tasks', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:task_service) { instance_double(Captain::LabelSuggestionService, perform: { message: 'reembolso' }) }

  before do
    allow(Captain::LabelSuggestionService).to receive(:new).and_return(task_service)
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/tasks/label_suggestion' do
    context 'when label suggestion is disabled in both captain_features and openai hook' do
      it 'returns 200 with nil message without calling the service' do
        post "/api/v1/accounts/#{account.id}/captain/tasks/label_suggestion",
             params: { conversation_display_id: conversation.display_id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('message' => nil)
        expect(Captain::LabelSuggestionService).not_to have_received(:new)
      end
    end

    context 'when label_suggestion is enabled via captain_features' do
      before do
        account.update!(captain_features: { 'label_suggestion' => true })
      end

      it 'executes Captain::LabelSuggestionService and returns the suggestion' do
        post "/api/v1/accounts/#{account.id}/captain/tasks/label_suggestion",
             params: { conversation_display_id: conversation.display_id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('message' => 'reembolso')
        expect(Captain::LabelSuggestionService).to have_received(:new).with(
          account: account,
          conversation_display_id: conversation.display_id.to_s
        )
      end
    end

    context 'when label_suggestion is enabled via active OpenAI integration hook settings' do
      before do
        create(:integrations_hook, account: account, app_id: 'openai', status: :enabled, settings: {
                 'api_key' => 'sk-test',
                 'label_suggestion' => true
               })
      end

      it 'executes Captain::LabelSuggestionService and returns the suggestion' do
        post "/api/v1/accounts/#{account.id}/captain/tasks/label_suggestion",
             params: { conversation_display_id: conversation.display_id },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('message' => 'reembolso')
      end
    end
  end
end
