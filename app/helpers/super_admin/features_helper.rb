module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    if defined?(EliteLicenseEngine)
      info = EliteLicenseEngine.status_summary
      return "Instância operando no motor <span class='font-semibold text-emerald-400'>#{info[:tier_name]}</span> " \
             "(<span class='font-mono text-xs text-emerald-300'>#{info[:license_key]}</span>) com " \
             "<span class='font-semibold text-emerald-400'>#{info[:max_agents]} assentos</span> e " \
             "<span class='font-semibold text-emerald-400'>#{info[:whitelabel_enabled] ? 'White-Label Ativo' : 'SaaS Multi-Tenant'}</span>."
    end

    plan = ChatwootHub.pricing_plan.to_s.presence || 'enterprise'
    quantity = ChatwootHub.pricing_plan_quantity

    if quantity.present? && quantity.to_i.positive?
      "Instância operando na edição <span class='font-semibold text-emerald-400'>#{plan.capitalize}</span> com <span class='font-semibold text-emerald-400'>#{quantity} licenças ativas</span>."
    else
      "Instância operando na edição <span class='font-semibold text-emerald-400'>#{plan.capitalize}</span>."
    end
  end
end
