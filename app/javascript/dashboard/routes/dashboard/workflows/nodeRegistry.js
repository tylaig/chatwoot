export const NODE_CATEGORIES = [
  { id: 'all', name: 'Todos' },
  { id: 'triggers', name: 'Gatilhos' },
  { id: 'whatsapp', name: 'WhatsApp' },
  { id: 'messaging', name: 'Mensageria' },
  { id: 'logic', name: 'Lógica' },
  { id: 'time', name: 'Tempo' },
  { id: 'data', name: 'Dados' },
  { id: 'chatwoot', name: 'Chatwoot' },
  { id: 'integrations', name: 'Integrações' },
  { id: 'flow_control', name: 'Controle de Fluxo' },
];

export const WORKFLOW_NODES_REGISTRY = {
  // 1. WEBHOOK TRIGGER
  webhook_trigger: {
    type: 'webhook_trigger',
    title: 'Webhook Trigger',
    subtitle: 'Disparado por webhook externo',
    category: 'triggers',
    icon: '⚡',
    iconColor: '#FFB800',
    badge: 'Trigger',
    badgeType: 'trigger',
    isTrigger: true,
    hasInput: false,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Webhook Trigger',
      trigger_token: '',
      endpoint: '/public/api/v1/webhook_dispatches/default',
    },
    summarize: cfg => cfg.endpoint || 'webhook_trigger',
  },

  // 2. SEND MESSAGE
  send_message: {
    type: 'send_message',
    title: 'Enviar Mensagem',
    subtitle: 'Envia mensagem no canal ativo',
    category: 'messaging',
    icon: '💬',
    iconColor: '#3B82F6',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Enviar Mensagem',
      content: '',
      message_type: 'outgoing',
      private: false,
    },
    summarize: cfg =>
      cfg.content ? `"${cfg.content.slice(0, 32)}..."` : 'Sem mensagem',
  },

  // 3. SEND WHATSAPP MESSAGE
  send_whatsapp_message: {
    type: 'send_whatsapp_message',
    title: 'Enviar Mensagem WhatsApp',
    subtitle: 'Envia mensagem de texto livre ou template',
    category: 'whatsapp',
    icon: 'whatsapp', // renderiza SVG oficial
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Enviar Mensagem WhatsApp',
      inbox_id: '',
      delivery_mode: 'auto', // 'auto', 'inside_24h', 'outside_24h'
      text: 'Olá {{contact.first_name}}! Como posso te ajudar hoje?',
      template_name: '',
      template_language: 'pt_BR',
    },
    summarize: cfg => {
      if (cfg.delivery_mode === 'outside_24h') {
        return `Template: ${cfg.template_name || 'Não selecionado'}`;
      }
      return cfg.text ? `"${cfg.text.slice(0, 36)}..."` : 'Mensagem automática';
    },
  },

  // 4. SEND WHATSAPP TEMPLATE
  send_whatsapp_template: {
    type: 'send_whatsapp_template',
    title: 'Enviar Template WhatsApp',
    subtitle: 'Envia template aprovado da Meta',
    category: 'whatsapp',
    icon: 'whatsapp',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Enviar Template WhatsApp',
      inbox_id: '',
      template_name: '',
      template_category: 'MARKETING',
      template_language: 'pt_BR',
      status: 'APPROVED',
      variable_mapping: {
        '{{1}}': 'contact.name',
      },
    },
    summarize: cfg =>
      cfg.template_name
        ? `Template: ${cfg.template_name}\nIdioma: ${cfg.template_language || 'pt_BR'}`
        : 'Selecionar template...',
  },

  // 5. CONDITION (IF / ELSE)
  condition: {
    type: 'condition',
    title: 'Condição',
    subtitle: 'Cria um desvio baseado em regras',
    category: 'logic',
    icon: '🔀',
    iconColor: '#A855F7',
    badge: 'Condição',
    badgeType: 'condition',
    hasInput: true,
    outputs: [
      { id: 'true', label: 'TRUE', type: 'success' },
      { id: 'false', label: 'FALSE', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Condição',
      match_type: 'all', // 'all' (AND) ou 'any' (OR)
      conditions: [
        {
          field: 'webhook.status',
          operator: 'equal_to',
          value: 'interested',
        },
      ],
    },
    summarize: cfg => {
      if (!cfg.conditions || !cfg.conditions.length)
        return 'Configurar regras...';
      const first = cfg.conditions[0];
      const opText =
        first.operator === 'equal_to' ? 'é igual a' : first.operator;
      const andText =
        cfg.conditions.length > 1
          ? ` +${cfg.conditions.length - 1} regra(s)`
          : '';
      return `${first.field || 'campo'} ${opText} ${first.value || ''}${andText}`;
    },
  },

  // 6. ROUTER
  router: {
    type: 'router',
    title: 'Roteador',
    subtitle: 'Direciona o fluxo por múltiplas rotas',
    category: 'logic',
    icon: '🔀',
    iconColor: '#A855F7',
    badge: 'Roteador',
    badgeType: 'condition',
    hasInput: true,
    outputs: [
      { id: 'Instagram', label: 'Instagram', color: '#3B82F6' },
      { id: 'Google', label: 'Google', color: '#10B981' },
      { id: 'Referral', label: 'Referral', color: '#F59E0B' },
      { id: 'Default', label: 'Default', color: '#64748B' },
    ],
    defaultConfig: {
      custom_title: 'Origem do Lead',
      source_variable: 'webhook.source',
      routes: [
        {
          name: 'Instagram',
          operator: 'equal_to',
          value: 'instagram',
          color: '#3B82F6',
        },
        {
          name: 'Google',
          operator: 'equal_to',
          value: 'google',
          color: '#10B981',
        },
        {
          name: 'Referral',
          operator: 'equal_to',
          value: 'referral',
          color: '#F59E0B',
        },
      ],
      default_route_name: 'Default',
    },
    summarize: cfg => cfg.source_variable || 'webhook.source',
  },

  // 7. DELAY
  delay: {
    type: 'delay',
    title: 'Delay',
    subtitle: 'Aguarda por um período de tempo',
    category: 'time',
    icon: '⏱️',
    iconColor: '#F59E0B',
    badge: 'Tempo',
    badgeType: 'time',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Delay',
      duration: 10,
      unit: 'minutes', // seconds, minutes, hours, days
    },
    summarize: cfg => `${cfg.duration || 10} ${cfg.unit || 'minutos'}`,
  },

  // 8. WAIT UNTIL
  wait_until: {
    type: 'wait_until',
    title: 'Aguardar Até',
    subtitle: 'Pausa o fluxo até uma data ou horário',
    category: 'time',
    icon: '📅',
    iconColor: '#F59E0B',
    badge: 'Tempo',
    badgeType: 'time',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Aguardar Até',
      wait_mode: 'specific_time', // specific_time, business_hours, variable_date
      target_time: '09:00',
      timezone: 'America/Sao_Paulo',
    },
    summarize: cfg =>
      cfg.target_time ? `Até ${cfg.target_time}` : 'Aguardar horário',
  },

  // 9. WAIT FOR REPLY
  wait_for_reply: {
    type: 'wait_for_reply',
    title: 'Aguardar Resposta',
    subtitle: 'Espera o cliente responder',
    category: 'time',
    icon: '⏳',
    iconColor: '#6366F1',
    badge: 'Tempo',
    badgeType: 'time',
    hasInput: true,
    outputs: [
      { id: 'REPLIED', label: 'REPLIED', type: 'success' },
      { id: 'TIMEOUT', label: 'TIMEOUT', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Aguardar Resposta do Cliente',
      wait_for: 'customer_reply',
      conversation: 'current',
      timeout_hours: 24,
      timeout_unit: 'hours',
      ignore_bot_messages: true,
      ignore_private_notes: true,
      only_customer_messages: true,
    },
    summarize: cfg => `Timeout: ${cfg.timeout_hours || 24} horas`,
  },

  // 10. SET VARIABLE
  set_variable: {
    type: 'set_variable',
    title: 'Definir Variável',
    subtitle: 'Atribui um valor a uma variável do fluxo',
    category: 'data',
    icon: '📝',
    iconColor: '#EC4899',
    badge: 'Dados',
    badgeType: 'data',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Definir Variável',
      variable_name: 'lead_score',
      variable_type: 'number',
      variable_value: '10',
    },
    summarize: cfg =>
      `${cfg.variable_name || 'var'} = ${cfg.variable_value || ''}`,
  },

  // 11. ADD TAG
  add_tag: {
    type: 'add_tag',
    title: 'Adicionar Tag',
    subtitle: 'Adiciona uma tag ao contato',
    category: 'chatwoot',
    icon: '🏷️',
    iconColor: '#EF4444',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Adicionar Tag',
      tag_name: 'cliente_vip',
    },
    summarize: cfg => `Tag: ${cfg.tag_name || 'sem tag'}`,
  },

  // 12. REMOVE TAG
  remove_tag: {
    type: 'remove_tag',
    title: 'Remover Tag',
    subtitle: 'Remove uma tag existente do contato',
    category: 'chatwoot',
    icon: '🏷️',
    iconColor: '#EF4444',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Remover Tag',
      tag_name: '',
    },
    summarize: cfg => `Remover: ${cfg.tag_name || 'sem tag'}`,
  },

  // 13. UPDATE CONTACT
  update_contact: {
    type: 'update_contact',
    title: 'Atualizar Contato',
    subtitle: 'Altera dados cadastrais do contato',
    category: 'chatwoot',
    icon: '👤',
    iconColor: '#3B82F6',
    badge: 'CRM',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Atualizar Contato',
      field_name: 'name',
      field_value: '{{webhook.customer.name}}',
    },
    summarize: cfg => `${cfg.field_name || 'campo'} ← ${cfg.field_value || ''}`,
  },

  // 14. UPDATE CUSTOM ATTRIBUTE
  update_custom_attribute: {
    type: 'update_custom_attribute',
    title: 'Atualizar Atributo Customizado',
    subtitle: 'Define valor de campo customizado',
    category: 'chatwoot',
    icon: '⚙️',
    iconColor: '#64748B',
    badge: 'CRM',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Atualizar Atributo',
      attribute_key: 'cliente_ativo',
      attribute_value: 'true',
    },
    summarize: cfg =>
      `${cfg.attribute_key || 'atributo'} = ${cfg.attribute_value || ''}`,
  },

  // 15. UPDATE CONVERSATION
  update_conversation: {
    type: 'update_conversation',
    title: 'Atualizar Conversa',
    subtitle: 'Altera prioridade ou status da conversa',
    category: 'chatwoot',
    icon: '💬',
    iconColor: '#3B82F6',
    badge: 'Chatwoot',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Atualizar Conversa',
      priority: 'high',
      status: 'open',
    },
    summarize: cfg => `Prioridade: ${cfg.priority || 'média'}`,
  },

  // 16. ASSIGN AGENT
  assign_agent: {
    type: 'assign_agent',
    title: 'Atribuir Agente',
    subtitle: 'Define um atendente responsável',
    category: 'chatwoot',
    icon: '👤',
    iconColor: '#10B981',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Atribuir Agente',
      agent_id: '',
      agent_name: 'Samuel',
    },
    summarize: cfg => `Agente: ${cfg.agent_name || 'Automático'}`,
  },

  // 17. ASSIGN TEAM
  assign_team: {
    type: 'assign_team',
    title: 'Atribuir ao Time',
    subtitle: 'Direciona conversa para equipe especializada',
    category: 'chatwoot',
    icon: '👥',
    iconColor: '#8B5CF6',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Atribuir ao Time',
      team_id: '',
      team_name: 'Vendas',
    },
    summarize: cfg => `Time: ${cfg.team_name || 'Equipe'}`,
  },

  // 18. ADD PRIVATE NOTE
  add_private_note: {
    type: 'add_private_note',
    title: 'Adicionar Nota Privada',
    subtitle: 'Insere uma nota interna na conversa',
    category: 'chatwoot',
    icon: '🔒',
    iconColor: '#F59E0B',
    badge: 'Interno',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Adicionar Nota Privada',
      note_text: 'Lead qualificado via fluxo automatizado.',
    },
    summarize: cfg =>
      cfg.note_text ? `"${cfg.note_text.slice(0, 32)}..."` : 'Nota vazia',
  },

  // 19. RESOLVE CONVERSATION
  resolve_conversation: {
    type: 'resolve_conversation',
    title: 'Resolver Conversa',
    subtitle: 'Finaliza e fecha o ticket de atendimento',
    category: 'chatwoot',
    icon: '✅',
    iconColor: '#10B981',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Resolver Conversa',
    },
    summarize: () => 'Finalizar ticket',
  },

  // 20. REOPEN CONVERSATION
  reopen_conversation: {
    type: 'reopen_conversation',
    title: 'Reabrir Conversa',
    subtitle: 'Reabre um atendimento finalizado',
    category: 'chatwoot',
    icon: '🔄',
    iconColor: '#3B82F6',
    badge: 'Ação',
    badgeType: 'action',
    hasInput: true,
    outputs: [{ id: 'output', label: '', type: 'default' }],
    defaultConfig: {
      custom_title: 'Reabrir Conversa',
    },
    summarize: () => 'Reabrir ticket',
  },

  // 21. HTTP REQUEST
  http_request: {
    type: 'http_request',
    title: 'Requisição HTTP',
    subtitle: 'Faz uma requisição externa',
    category: 'integrations',
    icon: '🌐',
    iconColor: '#3B82F6',
    badge: 'Integração',
    badgeType: 'integration',
    hasInput: true,
    outputs: [
      { id: 'SUCCESS', label: 'SUCCESS', type: 'success' },
      { id: 'ERROR', label: 'ERROR', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'HTTP Request - Criar Pedido',
      method: 'POST',
      url: 'https://api.exemplo.com/orders',
      params: [{ key: 'source', value: '{{webhook.source}}' }],
      headers: [
        { key: 'Authorization', value: 'Bearer **********' },
        { key: 'Content-Type', value: 'application/json' },
      ],
      body: JSON.stringify(
        {
          customer_name: '{{contact.name}}',
          order_id: '{{webhook.order_id}}',
          source: '{{webhook.source}}',
        },
        null,
        2
      ),
      timeout: 30,
      retry_count: 3,
      retry_interval: 5,
      save_response_as: 'workflow.http_response',
    },
    summarize: cfg =>
      `${cfg.method || 'POST'} ${cfg.url || 'https://api...'}\nEnvia dados para API externa`,
  },

  // 22. SEND WEBHOOK
  send_webhook: {
    type: 'send_webhook',
    title: 'Enviar Webhook Outbound',
    subtitle: 'Dispara payload para URL externa',
    category: 'integrations',
    icon: '📤',
    iconColor: '#8B5CF6',
    badge: 'Integração',
    badgeType: 'integration',
    hasInput: true,
    outputs: [
      { id: 'SUCCESS', label: 'SUCCESS', type: 'success' },
      { id: 'ERROR', label: 'ERROR', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Enviar Webhook',
      url: 'https://n8n.meusuper.app/webhook/chatwoot',
      method: 'POST',
      payload: '{\n  "event": "lead_converted"\n}',
    },
    summarize: cfg => `POST ${cfg.url || 'https://...'}`,
  },

  // 23. END WORKFLOW
  end_workflow: {
    type: 'end_workflow',
    title: 'Fim do Fluxo',
    subtitle: 'Encerra a execução do workflow',
    category: 'flow_control',
    icon: '🛑',
    iconColor: '#EF4444',
    badge: 'Fim',
    badgeType: 'flow_control',
    hasInput: true,
    outputs: [],
    defaultConfig: {
      custom_title: 'Fim do Fluxo',
      result_status: 'completed',
    },
    summarize: cfg => `Status final: ${cfg.result_status || 'completed'}`,
  },
};

export const getNodeDefinition = type => {
  return WORKFLOW_NODES_REGISTRY[type] || WORKFLOW_NODES_REGISTRY.send_message;
};
