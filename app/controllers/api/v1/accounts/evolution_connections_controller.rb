# frozen_string_literal: true

class Api::V1::Accounts::EvolutionConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: { connection: serialize(Current.account.evolution_connection) }
  end

  def update
    connection = Current.account.evolution_connection || Current.account.build_evolution_connection
    url = params[:base_url].presence || connection.base_url
    key = params[:api_key].presence || connection.api_key
    outcome = run_precheck(url, key)
    unless outcome[:ok]
      return render json: { error: outcome[:error], checks: outcome[:checks] }, status: :unprocessable_entity
    end

    connection.update!(
      base_url: Evolution::Client.normalize_url(url),
      api_key: key,
      version: outcome[:version],
      client_name: outcome[:client_name],
      status: 'connected',
      instance_count: outcome[:instance_count],
      last_checked_at: Time.current,
      last_error: nil
    )
    render json: { connection: serialize(connection), checks: outcome[:checks] }
  rescue Evolution::Client::Error => e
    render json: { error: e.message, checks: [{ id: 'url', ok: false, label: 'URL', detail: e.message }] }, status: :unprocessable_entity
  end

  def check
    connection = Current.account.evolution_connection
    return render json: { error: 'Conecte a Evolution API antes de sincronizar.' }, status: :unprocessable_entity if connection.blank?

    previous = connection.version
    outcome = run_precheck(connection.base_url, connection.api_key)
    connection.update!(
      version: outcome[:version].presence || connection.version,
      client_name: outcome[:client_name].presence || connection.client_name,
      status: outcome[:ok] ? 'connected' : 'error',
      instance_count: outcome[:instance_count],
      last_checked_at: Time.current,
      last_error: outcome[:ok] ? nil : outcome[:error]
    )
    render json: {
      connection: serialize(connection),
      checks: outcome[:checks],
      previous_version: previous,
      version_changed: previous.present? && outcome[:version].present? && previous != outcome[:version]
    }, status: outcome[:ok] ? :ok : :unprocessable_entity
  end

  private

  def run_precheck(url, key)
    Evolution::Client.new(base_url: url, api_key: key).precheck
  end

  def serialize(connection)
    return { configured: false, status: 'disconnected' } if connection.blank?

    {
      configured: true,
      base_url: connection.base_url,
      api_key_set: connection.api_key.present?,
      api_key_last4: connection.api_key_last4,
      version: connection.version,
      client_name: connection.client_name,
      status: connection.status,
      instance_count: connection.instance_count,
      last_checked_at: connection.last_checked_at,
      last_error: connection.last_error
    }
  end
end
