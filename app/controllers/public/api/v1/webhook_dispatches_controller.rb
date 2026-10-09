# frozen_string_literal: true

class Public::Api::V1::WebhookDispatchesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user, raise: false
  skip_before_action :check_subscription, raise: false
  skip_before_action :verify_authenticity_token, raise: false

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
