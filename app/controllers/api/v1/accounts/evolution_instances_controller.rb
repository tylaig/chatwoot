# frozen_string_literal: true

class Api::V1::Accounts::EvolutionInstancesController < Api::V1::Accounts::BaseController
  # Evolution aceita nomes como "API OFICIAL"; só bloqueia vazio, barra e controle.
  INSTANCE_NAME = /\A[\p{L}\p{N}](?:[\p{L}\p{N} ._+\-]*[\p{L}\p{N}])?\z/

  before_action :check_admin_authorization?
  before_action :client
  before_action :validate_name, only: [:destroy, :connect, :connection_state, :logout, :restart, :webhook, :update_webhook,
                                       :connect_chatwoot]

  def index
    render json: { instances: @client.instances }
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    name = params[:name].to_s.strip
    unless acceptable_instance_name?(name)
      return render json: { error: 'O nome precisa começar e terminar com letra ou número.' },
                    status: :unprocessable_entity
    end

    payload = @client.create_instance(name: name, number: params[:number].to_s.strip)
    chatwoot_error = nil
    if ActiveModel::Type::Boolean.new.cast(params[:connect_chatwoot])
      begin
        link_chatwoot!(name)
      rescue Evolution::Client::Error => e
        chatwoot_error = e.message
      end
    end
    render json: { instance: payload, chatwoot_error: chatwoot_error }, status: :created
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @client.delete_instance(params[:name])
    head :no_content
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connect
    render json: @client.connect(params[:name])
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connection_state
    render json: @client.connection_state(params[:name])
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def logout
    @client.logout(params[:name])
    head :no_content
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def restart
    @client.restart(params[:name])
    head :no_content
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def webhook
    render json: { webhook: @client.find_webhook(params[:name]), events: Evolution::Client::EVENTS }
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connect_chatwoot
    link_chatwoot!(params[:name])
    render json: { ok: true, inbox_name: params[:name].to_s }
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_webhook
    url = params[:url].to_s.strip
    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
    events = Array(params[:events]).map(&:to_s) & Evolution::Client::EVENTS
    if enabled && url.blank?
      return render json: { error: 'Informe a URL que vai receber os eventos.' }, status: :unprocessable_entity
    end

    @client.set_webhook(params[:name], enabled: enabled, url: url, events: events)
    render json: { webhook: @client.find_webhook(params[:name]) }
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def client
    connection = Current.account.evolution_connection
    if connection.blank? || connection.status != 'connected' || connection.api_key.blank?
      render json: { error: 'Conecte a chave da Evolution API antes de gerenciar instâncias.' }, status: :unprocessable_entity
      return
    end

    @client = Evolution::Client.new(base_url: connection.base_url, api_key: connection.api_key)
  end

  def validate_name
    return if acceptable_instance_name?(params[:name])

    render json: { error: 'Nome de instância inválido.' }, status: :unprocessable_entity
  end

  def acceptable_instance_name?(name)
    value = name.to_s
    value.length <= 100 && value.match?(INSTANCE_NAME)
  end

  def link_chatwoot!(name)
    token = Current.user.access_token&.token.to_s
    if token.blank?
      raise Evolution::Client::Error, 'Sua conta não tem um token de acesso para criar a caixa.'
    end

    @client.set_chatwoot(
      name,
      account_id: Current.account.id,
      token: token,
      url: public_chatwoot_url,
      inbox_name: name,
      import_messages: ActiveModel::Type::Boolean.new.cast(params[:import_messages]),
      organization: Current.account.name
    )
  end

  def public_chatwoot_url
    raw = ENV.fetch('FRONTEND_URL', '').to_s.strip.chomp('/')
    uri = URI.parse(raw)
    host = uri.host.to_s
    local = host.blank? || %w[localhost 127.0.0.1].include?(host)
    unless uri.is_a?(URI::HTTP) && !local
      raise Evolution::Client::Error,
            'A Evolution precisa da URL pública do Chatwoot. Ajuste FRONTEND_URL para o endereço real da instalação.'
    end

    raw
  rescue URI::InvalidURIError
    raise Evolution::Client::Error, 'FRONTEND_URL do Chatwoot é inválida.'
  end
end
