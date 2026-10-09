# frozen_string_literal: true

class Api::V1::Accounts::WebhookDispatchTriggersController < Api::V1::Accounts::BaseController
  before_action :fetch_trigger, only: [:show, :update, :destroy, :test_payload]

  def index
    @triggers = Current.account.webhook_dispatch_triggers.order(created_at: :desc)
    render json: @triggers
  end

  def show
    render json: @trigger
  end

  def create
    @trigger = Current.account.webhook_dispatch_triggers.new(trigger_params)

    if @trigger.save
      render json: @trigger, status: :created
    else
      render json: { error: @trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @trigger.update(trigger_params)
      render json: @trigger
    else
      render json: { error: @trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @trigger.destroy!
    head :no_content
  end

  # Dry-run test endpoint: tests the JSON mapping against a payload without sending real WhatsApp message
  def test_payload
    payload = params[:payload].presence || {}

    phone = @trigger.extract_by_path(payload, @trigger.field_mapping['phone_path'])
    name = @trigger.extract_by_path(payload, @trigger.field_mapping['name_path'])
    
    mapping_params = @trigger.field_mapping['parameters'] || []
    resolved_params = mapping_params.map do |param|
      if param['type'] == 'static'
        param['value']
      else
        @trigger.extract_by_path(payload, param['value'])
      end
    end

    render json: {
      phone: phone,
      name: name,
      template_name: @trigger.template_name,
      resolved_parameters: resolved_params,
      valid: phone.present?
    }
  end

  private

  def fetch_trigger
    @trigger = Current.account.webhook_dispatch_triggers.find(params[:id])
  end

  def trigger_params
    params.require(:webhook_dispatch_trigger).permit(
      :inbox_id,
      :name,
      :active,
      :template_name,
      :template_language,
      field_mapping: {},
      sample_payload: {}
    )
  end
end
