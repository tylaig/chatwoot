class SuperAdmin::SettingsController < SuperAdmin::ApplicationController
  def show; end

  def refresh
    Internal::CheckNewVersionsJob.perform_now
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to super_admin_settings_path, notice: 'Status da instância e licença Elite Label sincronizados com sucesso!'
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def update_license
    summary = EliteLicenseEngine.update_instance_license!(
      tier: params[:tier],
      holder: params[:holder],
      seats: params[:seats],
      sync_all_accounts: params[:sync_all_accounts]
    )
    redirect_to super_admin_settings_path,
                notice: "Licença #{summary[:tier_name]} (#{summary[:license_key]}) ativada com sucesso!"
  rescue StandardError => e
    redirect_to super_admin_settings_path, alert: "Erro ao atualizar licença: #{e.message}"
  end

  def apply_account_tier
    account = Account.find(params[:account_id])
    tier = EliteLicenseEngine.apply_tier_to_account!(account, params[:tier])
    redirect_to super_admin_settings_path,
                notice: "Plano #{tier[:name]} aplicado na conta '#{account.name}' (ID #{account.id}) com sucesso!"
  rescue StandardError => e
    redirect_to super_admin_settings_path, alert: "Erro ao aplicar plano na conta: #{e.message}"
  end
end
