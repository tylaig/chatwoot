# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::ExecutionEngineService, type: :service do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account, name: 'Samuel Teste', phone_number: '+5511999998888') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  let!(:workflow) do
    Workflow.create!(
      account: account,
      name: 'Lead Follow Up Test',
      trigger_type: 'webhook',
      status: 'active'
    )
  end

  let!(:workflow_version) do
    WorkflowVersion.create!(
      workflow: workflow,
      version_number: 1,
      status: 'published',
      nodes: [
        {
          'id' => 'trigger_1',
          'type' => 'webhook_trigger',
          'position' => { 'x' => 100, 'y' => 100 },
          'config' => { 'title' => 'Webhook Entry' }
        },
        {
          'id' => 'condition_1',
          'type' => 'condition',
          'position' => { 'x' => 100, 'y' => 200 },
          'config' => {
            'conditions' => [
              { 'field' => 'webhook.status', 'operator' => 'equal_to', 'value' => 'interested' }
            ]
          }
        },
        {
          'id' => 'tag_1',
          'type' => 'add_tag',
          'position' => { 'x' => 100, 'y' => 300 },
          'config' => { 'tag_name' => 'lead_quente' }
        }
      ],
      edges: [
        { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'condition_1' },
        { 'id' => 'e2', 'source' => 'condition_1', 'sourceHandle' => 'yes', 'target' => 'tag_1' }
      ]
    )
  end

  before do
    workflow.update!(active_version_id: workflow_version.id)
  end

  it 'executes workflow and takes the condition yes branch' do
    execution = WorkflowExecution.create!(
      account: account,
      workflow: workflow,
      workflow_version: workflow_version,
      contact: contact,
      conversation: conversation,
      inbox: inbox,
      trigger_type: 'webhook',
      status: 'running',
      started_at: Time.current,
      context: {
        'webhook' => { 'status' => 'interested' }
      }
    )

    described_class.new(execution).start!

    execution.reload
    expect(execution.status).to eq('completed')
    expect(execution.node_executions.count).to eq(3)
    expect(conversation.label_list).to include('lead_quente')
  end
end
