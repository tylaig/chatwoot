import {
  buildVariableCatalog,
  formatVariable,
  invalidTokens,
  normalizeVariablePath,
  tokenizeTemplate,
} from '../variables';
import { validateWorkflow } from '../workflowValidation';

const node = (id, type, config = {}) => ({ id, data: { type, config } });

describe('workflow variables', () => {
  it('formats and normalizes n8n style tokens', () => {
    expect(formatVariable('contact.name')).toBe('{{ $contact.name }}');
    expect(normalizeVariablePath('{{ $contact.name }}')).toBe('contact.name');
    expect(normalizeVariablePath('contact.name')).toBe('contact.name');
  });

  it('accepts any webhook path until a sample payload is captured', () => {
    const { isValid } = buildVariableCatalog({});
    expect(isValid('webhook.anything.here')).toBe(true);
  });

  it('validates webhook paths against the captured sample payload', () => {
    const { isValid, groups } = buildVariableCatalog({
      samplePayload: {
        customer: { phone: '5511999999999' },
        items: [{ sku: 'A1' }],
      },
    });
    const webhookPaths = groups
      .find(group => group.id === 'webhook')
      .items.map(item => item.path);

    expect(webhookPaths).toContain('webhook.customer.phone');
    expect(isValid('$webhook.customer.phone')).toBe(true);
    expect(isValid('payload.customer.phone')).toBe(true);
    expect(isValid('webhook.customer.email')).toBe(false);
    expect(isValid('webhook.items.0.sku')).toBe(true);
    expect(isValid('webhook.items.1.sku')).toBe(true);
  });

  it('only accepts flow variables declared by blocks', () => {
    const { isValid } = buildVariableCatalog({
      nodes: [
        node('a', 'set_variable', { variable_name: 'coupon' }),
        node('b', 'http_request', { save_response_as: 'crm' }),
      ],
    });

    expect(isValid('vars.coupon')).toBe(true);
    expect(isValid('vars.crm.body.id')).toBe(true);
    expect(isValid('vars.unknown')).toBe(false);
  });

  it('marks unknown roots and malformed paths as invalid', () => {
    const { isValid } = buildVariableCatalog({});
    expect(isValid('contact.name')).toBe(true);
    expect(isValid('contact.custom_attributes.plan')).toBe(true);
    expect(isValid('contact.nickname')).toBe(false);
    expect(isValid('foo.bar')).toBe(false);
    expect(isValid('contact name')).toBe(false);
  });

  it('tokenizes text and flags only invalid variables', () => {
    const { isValid } = buildVariableCatalog({});
    const text = 'Oi {{ $contact.name }} {{1}} {{ $foo.bar }}';
    const segments = tokenizeTemplate(text, isValid);

    expect(segments.filter(s => s.type === 'variable')).toEqual([
      { text: '{{ $contact.name }}', type: 'variable', valid: true },
      { text: '{{1}}', type: 'variable', valid: true },
      { text: '{{ $foo.bar }}', type: 'variable', valid: false },
    ]);
    expect(invalidTokens(text, isValid)).toEqual(['{{ $foo.bar }}']);
  });
});

describe('validateWorkflow', () => {
  const trigger = node('t', 'webhook_trigger');

  it('requires a trigger', () => {
    const { isValid } = buildVariableCatalog({});
    const issues = validateWorkflow({ nodes: [], edges: [], isValid });
    expect(issues).toHaveLength(1);
  });

  it('reports orphan blocks, missing config and invalid variables', () => {
    const nodes = [
      trigger,
      node('m', 'send_message', { content: 'Oi {{ $foo.bar }}' }),
      node('d', 'delay', { duration: 0 }),
    ];
    const { isValid } = buildVariableCatalog({ nodes });
    const issues = validateWorkflow({
      nodes,
      edges: [{ id: 'e1', source: 't', target: 'm' }],
      isValid,
    });
    const messagesFor = id =>
      issues.filter(issue => issue.nodeId === id).map(i => i.message);

    expect(messagesFor('m').join()).toContain('Variável inválida');
    expect(messagesFor('d').join()).toContain('não está conectado');
    expect(messagesFor('d').join()).toContain('duração');
  });

  it('returns no issues for a valid connected flow', () => {
    const nodes = [
      trigger,
      node('m', 'send_message', { content: 'Oi {{ $contact.name }}' }),
    ];
    const { isValid } = buildVariableCatalog({ nodes });
    expect(
      validateWorkflow({
        nodes,
        edges: [{ id: 'e1', source: 't', target: 'm' }],
        isValid,
      })
    ).toEqual([]);
  });
});
