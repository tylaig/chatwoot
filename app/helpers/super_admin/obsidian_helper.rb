# Meu Super Chat — Super Admin "Obsidian v2" presentation helpers.
# Centralises PT-BR labels and rich cell rendering for the Administrate views.
module SuperAdmin::ObsidianHelper
  MSC_RESOURCE_LABELS = {
    'accounts' => %w[Contas Conta],
    'users' => %w[Usuários Usuário],
    'access_tokens' => ['Tokens de acesso', 'Token de acesso'],
    'installation_configs' => ['Configurações da instalação', 'Configuração da instalação'],
    'agent_bots' => ['Agent Bots', 'Agent Bot'],
    'platform_apps' => ['Apps da Plataforma', 'App da Plataforma'],
    'account_users' => ['Membros da conta', 'Membro da conta'],
    'platform_banners' => ['Banners da Plataforma', 'Banner da Plataforma']
  }.freeze

  MSC_NEW_LABELS = {
    'accounts' => 'Nova conta', 'users' => 'Novo usuário', 'agent_bots' => 'Novo Agent Bot',
    'platform_apps' => 'Novo app', 'installation_configs' => 'Nova configuração', 'account_users' => 'Novo membro'
  }.freeze

  MSC_COLUMN_LABELS = {
    'id' => 'ID', 'name' => 'Nome', 'locale' => 'Idioma', 'users' => 'Usuários', 'conversations' => 'Conversas',
    'status' => 'Status', 'avatar_url' => 'Avatar', 'email' => 'E-mail', 'accounts' => 'Contas', 'type' => 'Perfil',
    'owner' => 'Proprietário', 'token' => 'Token', 'created_at' => 'Criado em', 'updated_at' => 'Atualizado em',
    'value' => 'Valor', 'account' => 'Conta', 'outgoing_url' => 'URL de saída', 'user' => 'Usuário',
    'inviter' => 'Convidado por', 'role' => 'Função', 'description' => 'Descrição', 'display_name' => 'Nome de exibição',
    'domain' => 'Domínio', 'support_email' => 'E-mail de suporte', 'features' => 'Recursos', 'limits' => 'Limites',
    'custom_attributes' => 'Atributos personalizados', 'password' => 'Senha', 'confirmed_at' => 'Confirmado em',
    'sign_in_count' => 'Total de logins', 'current_sign_in_at' => 'Login atual', 'last_sign_in_at' => 'Último login',
    'current_sign_in_ip' => 'IP atual', 'last_sign_in_ip' => 'Último IP', 'access_token' => 'Token de acesso',
    'account_users' => 'Membros', 'avatar' => 'Avatar', 'provider' => 'Provedor', 'uid' => 'UID',
    'unconfirmed_email' => 'E-mail não confirmado', 'all_features' => 'Recursos', 'manually_managed_features' => 'Recursos gerenciados',
    'suspension_history' => 'Histórico de suspensão', 'locked' => 'Bloqueado', 'serialized_value' => 'Valor',
    'pubsub_token' => 'Token PubSub', 'tokens' => 'Tokens'
  }.freeze

  MSC_FILTER_LABELS = {
    'active' => 'Ativas', 'suspended' => 'Suspensas', 'recent' => 'Criadas nos últimos 30 dias',
    'marked_for_deletion' => 'Marcadas para exclusão', 'user' => 'Usuários', 'agent_bot' => 'Agent Bots',
    'platform_app' => 'Apps da Plataforma', 'super_admin' => 'Super Admins', 'confirmed' => 'Confirmados',
    'unconfirmed' => 'Não confirmados'
  }.freeze

  MSC_STATUS = {
    'active' => ['Ativa', 'ok'], 'suspended' => ['Suspensa', 'err'], 'administrator' => ['Administrador', 'ok'],
    'agent' => ['Agente', 'off'], 'superadmin' => ['Super Admin', 'volt']
  }.freeze

  def msc_resource_label(resource_name, singular: false)
    key = resource_name.to_s.pluralize
    pair = MSC_RESOURCE_LABELS[key]
    return (singular ? pair.last : pair.first) if pair

    display_resource_name(resource_name)
  rescue StandardError
    resource_name.to_s.humanize
  end

  def msc_new_label(resource_name)
    MSC_NEW_LABELS[resource_name.to_s.pluralize] || "Novo #{msc_resource_label(resource_name, singular: true).downcase}"
  end

  def msc_column_label(resource_name, attr_name)
    MSC_COLUMN_LABELS[attr_name.to_s] ||
      t("helpers.label.#{resource_name}.#{attr_name}", default: attr_name.to_s.humanize)
  end

  def msc_filter_label(filter_name)
    MSC_FILTER_LABELS[filter_name.to_s] || filter_name.to_s.humanize
  end

  # avatar_url is merged into the "Nome" cell (avatar + name) to avoid a duplicated column.
  def msc_skip_column?(attr_name)
    attr_name.to_s == 'avatar_url'
  end

  def msc_avatar_for(resource, name)
    url = resource.try(:avatar_url).presence
    if url
      image_tag(url, class: 'msc-avatar msc-avatar--img', alt: '', loading: 'lazy')
    else
      content_tag(:span, msc_initials(name), class: 'msc-avatar msc-avatar--initials', 'aria-hidden': true)
    end
  rescue StandardError
    content_tag(:span, msc_initials(name), class: 'msc-avatar msc-avatar--initials', 'aria-hidden': true)
  end

  def msc_initials(text)
    words = text.to_s.gsub(/[^[:alnum:][:space:]]/, ' ').split
    return '?' if words.empty?

    (words.size > 1 ? "#{words.first[0]}#{words.last[0]}" : words.first[0, 2]).upcase
  end

  # Returns rich markup for well-known columns, or nil to fall back to Administrate's field partial.
  def msc_rich_cell(attribute, resource)
    value = attribute.data
    case attribute.name.to_s
    when 'id'
      content_tag(:span, "##{value}", class: 'msc-cell-id')
    when 'name'
      return nil if value.blank?

      content_tag(:span, class: 'msc-cell-name') do
        msc_avatar_for(resource, value) + content_tag(:span, value, class: 'msc-cell-name__text')
      end
    when 'locale'
      value.present? ? content_tag(:span, value, class: 'msc-pill') : nil
    when 'status', 'role'
      key = value.to_s.downcase
      label, tone = MSC_STATUS[key] || [value.to_s.humanize, 'off']
      content_tag(:span, class: "msc-badge msc-badge--#{tone}") { content_tag(:i, '', class: 'msc-dot') + label }
    when 'type'
      return content_tag(:span, 'Agente', class: 'msc-badge msc-badge--off') if value.blank? && resource.is_a?(User)

      key = value.to_s.downcase
      label, tone = MSC_STATUS[key] || [value.to_s, 'off']
      content_tag(:span, label, class: "msc-badge msc-badge--#{tone}")
    when 'created_at', 'updated_at'
      value.respond_to?(:strftime) ? content_tag(:span, l(value, format: '%d/%m/%Y %H:%M'), class: 'msc-cell-num') : nil
    when 'users', 'conversations', 'accounts'
      content_tag(:span, attribute.to_s, class: 'msc-cell-num')
    end
  rescue StandardError
    nil
  end
end
