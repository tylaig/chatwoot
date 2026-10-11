export const IDENTITY_FIELDS = [
  {
    key: 'phone_path',
    focus: 'phone',
    label: 'Telefone',
    placeholder: 'customer.phone',
  },
  {
    key: 'name_path',
    focus: 'name',
    label: 'Nome',
    placeholder: 'customer.name',
  },
  {
    key: 'email_path',
    focus: 'email',
    label: 'E-mail',
    placeholder: 'customer.email',
  },
  {
    key: 'identifier_path',
    focus: 'identifier',
    label: 'Identificador',
    placeholder: 'customer.id',
  },
  {
    key: 'labels_path',
    focus: 'labels',
    label: 'Etiquetas',
    placeholder: 'order.tags',
  },
];

export const sampleFor = (fields, path) =>
  fields.find(field => field.path === path)?.sample;

const isBranchSample = sample => ['{…}', '[…]'].includes(sample);

export const coerceSample = (displayType, sample) => {
  if (sample == null || sample === '' || isBranchSample(sample)) return '';
  if (['number', 'currency', 'percent'].includes(displayType)) {
    const number = Number(String(sample).replace(',', '.'));
    return Number.isFinite(number) ? String(number) : 'não é um número';
  }
  if (displayType === 'checkbox') {
    return /^(1|true|sim|yes)$/i.test(String(sample)) ? 'sim' : 'não';
  }
  return String(sample);
};

const pathWarning = (path, fields) => {
  if (!path || !fields.length) return '';
  const sample = sampleFor(fields, path);
  if (sample == null) return `O caminho ${path} não está no JSON de exemplo.`;
  if (isBranchSample(sample)) {
    return `O caminho ${path} aponta para um objeto ou lista. Escolha um valor.`;
  }
  if (!String(sample).trim()) return `O caminho ${path} veio vazio no exemplo.`;
  return '';
};

export const mappingWarnings = ({ mapping = {}, fields = [] }) => {
  const warnings = [];
  if (!mapping.phone_path && !mapping.email_path && !mapping.identifier_path) {
    warnings.push(
      'Mapeie telefone, e-mail ou identificador para achar o contato.'
    );
  }
  IDENTITY_FIELDS.forEach(field => {
    if (field.key === 'labels_path' && mapping.labels_path) {
      const sample = sampleFor(fields, mapping.labels_path);
      if (fields.length && sample == null) {
        warnings.push(
          `O caminho ${mapping.labels_path} não está no JSON de exemplo.`
        );
      } else if (sample === '{…}') {
        warnings.push(
          `O caminho ${mapping.labels_path} aponta para um objeto. Escolha a lista de etiquetas.`
        );
      }
      return;
    }
    const warning = pathWarning(mapping[field.key], fields);
    if (warning) warnings.push(warning);
  });

  ['custom_attributes', 'conversation_attributes'].forEach(listKey => {
    const seen = new Set();
    (mapping[listKey] || []).forEach(row => {
      const key = row.attribute_key;
      if (key && seen.has(key)) {
        warnings.push(`O atributo ${key} está mapeado mais de uma vez.`);
      }
      if (key) seen.add(key);
      const warning = pathWarning(row.source_path, fields);
      if (warning) warnings.push(warning);
    });
  });

  return [...new Set(warnings)];
};

const assignPath = (body, path, value) => {
  if (!path) return;
  const parts = String(path).split('.').filter(Boolean);
  let cursor = body;
  parts.forEach((part, index) => {
    if (index === parts.length - 1) {
      cursor[part] = value;
      return;
    }
    if (!cursor[part] || typeof cursor[part] !== 'object') cursor[part] = {};
    cursor = cursor[part];
  });
};

export const curlExample = (url, mapping = {}) => {
  const body = {};
  assignPath(body, mapping.phone_path, '5511999990000');
  assignPath(body, mapping.name_path, 'Maria');
  assignPath(body, mapping.email_path, 'maria@example.com');
  assignPath(body, mapping.identifier_path, 'cus_123');
  assignPath(body, mapping.labels_path, 'vip, pedido');
  const json = JSON.stringify(
    Object.keys(body).length
      ? body
      : { customer: { phone: '5511999990000', name: 'Maria' } }
  );
  return `curl -X POST ${url} \\\n  -H "Content-Type: application/json" \\\n  -d '${json}'`;
};
