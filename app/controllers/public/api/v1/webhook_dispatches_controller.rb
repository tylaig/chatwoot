# frozen_string_literal: true

class Public::Api::V1::WebhookDispatchesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user, raise: false
  skip_before_action :check_subscription, raise: false
  skip_before_action :verify_authenticity_token, raise: false
  wrap_parameters false

  def trigger
    trigger = WebhookDispatchTrigger.active.find_by(token: params[:token])

    unless trigger
      return render json: { error: 'Invalid or inactive webhook token' }, status: :not_found
    end

    payload = request.request_parameters.presence || request.query_parameters.presence || {}

    # Support raw JSON string body
    if payload.blank? && request.raw_post.present?
      begin
        payload = JSON.parse(request.raw_post)
      rescue JSON::ParserError
        return render json: { error: 'Invalid JSON payload' }, status: :unprocessable_entity
      end
    end

    payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
    return render json: { error: 'Payload must be a JSON object' }, status: :unprocessable_entity unless payload.is_a?(Hash)

    trigger.update_columns(sample_payload: payload, sample_received_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    workflow = trigger.workflow
    if workflow.present? && !(workflow.status == 'active' && workflow.active_version.present?)
      return render json: { status: 'captured', message: 'Payload capturado. Publique e ative o workflow para executá-lo.' }, status: :accepted
    end

    result = trigger.execute_payload(payload)

    if result[:success]
      render json: {
        status: 'queued',
        conversation_id: result[:conversation_id],
        contact_id: result[:contact_id],
        message_id: result[:message_id]
      }, status: :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
