class SuperAdmin::InstanceStatusesController < SuperAdmin::ApplicationController
  def show
    @metrics = {}
    msc_version
    sha
    postgres_status
    redis_metrics
    msc_edition
    instance_meta
    baileys_api_version
    jev_engine_metrics
    @jev_status = Jev::DecisionService.status
    @update_info = SystemUpdateService.check_updates
  end

  def test_jev
    text = params[:text].to_s.strip
    preset = params[:preset].presence || 'msc_saas_triage'
    if text.blank?
      return render json: { ok: false, error: 'Informe um texto para avaliar.' }, status: :unprocessable_entity
    end

    result = if preset == 'captain_handoff_guard'
               Jev::DecisionService.check_captain_handoff_guard(text)
             else
               Jev::DecisionService.triage_message(text, preset: preset)
             end

    if result.present?
      render json: { ok: true, preset: preset, result: result }
    else
      render json: { ok: false, error: 'Falha ao consultar o motor Jev / Ollaya.' }, status: :bad_gateway
    end
  end

  def jev_engine_metrics
    st = Jev::DecisionService.status
    @metrics['Motor System 1 (Jev / Ollaya)'] = st[:online] ? 'true' : 'false'
    @metrics['Modelo Jev Ativo'] = st[:online] ? "#{st[:default_model]} (v#{st[:version]})" : 'Indisponível'
  rescue StandardError
    @metrics['Motor System 1 (Jev / Ollaya)'] = 'false'
  end

  def check_updates
    render json: SystemUpdateService.check_updates(
      force_refresh: ActiveModel::Type::Boolean.new.cast(params[:refresh])
    )
  end

  def apply_update
    result = SystemUpdateService.trigger_update!(
      user: current_super_admin,
      target_sha: params[:target_sha],
      force_window: params[:force_window]
    )
    render json: result, status: result[:ok] ? :ok : :unprocessable_entity
  end

  def msc_edition
    @metrics['Edição Meu Super Chat'] = if ChatwootApp.enterprise?
                                          'Enterprise'
                                        elsif ChatwootApp.custom?
                                          'Custom'
                                        else
                                          'Community'
                                        end
  end

  def instance_meta
    migrations_paths = ActiveRecord::Migrator.migrations_paths
    migrations_context = ActiveRecord::MigrationContext.new(migrations_paths)
    @metrics['Migrações do Banco de Dados'] = migrations_context.needs_migration? ? 'pendente' : 'concluídas'
  end

  def msc_version
    @metrics['Versão Meu Super Chat'] = Chatwoot.config[:version]
  end

  def sha
    @metrics['Git SHA'] = GIT_HASH
  end

  def postgres_status
    @metrics['PostgreSQL Ativo'] = ActiveRecord::Base.connection.active? ? 'true' : 'false'
  end

  def redis_metrics
    r = Redis.new(Redis::Config.app)
    if r.ping == 'PONG'
      redis_server = r.info
      @metrics['Redis Ativo'] = 'true'
      @metrics['Versão do Redis'] = redis_server['redis_version']
      @metrics['Clientes Redis Conectados'] = redis_server['connected_clients']
      @metrics["Limite 'maxclients' do Redis"] = redis_server['maxclients']
      @metrics['Memória Redis em Uso'] = redis_server['used_memory_human']
      @metrics['Pico de Memória Redis'] = redis_server['used_memory_peak_human']
      @metrics['Memória Total do Servidor'] = redis_server['total_system_memory_human']
      @metrics["Configuração 'maxmemory' do Redis"] = redis_server['maxmemory']
      @metrics["Política 'maxmemory_policy' do Redis"] = redis_server['maxmemory_policy']
    end
  rescue Redis::CannotConnectError
    @metrics['Redis Ativo'] = 'false'
  end

  def baileys_api_version
    @metrics['Versão Baileys API'] = Whatsapp::Providers::WhatsappBaileysService.status[:packageInfo][:version]
  rescue StandardError => e
    @metrics['Versão Baileys API'] = e.message.to_s.gsub(/Chatwoot/i, 'Meu Super Chat')
  end
end
