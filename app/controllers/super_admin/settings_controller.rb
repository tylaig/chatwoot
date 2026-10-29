class SuperAdmin::SettingsController < SuperAdmin::ApplicationController
  def show; end

  def refresh
    Internal::CheckNewVersionsJob.perform_now
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to super_admin_settings_path, notice: 'Status da instância e licença Elite Label sincronizados com sucesso!'
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def update_license
    mode = params[:license_mode].to_s.presence || 'generate'
    summary = if mode == 'validate' && params[:license_key].present?
                EliteLicenseEngine.activate_with_key!(
                  license_key: params[:license_key],
                  holder: params[:holder],
                  tier: params[:tier].presence,
                  seats: params[:seats].presence,
                  expires_at: params[:expires_at].presence,
                  sync_all_accounts: params[:sync_all_accounts]
                )
              else
                EliteLicenseEngine.update_instance_license!(
                  tier: params[:tier],
                  holder: params[:holder],
                  seats: params[:seats],
                  expires_at: params[:expires_at],
                  sync_all_accounts: params[:sync_all_accounts]
                )
              end

    respond_to do |format|
      format.json { render json: { ok: true, summary: summary, message: "Licença #{summary[:tier_name]} (#{summary[:license_key]}) ativada!" } }
      format.html do
        redirect_to super_admin_settings_path,
                    notice: "Licença #{summary[:tier_name]} (#{summary[:license_key]}) emitida e ativada com sucesso!"
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to super_admin_settings_path, alert: "Erro na licença: #{e.message}" }
    end
  end

  def verify_license
    result = EliteLicenseEngine.inspect_license_key(
      params[:license_key],
      tier: params[:tier].presence,
      holder: params[:holder].presence,
      seats: params[:seats].presence,
      expires_at: params[:expires_at].presence
    )

    if ActiveModel::Type::Boolean.new.cast(params[:activate]) && result[:valid]
      summary = EliteLicenseEngine.activate_with_key!(
        license_key: params[:license_key],
        holder: params[:holder].presence || result[:holder],
        sync_all_accounts: params[:sync_all_accounts]
      )
      result[:activated] = true
      result[:summary] = summary
    end

    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:valid]
          redirect_to super_admin_settings_path, notice: "Chave HMAC válida (#{result[:tier_key].to_s.upcase} · #{result[:seats]} seats): #{result[:reason]}"
        else
          redirect_to super_admin_settings_path, alert: "Falha na verificação HMAC: #{result[:reason]}"
        end
      end
    end
  end

  def update_branding
    branding_payload = params.fetch(:branding, params).permit(
      :preset,
      :apply_sidebar,
      :explicit_override,
      :INSTALLATION_NAME,
      :BRAND_NAME,
      :BRAND_COLOR,
      :BRAND_URL,
      :WIDGET_BRAND_URL,
      :LOGO,
      :LOGO_DARK,
      :LOGO_THUMBNAIL,
      :LOGO_EMAIL,
      :TERMS_URL,
      :PRIVACY_URL,
      :DISPLAY_MANIFEST,
      sidebar_items: []
    ).to_h

    branding_payload[:explicit_override] = true
    cfg = EliteLicenseEngine.apply_whitelabel_branding!(
      branding_payload,
      apply_sidebar: branding_payload[:apply_sidebar],
      account_id: params[:account_id]
    )

    respond_to do |format|
      format.json { render json: { ok: true, whitelabel: cfg, message: "Identidade White-Label '#{cfg['INSTALLATION_NAME']}' aplicada com sucesso!" } }
      format.html do
        redirect_to super_admin_settings_path,
                    notice: "Identidade White-Label '#{cfg['INSTALLATION_NAME']}' (#{cfg['BRAND_COLOR']}) salva e sincronizada globalmente!"
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to super_admin_settings_path, alert: "Erro ao atualizar branding White-Label: #{e.message}" }
    end
  end

  def apply_preset
    preset_key = params[:preset].to_s.strip.downcase
    apply_sidebar = params.key?(:apply_sidebar) ? ActiveModel::Type::Boolean.new.cast(params[:apply_sidebar]) : true
    cfg = EliteLicenseEngine.apply_whitelabel_branding!(preset_key, apply_sidebar: apply_sidebar, account_id: params[:account_id])

    respond_to do |format|
      format.json { render json: { ok: true, whitelabel: cfg } }
      format.html do
        redirect_to super_admin_settings_path,
                    notice: "Preset White-Label '#{cfg['INSTALLATION_NAME']}' aplicado com sucesso!"
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to super_admin_settings_path, alert: "Erro ao aplicar preset: #{e.message}" }
    end
  end

  def apply_account_tier
    account = Account.find(params[:account_id])
    custom_limits = {
      agents: params[:agents].presence,
      inboxes: params[:inboxes].presence,
      captain_responses: params[:captain_responses].presence,
      captain_documents: params[:captain_documents].presence
    }.compact

    sync_sidebar = params.key?(:sync_sidebar) ? ActiveModel::Type::Boolean.new.cast(params[:sync_sidebar]) : true
    tier = EliteLicenseEngine.apply_tier_to_account!(
      account,
      params[:tier],
      custom_limits: custom_limits,
      sync_sidebar: sync_sidebar
    )

    respond_to do |format|
      format.json { render json: { ok: true, account_id: account.id, tier: tier[:key] } }
      format.html do
        redirect_to super_admin_settings_path,
                    notice: "Plano #{tier[:name]} e cotas aplicados na conta '#{account.name}' (#{account.id}) com sucesso!"
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to super_admin_settings_path, alert: "Erro ao aplicar plano na conta: #{e.message}" }
    end
  end
end
