export const VARIABLE_TOKEN_REGEX = /\{\{(.*?)\}\}/g;
const VARIABLE_PATH_REGEX = /^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$/;
const DECLARED_VAR_PREFIX = /^(workflow|vars?)\./;
const MAX_PAYLOAD_DEPTH = 6;

const CONTACT_FIELDS = [
  { path: 'contact.name', label: 'Nome completo' },
  { path: 'contact.first_name', label: 'Primeiro nome' },
  { path: 'contact.last_name', label: 'Sobrenome' },
  { path: 'contact.phone_number', label: 'Telefone' },
  { path: 'contact.email', label: 'E-mail' },
  { path: 'contact.id', label: 'ID do contato' },
];

const CONVERSATION_FIELDS = [
  { path: 'conversation.id', label: 'ID da conversa' },
  { path: 'conversation.status', label: 'Status' },
  { path: 'conversation.priority', label: 'Prioridade' },
  {
    path: 'conversation.last_message',
    label: 'Última mensagem do contato',
  },
];

const SYSTEM_FIELDS = [
  { path: 'inbox.id', label: 'ID da caixa' },
  { path: 'inbox.name', label: 'Nome da caixa' },
  { path: 'inbox.channel_type', label: 'Canal' },
  { path: 'account.id', label: 'ID da conta' },
  { path: 'account.name', label: 'Nome da conta' },
];

const STRICT_ROOTS = ['contact', 'conversation', 'inbox', 'account'];
const PATH_ALIASES = { var: 'vars', workflow: 'vars', payload: 'webhook' };

export const normalizeVariablePath = raw => {
  let path = String(raw || '').trim();
  const wrapped = path.match(/^\{\{\s*(.+?)\s*\}\}$/);
  if (wrapped) [, path] = wrapped;
  return path.replace(/^\$/, '');
};

export const formatVariable = path => `{{ $${path} }}`;

const ARRAY_PREVIEW = '[…]';

const previewValue = value => {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') {
    return Array.isArray(value) ? ARRAY_PREVIEW : '{…}';
  }
  return String(value).slice(0, 40);
};

export const flattenPayload = (data, prefix = 'webhook', depth = 0) => {
  if (!data || typeof data !== 'object' || depth > MAX_PAYLOAD_DEPTH) return [];

  return Object.entries(data).flatMap(([key, value]) => {
    const path = `${prefix}.${key}`;
    const entry = { path, label: key, sample: previewValue(value) };
    if (Array.isArray(value)) {
      return [entry, ...flattenPayload(value.slice(0, 1), path, depth + 1)];
    }
    if (value && typeof value === 'object') {
      return [entry, ...flattenPayload(value, path, depth + 1)];
    }
    return [entry];
  });
};

export const declaredFlowVariables = nodes =>
  nodes.flatMap(node => {
    const type = node.data?.type;
    const config = node.data?.config || {};
    if (type === 'set_variable' && config.variable_name) {
      return [config.variable_name.replace(/^vars\./, '')];
    }
    if (type === 'wait_for_reply' && config.save_reply_as) {
      return [String(config.save_reply_as).replace(/^vars\./, '')];
    }
    if (type === 'http_request' || type === 'send_webhook') {
      const name = (config.save_response_as || 'http_response').replace(
        DECLARED_VAR_PREFIX,
        ''
      );
      const mapped = (config.response_mappings || [])
        .filter(row => (row.destination || 'variable') === 'variable')
        .map(row => String(row.variable_name || '').replace(/^vars\./, ''))
        .filter(rowName => /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(rowName));
      return [name, ...mapped];
    }
    return [];
  });

export const buildVariableCatalog = ({
  samplePayload = {},
  nodes = [],
  contactAttributes = [],
  conversationAttributes = [],
}) => {
  const webhookItems = flattenPayload(samplePayload);
  const flowVariables = [...new Set(declaredFlowVariables(nodes))];
  const flowItems = flowVariables.flatMap(name => {
    const isHttp = nodes.some(
      node =>
        node.data?.type === 'http_request' &&
        (node.data?.config?.save_response_as || 'http_response').replace(
          DECLARED_VAR_PREFIX,
          ''
        ) === name
    );
    const base = { path: `vars.${name}`, label: name };
    if (!isHttp) return [base];
    return [
      base,
      { path: `vars.${name}.status`, label: `${name} · status HTTP` },
      { path: `vars.${name}.body`, label: `${name} · corpo da resposta` },
    ];
  });

  const attributeItem = (attr, root) => {
    const key = attr?.attribute_key || attr?.attributeKey;
    if (!key) return null;
    return {
      path: `${root}.custom_attributes.${key}`,
      label: attr.attribute_display_name || attr.attributeDisplayName || key,
    };
  };
  const contactItems = [
    ...CONTACT_FIELDS,
    ...contactAttributes.map(attr => attributeItem(attr, 'contact')),
  ].filter(Boolean);
  const conversationItems = [
    ...CONVERSATION_FIELDS,
    ...conversationAttributes.map(attr => attributeItem(attr, 'conversation')),
  ].filter(Boolean);

  const groups = [
    {
      id: 'webhook',
      label: 'Webhook (payload recebido)',
      icon: 'i-lucide-webhook',
      items: webhookItems,
      emptyHint: 'Capture uma requisição no gatilho para listar os campos.',
    },
    {
      id: 'contact',
      label: 'Contato',
      icon: 'i-lucide-contact',
      items: contactItems,
    },
    {
      id: 'conversation',
      label: 'Conversa',
      icon: 'i-lucide-message-circle',
      items: conversationItems,
    },
    {
      id: 'vars',
      label: 'Variáveis do fluxo',
      icon: 'i-lucide-variable',
      items: flowItems,
      emptyHint:
        'Use Definir Variável, Aguardar Resposta ou Requisição HTTP para criar.',
    },
    {
      id: 'system',
      label: 'Caixa e conta',
      icon: 'i-lucide-inbox',
      items: SYSTEM_FIELDS,
    },
  ];

  const knownPaths = new Set(
    groups.flatMap(group => group.items.map(item => item.path))
  );
  const hasWebhookSample = webhookItems.length > 0;

  const isValid = raw => {
    const path = normalizeVariablePath(raw);
    if (!VARIABLE_PATH_REGEX.test(path)) return false;

    const [rawRoot, ...rest] = path.split('.');
    const root = PATH_ALIASES[rawRoot] || rawRoot;
    const normalized = [root, ...rest].join('.');
    if (knownPaths.has(normalized)) return true;
    if (!rest.length) return false;

    if (root === 'webhook') {
      if (!hasWebhookSample) return true;
      return webhookItems.some(
        item =>
          item.sample === ARRAY_PREVIEW &&
          normalized.startsWith(`${item.path}.`)
      );
    }
    if (root === 'vars') return flowVariables.includes(rest[0]);
    if (STRICT_ROOTS.includes(root)) {
      return rest[0] === 'custom_attributes' && rest.length > 1;
    }
    return root === 'custom_attributes';
  };

  return { groups, isValid };
};

export const tokenizeTemplate = (text, isValid) => {
  const value = String(text ?? '');
  const segments = [];
  let lastIndex = 0;

  value.replace(VARIABLE_TOKEN_REGEX, (match, inner, offset) => {
    if (offset > lastIndex) {
      segments.push({ text: value.slice(lastIndex, offset), type: 'text' });
    }
    const trimmed = inner.trim();
    const isPlaceholder = /^\d+$/.test(trimmed);
    segments.push({
      text: match,
      type: 'variable',
      valid: isPlaceholder || isValid(trimmed),
    });
    lastIndex = offset + match.length;
    return match;
  });

  if (lastIndex < value.length) {
    segments.push({ text: value.slice(lastIndex), type: 'text' });
  }
  return segments;
};

export const invalidTokens = (text, isValid) =>
  tokenizeTemplate(text, isValid)
    .filter(segment => segment.type === 'variable' && !segment.valid)
    .map(segment => segment.text);
