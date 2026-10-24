module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    plan = ChatwootHub.pricing_plan.to_s.presence || 'enterprise'
    quantity = ChatwootHub.pricing_plan_quantity

    if quantity.present? && quantity.to_i.positive?
      "Instância operando na edição <span class='font-semibold text-emerald-400'>#{plan.capitalize}</span> com <span class='font-semibold text-emerald-400'>#{quantity} licenças ativas</span>."
    else
      "Instância operando na edição <span class='font-semibold text-emerald-400'>#{plan.capitalize}</span>."
    end
  end
end
