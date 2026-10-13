# frozen_string_literal: true

class Api::V1::Accounts::EvolutionInstancesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :client
  before_action :validate_name, only: [:destroy, :connect, :connection_state, :logout, :restart, :webhook, :update_webhook]

  def index
    render json: { instances: @client.instances }
  rescue Evolution::Client::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    name = params[:name].to_s.strip
    unless name.match?(/\A[a-zA-Z0-9_-]+\z/)
      return render json: { error: 'O nome da instância usa letras, números, _ ou -.' }, status: :unprocessable_entity
    end

    payload = @client.create_instance(name: name, number: params[:number].to_s.strip)
    render json: { instance: payload }, status: :created
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
    return if params[:name].to_s.match?(/\A[a-zA-Z0-9_-]+\z/)

    render json: { error: 'Nome de instância inválido.' }, status: :unprocessable_entity
  end
end
