export const SAMPLE_TEMPLATE_VARIABLES = {
  1: 'Samuel',
  2: '7420',
  nome: 'Samuel',
  primeiro_nome: 'Samuel',
  nome_completo: 'Samuel Silva',
};

export function previewTemplateText(text, samples = SAMPLE_TEMPLATE_VARIABLES) {
  const source = text || '';
  return source.replace(/\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/g, (match, key) => {
    const value = samples[key] ?? samples[String(key).toLowerCase()];
    return value == null ? match : String(value);
  });
}

export function templateButtons(template) {
  if (!Array.isArray(template?.buttons)) return [];
  return template.buttons
    .map(button => button?.text || button?.title)
    .filter(Boolean);
}
