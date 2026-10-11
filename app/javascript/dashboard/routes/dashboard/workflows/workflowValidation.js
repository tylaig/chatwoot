import { getNodeDefinition } from './nodeRegistry';
import { invalidTokens, normalizeVariablePath } from './variables';

const VARIABLE_NAME_REGEX = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

const collectStrings = value => {
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.flatMap(collectStrings);
  if (value && typeof value === 'object') {
    return Object.values(value).flatMap(collectStrings);
  }
  return [];
};

const plainOver = (value, max) =>
  Boolean(value) && !String(value).includes('{{') && String(value).length > max;

function buttonIssues(config) {
  const issues = [];
  if (!config.body) issues.push('O texto da mensagem não pode ficar vazio.');
  const buttons = config.buttons || [];
  if (buttons.length < 1 || buttons.length > 3) {
    issues.push('A API oficial aceita de 1 a 3 botões.');
  }
  buttons.forEach((button, index) => {
    if (!button.title) issues.push(`O botão ${index + 1} precisa de um texto.`);
    else if (plainOver(button.title, 20)) {
      issues.push(`O botão ${index + 1} pode ter no máximo 20 caracteres.`);
    }
  });
  return issues;
}

function listIssues(config) {
  const issues = [];
  if (!config.body) issues.push('O texto da mensagem não pode ficar vazio.');
  if (!config.button_label) {
    issues.push('Informe o texto do botão que abre a lista.');
  } else if (plainOver(config.button_label, 20)) {
    issues.push('O botão da lista pode ter no máximo 20 caracteres.');
  }
  const rows = config.rows || [];
  if (rows.length < 1 || rows.length > 10) {
    issues.push('A lista precisa de 1 a 10 opções.');
  }
  rows.forEach((row, index) => {
    if (!row.title) issues.push(`A opção ${index + 1} precisa de um título.`);
    else if (plainOver(row.title, 24)) {
      issues.push(`A opção ${index + 1} pode ter no máximo 24 caracteres.`);
    }
    if (plainOver(row.description, 72)) {
      issues.push(
        `A descrição da opção ${index + 1} pode ter no máximo 72 caracteres.`
      );
    }
  });
  return issues;
}

function mediaIssues(config) {
  const issues = [];
  if (!['image', 'video', 'audio', 'document'].includes(config.media_type)) {
    issues.push('Escolha imagem, vídeo, áudio ou documento.');
  }
  const url = config.url || '';
  if (!url) issues.push('Informe o link https da mídia.');
  else if (!/^(https:\/\/|\{\{)/.test(url)) {
    issues.push('O link da mídia precisa ser https.');
  }
  return issues;
}

const configIssues = (type, config) => {
  switch (type) {
    case 'send_message': {
      const hasText = Boolean((config.content || '').trim());
      const hasFiles =
        Array.isArray(config.attachments) &&
        config.attachments.some(item => item?.blob_id);
      return hasText || hasFiles
        ? []
        : ['Escreva a mensagem ou anexe um arquivo.'];
    }
    case 'send_whatsapp_template':
      return config.template_name ? [] : ['Selecione um template aprovado.'];
    case 'send_whatsapp_message': {
      const mode = config.delivery_mode || 'auto';
      if (mode === 'outside_24h' && !config.template_name) {
        return ['Selecione um template aprovado.'];
      }
      if (mode === 'inside_24h' && !config.text) {
        return ['A mensagem de texto não pode ficar vazia.'];
      }
      return [];
    }
    case 'send_whatsapp_buttons':
      return buttonIssues(config);
    case 'send_whatsapp_list':
      return listIssues(config);
    case 'send_whatsapp_media':
      return mediaIssues(config);
    case 'condition': {
      const rules = config.conditions || [];
      if (!rules.length) return ['Configure pelo menos uma regra.'];
      return rules.flatMap((rule, index) =>
        rule.field ? [] : [`Regra #${index + 1} está sem campo.`]
      );
    }
    case 'router': {
      const routes = config.routes || [];
      const names = routes.map(route => (route.name || '').trim());
      const issues = [];
      if (!routes.length) issues.push('Configure pelo menos uma rota.');
      if (names.some(name => !name))
        issues.push('Todas as rotas precisam de um nome.');
      if (new Set(names).size !== names.length)
        issues.push('Os nomes das rotas precisam ser únicos.');
      if (!config.source_variable)
        issues.push('Informe a variável de roteamento.');
      return issues;
    }
    case 'http_request':
    case 'send_webhook': {
      const url = config.url || '';
      if (!url) return ['A URL é obrigatória.'];
      if (!/^(https?:\/\/|\{\{)/.test(url))
        return ['A URL deve iniciar com http:// ou https://.'];
      return [];
    }
    case 'delay':
      return Number(config.duration) > 0
        ? []
        : ['A duração da espera deve ser um número positivo.'];
    case 'wait_for_reply':
      return Number(config.timeout_hours) > 0
        ? []
        : ['O tempo limite deve ser um número positivo.'];
    case 'set_variable':
      return VARIABLE_NAME_REGEX.test(config.variable_name || '')
        ? []
        : ['Informe um nome de variável válido (letras, números e _).'];
    case 'add_tag':
    case 'remove_tag':
      return config.tag_name ? [] : ['Informe o nome da tag.'];
    case 'update_custom_attribute':
      return config.attribute_key
        ? []
        : ['Informe a chave do atributo customizado.'];
    case 'assign_agent':
      return config.agent_id ? [] : ['Selecione um agente.'];
    case 'assign_team':
      return config.team_id ? [] : ['Selecione um time.'];
    default:
      return [];
  }
};

const pathIssues = (type, config, isValid) => {
  const paths = [];
  if (type === 'condition') {
    (config.conditions || []).forEach(rule => {
      if (rule.field) paths.push(rule.field);
    });
  }
  if (type === 'router' && config.source_variable) {
    paths.push(config.source_variable);
  }
  return paths
    .filter(path => !isValid(normalizeVariablePath(path)))
    .map(path => `Variável inválida: ${path}`);
};

const templateParamIssues = (config, templates) => {
  if (!config.template_name) return [];
  const template = templates.find(item => item.name === config.template_name);
  if (!template?.body) return [];
  const params = config.template_params || {};
  return [
    ...new Set(
      [...template.body.matchAll(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g)].map(
        match => match[1]
      )
    ),
  ]
    .filter(key => !params[key])
    .map(key => `Preencha a variável {{${key}}} do template.`);
};

export const validateWorkflow = ({ nodes, edges, isValid, templates = [] }) => {
  const issues = [];
  const add = (node, message) => {
    const title =
      node?.data?.config?.custom_title ||
      (node ? getNodeDefinition(node.data?.type).title : null);
    issues.push({
      nodeId: node?.id || null,
      message: title ? `${title}: ${message}` : message,
    });
  };

  if (!nodes.length) {
    add(null, 'O workflow deve possuir pelo menos um bloco.');
    return issues;
  }

  const triggers = nodes.filter(
    node => getNodeDefinition(node.data?.type).isTrigger
  );
  if (!triggers.length) add(null, 'O workflow deve possuir um gatilho.');
  triggers
    .slice(1)
    .forEach(node => add(node, 'Apenas um gatilho é permitido.'));

  const targets = new Set(edges.map(edge => edge.target));
  nodes.forEach(node => {
    const type = node.data?.type;
    const config = node.data?.config || {};
    const definition = getNodeDefinition(type);

    if (!definition.isTrigger && !targets.has(node.id)) {
      add(node, 'Bloco não está conectado ao fluxo.');
    }
    configIssues(type, config).forEach(message => add(node, message));
    if (
      type === 'send_whatsapp_template' ||
      (type === 'send_whatsapp_message' &&
        (config.delivery_mode || 'auto') !== 'inside_24h')
    ) {
      templateParamIssues(config, templates).forEach(message =>
        add(node, message)
      );
    }
    pathIssues(type, config, isValid).forEach(message => add(node, message));

    const {
      custom_title: _title,
      variable_mapping: _mapping,
      ...rest
    } = config;
    const badTokens = new Set(
      collectStrings(rest).flatMap(text => invalidTokens(text, isValid))
    );
    badTokens.forEach(token => add(node, `Variável inválida: ${token}`));
  });

  return issues;
};
