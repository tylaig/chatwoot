# frozen_string_literal: true

class Webhooks::AsaasController < ActionController::API
  before_action :verify_webhook_token!

  def process_payload
    payload = parsed_payload
    return head :bad_request if payload.blank?

    result = ::Billing::HandleAsaasEventService.new(payload: payload).perform
    render json: result, status: :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def parsed_payload
    raw = request.body.read
    request.body.rewind if request.body.respond_to?(:rewind)
    return params.to_unsafe_h if raw.blank? && params.present?

    JSON.parse(raw)
  end

  def verify_webhook_token!
    expected = configured_webhook_token
    return if expected.blank?

    provided = request.headers['asaas-access-token'].presence ||
               request.headers['X-Asaas-Access-Token'].presence ||
               params[:access_token].presence
    return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected.to_s)

    head :unauthorized
  end

  def configured_webhook_token
    ENV['ASAAS_WEBHOOK_TOKEN'].presence ||
      GlobalConfigService.load('ASAAS_WEBHOOK_TOKEN', nil).presence
  end
end
