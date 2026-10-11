export const NODE_CATEGORIES = [
  { id: 'all', name: 'Todos', icon: 'i-lucide-layout-grid' },
  { id: 'triggers', name: 'Gatilhos', icon: 'i-lucide-zap' },
  { id: 'whatsapp', name: 'WhatsApp', icon: 'i-ri-whatsapp-line' },
  { id: 'messaging', name: 'Mensagens', icon: 'i-lucide-message-square' },
  { id: 'logic', name: 'Lógica', icon: 'i-lucide-git-branch' },
  { id: 'time', name: 'Tempo', icon: 'i-lucide-clock' },
  { id: 'data', name: 'Dados', icon: 'i-lucide-variable' },
  { id: 'chatwoot', name: 'Chatwoot', icon: 'i-lucide-inbox' },
  { id: 'integrations', name: 'Integrações', icon: 'i-lucide-plug' },
  { id: 'flow_control', name: 'Controle', icon: 'i-lucide-flag' },
];

export const CATEGORY_STYLES = {
  triggers: {
    hex: '#FFC53D',
    accent: 'bg-n-amber-9',
    soft: 'bg-n-amber-3',
    text: 'text-n-amber-11',
    border: 'border-n-amber-8',
    hoverBorder: 'hover:border-n-amber-9',
    badge: 'bg-n-amber-3 text-n-amber-11',
  },
  whatsapp: {
    hex: '#30A46C',
    accent: 'bg-green-500',
    soft: 'bg-green-500/15',
    text: 'text-green-500',
    border: 'border-green-500/60',
    hoverBorder: 'hover:border-green-500',
    badge: 'bg-green-500/15 text-green-500',
  },
  messaging: {
    hex: '#5B5BD6',
    accent: 'bg-n-iris-9',
    soft: 'bg-n-iris-3',
    text: 'text-n-iris-11',
    border: 'border-n-iris-8',
    hoverBorder: 'hover:border-n-iris-9',
    badge: 'bg-n-iris-3 text-n-iris-11',
  },
  logic: {
    hex: '#E54666',
    accent: 'bg-n-ruby-9',
    soft: 'bg-n-ruby-3',
    text: 'text-n-ruby-11',
    border: 'border-n-ruby-8',
    hoverBorder: 'hover:border-n-ruby-9',
    badge: 'bg-n-ruby-3 text-n-ruby-11',
  },
  time: {
    hex: '#12A594',
    accent: 'bg-n-teal-9',
    soft: 'bg-n-teal-3',
    text: 'text-n-teal-11',
    border: 'border-n-teal-8',
    hoverBorder: 'hover:border-n-teal-9',
    badge: 'bg-n-teal-3 text-n-teal-11',
  },
  data: {
    hex: '#6E56CF',
    accent: 'bg-n-violet-9',
    soft: 'bg-n-violet-3',
    text: 'text-n-violet-11',
    border: 'border-n-violet-8',
    hoverBorder: 'hover:border-n-violet-9',
    badge: 'bg-n-violet-3 text-n-violet-11',
  },
  chatwoot: {
    hex: '#F76B15',
    accent: 'bg-n-blue-9',
    soft: 'bg-n-blue-3',
    text: 'text-n-blue-11',
    border: 'border-n-blue-8',
    hoverBorder: 'hover:border-n-blue-9',
    badge: 'bg-n-blue-3 text-n-blue-11',
  },
  integrations: {
    hex: '#F5D90A',
    accent: 'bg-yellow-500',
    soft: 'bg-yellow-500/15',
    text: 'text-yellow-500',
    border: 'border-yellow-500/60',
    hoverBorder: 'hover:border-yellow-500',
    badge: 'bg-yellow-500/15 text-yellow-500',
  },
  flow_control: {
    hex: '#8B8D98',
    accent: 'bg-n-slate-9',
    soft: 'bg-n-slate-3',
    text: 'text-n-slate-11',
    border: 'border-n-slate-8',
    hoverBorder: 'hover:border-n-slate-9',
    badge: 'bg-n-slate-3 text-n-slate-11',
  },
};

export const OUTPUT_COLORS = {
  success: '#10B981',
  danger: '#F43F5E',
  default: '#94A3B8',
};

const SINGLE_OUTPUT = [{ id: 'output', label: '', type: 'default' }];

const truncate = (text, size) =>
  text.length > size ? `${text.slice(0, size)}…` : text;

export const WORKFLOW_NODES_REGISTRY = {
  webhook_trigger: {
    type: 'webhook_trigger',
    title: 'Webhook',
    subtitle: 'Inicia quando uma requisição chega na URL do fluxo',
    category: 'triggers',
    icon: 'i-lucide-webhook',
    badge: 'Gatilho',
    isTrigger: true,
    hasInput: false,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Webhook recebido',
    },
    summarize: () => '',
  },

  incoming_message_trigger: {
    type: 'incoming_message_trigger',
    title: 'Mensagem recebida',
    subtitle: 'Inicia quando o contato escreve na caixa escolhida',
    category: 'triggers',
    icon: 'i-lucide-message-circle',
    badge: 'Gatilho',
    isTrigger: true,
    hasInput: false,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Mensagem recebida',
      inbox_id: null,
      occurrence: 'first',
      keyword: '',
    },
    summarize: cfg =>
      cfg.occurrence === 'every'
        ? 'A cada mensagem do contato'
        : 'Na primeira mensagem do contato',
  },

  conversation_created_trigger: {
    type: 'conversation_created_trigger',
    title: 'Conversa criada',
    subtitle: 'Inicia quando uma conversa nova nasce na caixa',
    category: 'triggers',
    icon: 'i-lucide-message-square-plus',
    badge: 'Gatilho',
    isTrigger: true,
    hasInput: false,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Conversa criada',
      inbox_id: null,
    },
    summarize: () => 'Quando a conversa é criada',
  },

  widget_opened_trigger: {
    type: 'widget_opened_trigger',
    title: 'Widget aberto',
    subtitle: 'Inicia quando o visitante abre o widget do site',
    category: 'triggers',
    icon: 'i-lucide-app-window',
    badge: 'Gatilho',
    isTrigger: true,
    hasInput: false,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Widget aberto',
      inbox_id: null,
      frequency: 'once_per_contact',
    },
    summarize: cfg =>
      cfg.frequency === 'every_open'
        ? 'A cada abertura do widget'
        : 'Uma vez por contato',
  },

  conversation_reopened_trigger: {
    type: 'conversation_reopened_trigger',
    title: 'Conversa reaberta',
    subtitle: 'Inicia quando uma conversa resolvida ou adiada volta',
    category: 'triggers',
    icon: 'i-lucide-rotate-ccw',
    badge: 'Gatilho',
    isTrigger: true,
    hasInput: false,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Conversa reaberta',
      inbox_id: null,
      from_statuses: ['resolved', 'snoozed'],
    },
    summarize: () => 'Quando a conversa é reaberta',
  },

  send_message: {
    type: 'send_message',
    title: 'Enviar Mensagem',
    subtitle: 'Texto, foto, vídeo, áudio ou arquivo na conversa',
    category: 'messaging',
    icon: 'i-lucide-message-square-text',
    badge: 'Mensagem',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Enviar Mensagem',
      content: 'Olá {{ $contact.first_name }}! Como posso ajudar?',
      private: false,
      attachments: [],
    },
    summarize: cfg => {
      const text = cfg.content ? truncate(cfg.content, 60) : '';
      const count = Array.isArray(cfg.attachments) ? cfg.attachments.length : 0;
      const files = count ? `${count} anexo${count > 1 ? 's' : ''}` : '';
      if (text && files) return `${text} · ${files}`;
      return text || files || 'Escreva a mensagem…';
    },
  },

  send_whatsapp_message: {
    type: 'send_whatsapp_message',
    title: 'Mensagem WhatsApp',
    subtitle: 'Texto livre na janela de 24h ou template fora dela',
    category: 'whatsapp',
    icon: 'i-ri-whatsapp-line',
    badge: 'WhatsApp',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Mensagem WhatsApp',
      delivery_mode: 'auto',
      text: 'Olá {{ $contact.first_name }}! Como posso te ajudar hoje?',
      template_name: '',
      template_language: 'pt_BR',
      template_params: {},
    },
    summarize: cfg => {
      if (cfg.delivery_mode === 'outside_24h') {
        return `Template: ${cfg.template_name || 'não selecionado'}`;
      }
      return cfg.text ? truncate(cfg.text, 80) : 'Escreva a mensagem…';
    },
  },

  send_whatsapp_template: {
    type: 'send_whatsapp_template',
    title: 'Template WhatsApp',
    subtitle: 'Envia um template aprovado pela Meta',
    category: 'whatsapp',
    icon: 'i-lucide-layout-template',
    badge: 'WhatsApp',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Template WhatsApp',
      template_name: '',
      template_category: 'MARKETING',
      template_language: 'pt_BR',
      template_params: {},
    },
    summarize: cfg =>
      cfg.template_name
        ? `${cfg.template_name} · ${cfg.template_language || 'pt_BR'}`
        : 'Selecione um template…',
  },

  send_whatsapp_buttons: {
    type: 'send_whatsapp_buttons',
    title: 'Botões de resposta',
    subtitle: 'Até 3 botões pela API oficial, dentro da janela de 24h',
    category: 'whatsapp',
    icon: 'i-lucide-mouse-pointer-click',
    badge: 'API oficial',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Botões de resposta',
      body: 'Como posso te ajudar?',
      header: '',
      footer: '',
      buttons: [
        { id: 'sim', title: 'Sim' },
        { id: 'nao', title: 'Não' },
      ],
    },
    summarize: cfg =>
      (cfg.buttons || [])
        .map(button => button.title)
        .filter(Boolean)
        .join(' · ') || 'Adicione os botões…',
  },

  send_whatsapp_list: {
    type: 'send_whatsapp_list',
    title: 'Lista de opções',
    subtitle: 'Menu com até 10 opções pela API oficial',
    category: 'whatsapp',
    icon: 'i-lucide-list',
    badge: 'API oficial',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Lista de opções',
      body: 'Escolha uma opção para continuar.',
      button_label: 'Ver opções',
      header: '',
      footer: '',
      rows: [
        {
          id: 'pedido',
          title: 'Meu pedido',
          description: 'Acompanhar uma compra',
        },
        { id: 'atendente', title: 'Falar com atendente', description: '' },
      ],
    },
    summarize: cfg =>
      `${(cfg.rows || []).filter(row => row.title).length} opções`,
  },

  send_whatsapp_media: {
    type: 'send_whatsapp_media',
    title: 'Mídia',
    subtitle: 'Imagem, vídeo, áudio ou documento por link https',
    category: 'whatsapp',
    icon: 'i-lucide-image',
    badge: 'API oficial',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Mídia',
      media_type: 'image',
      url: '',
      caption: '',
      filename: '',
    },
    summarize: cfg => {
      const labels = {
        image: 'Imagem',
        video: 'Vídeo',
        audio: 'Áudio',
        document: 'Documento',
      };
      return cfg.url
        ? `${labels[cfg.media_type] || 'Mídia'} · ${truncate(cfg.url, 48)}`
        : 'Informe o link da mídia…';
    },
  },

  condition: {
    type: 'condition',
    title: 'Condição',
    subtitle: 'Divide o fluxo em verdadeiro ou falso',
    category: 'logic',
    icon: 'i-lucide-git-branch',
    badge: 'Lógica',
    hasInput: true,
    outputs: [
      { id: 'true', label: 'Verdadeiro', type: 'success' },
      { id: 'false', label: 'Falso', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Condição',
      match_type: 'all',
      conditions: [
        {
          field: '{{ $webhook.status }}',
          operator: 'equal_to',
          value: 'interested',
        },
      ],
    },
    summarize: () => '',
  },

  router: {
    type: 'router',
    title: 'Roteador',
    subtitle: 'Direciona o fluxo por múltiplas rotas',
    category: 'logic',
    icon: 'i-lucide-split',
    badge: 'Lógica',
    hasInput: true,
    outputs: [{ id: 'Default', label: 'Default', color: '#94A3B8' }],
    defaultConfig: {
      custom_title: 'Roteador',
      source_variable: '{{ $webhook.source }}',
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
      ],
      default_route_name: 'Default',
    },
    summarize: () => '',
  },

  delay: {
    type: 'delay',
    title: 'Aguardar',
    subtitle: 'Pausa o fluxo por um período',
    category: 'time',
    icon: 'i-lucide-timer',
    badge: 'Tempo',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Aguardar',
      duration: 10,
      unit: 'minutes',
    },
    summarize: cfg => {
      const units = {
        seconds: 'segundo(s)',
        minutes: 'minuto(s)',
        hours: 'hora(s)',
        days: 'dia(s)',
      };
      return `Esperar ${cfg.duration || 0} ${units[cfg.unit] || 'minuto(s)'}`;
    },
  },

  wait_until: {
    type: 'wait_until',
    title: 'Aguardar Até',
    subtitle: 'Pausa até um horário ou data',
    category: 'time',
    icon: 'i-lucide-calendar-clock',
    badge: 'Tempo',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Aguardar Até',
      wait_mode: 'specific_time',
      target_time: '09:00',
      timezone: 'America/Sao_Paulo',
    },
    summarize: cfg =>
      cfg.wait_mode === 'business_hours'
        ? 'Próximo horário comercial'
        : `Até ${cfg.target_time || '--:--'}`,
  },

  wait_for_reply: {
    type: 'wait_for_reply',
    title: 'Aguardar Resposta',
    subtitle: 'Espera o cliente responder',
    category: 'time',
    icon: 'i-lucide-hourglass',
    badge: 'Tempo',
    hasInput: true,
    outputs: [
      { id: 'REPLIED', label: 'Respondeu', type: 'success' },
      { id: 'TIMEOUT', label: 'Sem resposta', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Aguardar Resposta',
      timeout_hours: 24,
      ignore_bot_messages: true,
      ignore_private_notes: true,
      only_customer_messages: true,
      save_reply_as: '',
    },
    summarize: cfg => {
      const wait = `Tempo limite: ${cfg.timeout_hours || 24}h`;
      return cfg.save_reply_as ? `${wait} · ${cfg.save_reply_as}` : wait;
    },
  },

  set_variable: {
    type: 'set_variable',
    title: 'Definir Variável',
    subtitle: 'Guarda um valor para usar depois',
    category: 'data',
    icon: 'i-lucide-variable',
    badge: 'Dados',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Definir Variável',
      variable_name: 'lead_score',
      variable_type: 'string',
      variable_value: '10',
    },
    summarize: cfg =>
      `$vars.${cfg.variable_name || 'nome'} = ${cfg.variable_value || '…'}`,
  },

  add_tag: {
    type: 'add_tag',
    title: 'Adicionar Etiqueta',
    subtitle: 'Adiciona uma etiqueta à conversa',
    category: 'chatwoot',
    icon: 'i-lucide-tag',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Adicionar Etiqueta',
      tag_name: '',
    },
    summarize: cfg =>
      cfg.tag_name ? `#${cfg.tag_name}` : 'Escolha a etiqueta…',
  },

  remove_tag: {
    type: 'remove_tag',
    title: 'Remover Etiqueta',
    subtitle: 'Remove uma etiqueta da conversa',
    category: 'chatwoot',
    icon: 'i-lucide-tags',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Remover Etiqueta',
      tag_name: '',
    },
    summarize: cfg =>
      cfg.tag_name ? `Remover #${cfg.tag_name}` : 'Escolha a etiqueta…',
  },

  update_contact: {
    type: 'update_contact',
    title: 'Atualizar Contato',
    subtitle: 'Altera dados cadastrais do contato',
    category: 'chatwoot',
    icon: 'i-lucide-user-pen',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Atualizar Contato',
      field_name: 'name',
      field_value: '{{ $webhook.customer.name }}',
    },
    summarize: cfg => `${cfg.field_name || 'campo'} ← ${cfg.field_value || ''}`,
  },

  update_custom_attribute: {
    type: 'update_custom_attribute',
    title: 'Atributo Personalizado',
    subtitle: 'Define o valor de um atributo',
    category: 'chatwoot',
    icon: 'i-lucide-sliders-horizontal',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Atributo Personalizado',
      target: 'contact',
      attribute_key: '',
      attribute_value: '',
    },
    summarize: cfg =>
      cfg.attribute_key
        ? `${cfg.attribute_key} = ${cfg.attribute_value || '…'}`
        : 'Escolha o atributo…',
  },

  update_conversation: {
    type: 'update_conversation',
    title: 'Atualizar Conversa',
    subtitle: 'Altera prioridade ou status da conversa',
    category: 'chatwoot',
    icon: 'i-lucide-messages-square',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Atualizar Conversa',
      priority: 'high',
      status: 'open',
    },
    summarize: cfg =>
      `Prioridade ${cfg.priority || '—'} · Status ${cfg.status || '—'}`,
  },

  assign_agent: {
    type: 'assign_agent',
    title: 'Atribuir Agente',
    subtitle: 'Define o agente responsável',
    category: 'chatwoot',
    icon: 'i-lucide-user-check',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Atribuir Agente',
      agent_id: '',
      agent_name: '',
    },
    summarize: cfg => cfg.agent_name || 'Escolha o agente…',
  },

  assign_team: {
    type: 'assign_team',
    title: 'Atribuir Time',
    subtitle: 'Direciona a conversa para um time',
    category: 'chatwoot',
    icon: 'i-lucide-users',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Atribuir Time',
      team_id: '',
      team_name: '',
    },
    summarize: cfg => cfg.team_name || 'Escolha o time…',
  },

  add_private_note: {
    type: 'add_private_note',
    title: 'Nota Privada',
    subtitle: 'Adiciona uma nota interna na conversa',
    category: 'chatwoot',
    icon: 'i-lucide-sticky-note',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Nota Privada',
      note_text: 'Lead qualificado via fluxo automatizado.',
    },
    summarize: cfg =>
      cfg.note_text ? truncate(cfg.note_text, 80) : 'Escreva a nota…',
  },

  resolve_conversation: {
    type: 'resolve_conversation',
    title: 'Resolver Conversa',
    subtitle: 'Marca a conversa como resolvida',
    category: 'chatwoot',
    icon: 'i-lucide-circle-check',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Resolver Conversa',
    },
    summarize: () => '',
  },

  reopen_conversation: {
    type: 'reopen_conversation',
    title: 'Reabrir Conversa',
    subtitle: 'Reabre um atendimento resolvido',
    category: 'chatwoot',
    icon: 'i-lucide-rotate-ccw',
    badge: 'Chatwoot',
    hasInput: true,
    outputs: SINGLE_OUTPUT,
    defaultConfig: {
      custom_title: 'Reabrir Conversa',
    },
    summarize: () => '',
  },

  http_request: {
    type: 'http_request',
    title: 'Requisição HTTP',
    subtitle: 'Chama uma API externa',
    category: 'integrations',
    icon: 'i-lucide-globe',
    badge: 'Integração',
    hasInput: true,
    outputs: [
      { id: 'SUCCESS', label: 'Sucesso', type: 'success' },
      { id: 'ERROR', label: 'Erro', type: 'danger' },
    ],
    defaultConfig: {
      custom_title: 'Requisição HTTP',
      method: 'POST',
      url: 'https://api.exemplo.com/orders',
      params: [],
      headers: [{ key: 'Content-Type', value: 'application/json' }],
      auth_type: 'none',
      body: JSON.stringify(
        {
          customer_name: '{{ $contact.name }}',
          phone: '{{ $contact.phone_number }}',
        },
        null,
        2
      ),
      timeout: 15,
      retry_count: 1,
      retry_interval: 2,
      save_response_as: 'http_response',
      response_mappings: [],
    },
    summarize: cfg => `${cfg.method || 'POST'} ${cfg.url || 'https://…'}`,
  },

  end_workflow: {
    type: 'end_workflow',
    title: 'Fim do Fluxo',
    subtitle: 'Encerra a execução',
    category: 'flow_control',
    icon: 'i-lucide-octagon-x',
    badge: 'Controle',
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

export const getCategoryStyle = type =>
  CATEGORY_STYLES[getNodeDefinition(type).category] ||
  CATEGORY_STYLES.messaging;

const CHOICE_COLORS = [
  '#3B82F6',
  '#10B981',
  '#F59E0B',
  '#8B5CF6',
  '#EC4899',
  '#06B6D4',
  '#F97316',
  '#14B8A6',
  '#6366F1',
  '#84CC16',
];
const ELSE_OUTPUT = { id: 'else', label: 'Outra resposta', color: '#94A3B8' };

const choiceOutputs = (items, prefix, idLimit) =>
  (items || []).flatMap((item, index) => {
    const title = String(item?.title || '').trim();
    if (!title) return [];

    return [
      {
        id: String(item.id || `${prefix}_${index + 1}`).slice(0, idLimit),
        label: title,
        color: CHOICE_COLORS[index % CHOICE_COLORS.length],
      },
    ];
  });

export const getNodeOutputs = (type, config = {}) => {
  const definition = getNodeDefinition(type);
  if (type === 'send_whatsapp_buttons') {
    return [...choiceOutputs(config.buttons, 'opcao', 256), ELSE_OUTPUT];
  }
  if (type === 'send_whatsapp_list') {
    return [...choiceOutputs(config.rows, 'item', 200), ELSE_OUTPUT];
  }
  if (type !== 'router') return definition.outputs || [];

  const named = (config.routes || [])
    .filter(route => route.name)
    .map(route => ({
      id: route.name,
      label: route.name,
      color: route.color || '#3B82F6',
    }));
  const fallback = config.default_route_name || 'Default';
  return [...named, { id: fallback, label: fallback, color: '#94A3B8' }];
};

export const getOutputColor = output =>
  output.color || OUTPUT_COLORS[output.type] || OUTPUT_COLORS.default;
