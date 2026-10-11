const TOKEN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g;
const NAMED_PARAM = /^[a-z][a-z0-9_]{0,19}$/;

const tokens = text => [...(text || '').matchAll(TOKEN)].map(match => match[1]);

const sampleFor = (variables, component, key) =>
  variables.find(
    item =>
      item.key === key && (!item.component || item.component === component)
  )?.sample_value;

const validateParameterText = (label, text, component, variables, errors) => {
  const stripped = (text || '').trim();
  if (/^\{\{/.test(stripped) || /\}\}\s*$/.test(stripped)) {
    errors.push(`A Meta não permite variável no início ou no fim do ${label}.`);
  }

  const found = tokens(text);
  if (!found.length) return;

  const numeric = found.filter(token => /^\d+$/.test(token));
  if (numeric.length && numeric.length !== found.length) {
    errors.push(`O ${label} não pode misturar variáveis nomeadas e numéricas.`);
    return;
  }

  if (numeric.length === found.length) {
    const numbers = found.map(token => Number(token));
    const expected = Array.from(
      { length: Math.max(...numbers) },
      (_, i) => i + 1
    );
    const sameOrder =
      numbers.length === expected.length &&
      numbers.every((value, index) => value === expected[index]);
    if (!sameOrder) {
      errors.push(
        `As variáveis do ${label} devem ser {{1}}, {{2}}... sem repetir e sem pular números.`
      );
    }
  } else {
    found.forEach(token => {
      if (!NAMED_PARAM.test(token)) {
        errors.push(
          `A variável {{${token}}} deve começar com letra minúscula e ter no máximo 20 caracteres.`
        );
      }
    });
    if (new Set(found).size !== found.length) {
      errors.push(`As variáveis do ${label} não podem se repetir.`);
    }
  }

  found
    .filter((token, index) => found.indexOf(token) === index)
    .forEach(token => {
      if (!sampleFor(variables, component, token)) {
        errors.push(`Informe um exemplo para {{${token}}}.`);
      }
    });
};

const mediaSampleIssue = (url, requirePublicSample) => {
  if (!url) return 'Envie um arquivo para o armazenamento do Chatwoot.';
  if (!/^https?:\/\//i.test(url)) {
    return 'O arquivo precisa estar no armazenamento do Chatwoot.';
  }
  if (requirePublicSample && !/^https:\/\//i.test(url)) {
    return 'Para enviar à Meta, o arquivo salvo no Chatwoot precisa de um endereço https público.';
  }
  return '';
};

export const validateMetaTemplate = (template, options = {}) => {
  const requirePublicSample = options.requirePublicSample !== false;
  const errors = [];
  const variables = template.variables || [];
  const category =
    template.category === 'MARKETING_LITE' ? 'MARKETING' : template.category;
  if (!['MARKETING', 'UTILITY', 'AUTHENTICATION'].includes(category)) {
    errors.push(
      'Categoria inválida para a Meta. Use Marketing, Marketing Lite ou Utilidade.'
    );
  }

  if (!template.body) {
    errors.push('O corpo da mensagem é obrigatório.');
  } else {
    if (template.body.length > 1024) {
      errors.push('O corpo da mensagem pode ter no máximo 1024 caracteres.');
    }
    validateParameterText('corpo', template.body, 'body', variables, errors);
  }

  const headerType = template.header_type || 'NONE';
  if (headerType === 'TEXT') {
    const text = template.header_content || '';
    if (!text) errors.push('Informe o texto do cabeçalho ou escolha Nenhum.');
    if (text.length > 60) {
      errors.push('O cabeçalho de texto pode ter no máximo 60 caracteres.');
    }
    if (tokens(text).length > 1) {
      errors.push('O cabeçalho de texto aceita no máximo uma variável.');
    }
    validateParameterText('cabeçalho', text, 'header', variables, errors);
  } else if (['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerType)) {
    const mediaIssue = mediaSampleIssue(
      template.header_content || '',
      requirePublicSample
    );
    if (mediaIssue) errors.push(mediaIssue);
  }

  if (template.footer) {
    if (template.footer.length > 60) {
      errors.push('O rodapé pode ter no máximo 60 caracteres.');
    }
    if (tokens(template.footer).length) {
      errors.push('A Meta não permite variáveis no rodapé.');
    }
  }

  const buttons = template.buttons || [];
  if (buttons.length > 10) errors.push('A Meta permite no máximo 10 botões.');
  buttons.forEach((button, index) => {
    const position = index + 1;
    const text = (button.text || '').trim();
    if (!text || text.length > 25) {
      errors.push(`Botão ${position}: informe o texto (máximo 25 caracteres).`);
    }
    if (button.type === 'URL') {
      if (!/^https:\/\//i.test(button.url || '')) {
        errors.push(`Botão ${position}: a URL deve começar com https://.`);
      }
      const urlTokens = tokens(button.url);
      if (
        urlTokens.length &&
        (urlTokens.join() !== '1' || !/\{\{\s*1\s*\}\}$/.test(button.url || ''))
      ) {
        errors.push(
          `Botão ${position}: a URL aceita só a variável {{1}} no final.`
        );
      }
    } else if (button.type === 'PHONE_NUMBER') {
      const phone = (button.phone_number || '').replace(/[^\d+]/g, '');
      if (!/^\+?[1-9]\d{7,14}$/.test(phone)) {
        errors.push(
          `Botão ${position}: informe o telefone com código do país.`
        );
      }
    } else if (button.type !== 'QUICK_REPLY') {
      errors.push(`Botão ${position}: tipo inválido.`);
    }
  });

  return errors;
};

export const templateVariables = (headerType, headerContent, body, samples) => {
  const items = [];
  const push = (component, text) => {
    tokens(text).forEach(key => {
      if (
        items.some(item => item.component === component && item.key === key)
      ) {
        return;
      }
      items.push({
        key,
        name: key,
        component,
        sample_value: samples[`${component}:${key}`] || '',
      });
    });
  };
  if (headerType === 'TEXT') push('header', headerContent);
  push('body', body);
  return items;
};
