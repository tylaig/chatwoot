<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import WhatsAppPhonePreview from './WhatsAppPhonePreview.vue';
import whatsappTemplatesApi from 'dashboard/api/whatsappTemplates';

const router = useRouter();

const currentStep = ref(1); // 1 = Selecionar categoria, 2 = Configurar modelo
const isSubmitting = ref(false);

const form = ref({
  category: 'MARKETING_LITE',
  name: '',
  language: 'pt_BR',
  header_type: 'NONE', // NONE, TEXT, IMAGE, VIDEO, DOCUMENT
  header_content: '',
  body: '',
  footer: '',
  validity_hours: 24,
  buttons: [],
});

const isVariableMenuOpen = ref(false);
const variableSearch = ref('');
const textareaRef = ref(null);

const systemVariables = [
  { key: 'nome_completo', label: 'nome-completo', desc: 'Nome completo do contato' },
  { key: 'primeiro_nome', label: 'primeiro-nome', desc: 'Primeiro nome' },
  { key: 'sobrenome', label: 'sobrenome', desc: 'Sobrenome' },
  { key: 'telefone', label: 'telefone', desc: 'Número de telefone' },
  { key: 'ddd', label: 'ddd', desc: 'DDD / código de área' },
  { key: 'nome_indicador', label: 'nome-indicador', desc: 'Nome do indicador / vendedor' },
  { key: 'link_pedido', label: 'link-pedido', desc: 'URL de rastreamento / pedido' },
  { key: 'valor_total', label: 'valor-total', desc: 'Valor total do pedido' },
  { key: 'codigo_rastreio', label: 'codigo-rastreio', desc: 'Código de rastreamento' },
  { key: 'nome_produto', label: 'nome-produto', desc: 'Nome do jogo / produto' },
];

const filteredVariables = computed(() => {
  const q = variableSearch.value.toLowerCase().trim();
  if (!q) return systemVariables;
  return systemVariables.filter(v => v.label.toLowerCase().includes(q) || v.desc.toLowerCase().includes(q));
});

const categories = [
  {
    id: 'MARKETING_LITE',
    title: 'Marketing Lite',
    badge: 'Recomendado',
    icon: '🚀',
    description: 'Envie mensagens de marketing com maior alcance e limites flexíveis. Até 10% mais barato e entrega até 9% mais mensagens.',
  },
  {
    id: 'MARKETING',
    title: 'Marketing',
    badge: null,
    icon: '📢',
    description: 'Promova sua marca por meio de ofertas e campanhas. Ideal para reengajamento, upselling e aumento de conversões.',
  },
  {
    id: 'UTILITY',
    title: 'Utilidade',
    badge: null,
    icon: '🔔',
    description: 'Mantenha os clientes informados com atualizações essenciais. Use para lembretes, confirmações e outras mensagens não promocionais.',
  },
];

const languages = [
  { value: 'pt_BR', label: 'Português (Brasil)' },
  { value: 'en_US', label: 'Inglês (Estados Unidos)' },
  { value: 'es', label: 'Espanhol' },
];

const headerOptions = [
  { id: 'NONE', label: 'Sem Cabeçalho', icon: 'i-lucide-minus' },
  { id: 'TEXT', label: 'Título', icon: 'i-lucide-file-text' },
  { id: 'IMAGE', label: 'Imagem', icon: 'i-lucide-image' },
  { id: 'VIDEO', label: 'Vídeo', icon: 'i-lucide-video' },
  { id: 'DOCUMENT', label: 'Arquivo', icon: 'i-lucide-paperclip' },
];

const bodyLength = computed(() => form.value.body.length);
const footerLength = computed(() => (form.value.footer || '').length);

const isStep1Valid = computed(() => !!form.value.category);
const isStep2Valid = computed(() => {
  const nameClean = form.value.name.trim();
  const hasValidName = /^[a-z0-9_]+$/.test(nameClean);
  const hasBody = form.value.body.trim().length > 0 && form.value.body.length <= 1024;
  return hasValidName && hasBody;
});

const selectCategory = (id) => {
  form.value.category = id;
};

const goToStep2 = () => {
  if (isStep1Valid.value) {
    currentStep.value = 2;
  }
};

const goToStep1 = () => {
  currentStep.value = 1;
};

const sanitizeName = () => {
  form.value.name = form.value.name
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
};

const setHeaderType = (type) => {
  form.value.header_type = type;
  if (type === 'NONE') {
    form.value.header_content = '';
  }
};

const applyFormat = (wrapper) => {
  const textarea = textareaRef.value;
  if (!textarea) return;

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const selectedText = form.value.body.substring(start, end);

  const replacement = `${wrapper}${selectedText || 'texto'}${wrapper}`;
  form.value.body = form.value.body.substring(0, start) + replacement + form.value.body.substring(end);

  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(start + wrapper.length, end + wrapper.length);
  }, 50);
};

const insertVariable = (varKey) => {
  const textarea = textareaRef.value;
  const placeholder = `{{${varKey}}}`;

  if (!textarea) {
    form.value.body += placeholder;
    isVariableMenuOpen.value = false;
    return;
  }

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  form.value.body = form.value.body.substring(0, start) + placeholder + form.value.body.substring(end);
  isVariableMenuOpen.value = false;

  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(start + placeholder.length, start + placeholder.length);
  }, 50);
};

const addButton = () => {
  if (form.value.buttons.length >= 3) {
    useAlert('O WhatsApp permite até 3 botões rápidos ou de ação.');
    return;
  }
  form.value.buttons.push({
    type: 'URL',
    text: '',
    url: 'https://gamessafari.com',
  });
};

const removeButton = (index) => {
  form.value.buttons.splice(index, 1);
};

const submitTemplate = async (status = 'PENDING') => {
  if (!isStep2Valid.value) {
    useAlert('Preencha os campos obrigatórios corretamente (nome sem caracteres especiais e corpo da mensagem).');
    return;
  }

  isSubmitting.value = true;
  try {
    const payload = {
      ...form.value,
      status: status,
    };
    await whatsappTemplatesApi.createTemplate(payload);
    useAlert(status === 'APPROVED' ? 'Template aprovado e salvo com sucesso!' : 'Template enviado para revisão da Meta!');
    router.push({ name: 'whatsapp_templates_index' });
  } catch (err) {
    const errorMsg = err.response?.data?.error || 'Erro ao processar template.';
    useAlert(Array.isArray(errorMsg) ? errorMsg.join(', ') : errorMsg);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex-1 flex flex-col bg-slate-50 dark:bg-slate-900 min-h-screen">
    <!-- Top Step Bar Header -->
    <div class="border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 px-8 py-4">
      <div class="max-w-6xl mx-auto flex items-center justify-between">
        <div class="flex items-center gap-6">
          <!-- Step 1 Indicator -->
          <div
            class="flex items-center gap-2 cursor-pointer select-none"
            :class="currentStep === 1 ? 'text-primary-600 font-bold' : 'text-slate-500'"
            @click="currentStep = 1"
          >
            <div
              class="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
              :class="currentStep > 1 ? 'bg-emerald-500 text-white' : currentStep === 1 ? 'bg-primary-600 text-white' : 'bg-slate-200 text-slate-700'"
            >
              <span v-if="currentStep > 1">✓</span>
              <span v-else>1</span>
            </div>
            <span class="text-sm">Selecionar categoria</span>
          </div>

          <div class="w-8 h-[2px] bg-slate-200 dark:bg-slate-700" />

          <!-- Step 2 Indicator -->
          <div
            class="flex items-center gap-2 select-none"
            :class="currentStep === 2 ? 'text-primary-600 font-bold' : 'text-slate-400'"
          >
            <div
              class="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
              :class="currentStep === 2 ? 'bg-primary-600 text-white' : 'bg-slate-200 dark:bg-slate-800 text-slate-500'"
            >
              2
            </div>
            <span class="text-sm">Configurar modelo</span>
          </div>
        </div>

        <button
          type="button"
          class="text-xs text-slate-500 hover:text-slate-800 dark:hover:text-slate-200"
          @click="$router.push({ name: 'whatsapp_templates_index' })"
        >
          Cancelar e Voltar
        </button>
      </div>
    </div>

    <!-- Main Container -->
    <div class="flex-1 max-w-6xl w-full mx-auto p-6 md:p-8">
      <!-- ETAPA 1: SELECIONAR CATEGORIA -->
      <div v-if="currentStep === 1" class="space-y-6">
        <div>
          <h2 class="text-xl font-bold text-slate-900 dark:text-white">Categoria</h2>
          <p class="text-sm text-slate-500 mt-1">
            Escolha o tipo de modelo que melhor se adapta à sua mensagem.
            <a href="https://business.facebook.com/latest/whatsapp_manager/message_templates" target="_blank" class="text-primary-600 hover:underline">
              Saiba mais
            </a>
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            v-for="cat in categories"
            :key="cat.id"
            class="relative flex items-start gap-4 p-5 rounded-2xl border-2 transition-all cursor-pointer bg-white dark:bg-slate-800"
            :class="form.category === cat.id ? 'border-primary-500 shadow-md ring-2 ring-primary-500/20' : 'border-slate-200 dark:border-slate-700/80 hover:border-slate-300'"
            @click="selectCategory(cat.id)"
          >
            <div class="text-2xl p-2 rounded-xl bg-slate-100 dark:bg-slate-700/50 shrink-0">
              {{ cat.icon }}
            </div>

            <div class="flex-1 pr-6">
              <div class="flex items-center gap-2">
                <span class="font-bold text-slate-900 dark:text-white">{{ cat.title }}</span>
                <span
                  v-if="cat.badge"
                  class="px-2 py-0.5 text-[11px] font-semibold rounded-md bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300"
                >
                  {{ cat.badge }}
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1.5 leading-relaxed">
                {{ cat.description }}
              </p>
            </div>

            <!-- Radio Button Circle -->
            <div class="absolute top-5 right-5">
              <div
                class="w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors"
                :class="form.category === cat.id ? 'border-primary-600 bg-primary-600' : 'border-slate-300 dark:border-slate-600'"
              >
                <div v-if="form.category === cat.id" class="w-2 h-2 rounded-full bg-white" />
              </div>
            </div>
          </div>
        </div>

        <!-- Bottom Action Bar Step 1 -->
        <div class="flex items-center justify-between pt-8 border-t border-slate-200 dark:border-slate-800">
          <button
            type="button"
            class="px-5 py-2.5 rounded-xl border border-slate-300 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-medium text-sm hover:bg-slate-100 dark:hover:bg-slate-800"
            @click="$router.push({ name: 'whatsapp_templates_index' })"
          >
            Concluído
          </button>

          <button
            type="button"
            class="px-6 py-2.5 rounded-xl bg-primary-600 hover:bg-primary-700 text-white font-semibold text-sm shadow-md transition-all flex items-center gap-2"
            :disabled="!isStep1Valid"
            @click="goToStep2"
          >
            <span>Próximo</span>
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>

      <!-- ETAPA 2: CONFIGURAR MODELO COM PREVIEW EM TEMPO REAL -->
      <div v-else class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        <!-- Coluna Esquerda: Formulário de Configuração (7 colunas) -->
        <div class="lg:col-span-7 space-y-6">
          <!-- Card de Cabeçalho e Identificação -->
          <div class="p-6 rounded-2xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/80 shadow-sm space-y-4">
            <div>
              <h3 class="text-base font-bold text-slate-900 dark:text-white">
                Modelo {{ form.category === 'UTILITY' ? 'Utilitário' : form.category === 'MARKETING_LITE' ? 'Marketing Lite' : 'Marketing' }}
              </h3>
              <p class="text-xs text-slate-500 mt-0.5">
                Novos modelos devem ser aprovados pela Meta. Normalmente leva até 24 horas.
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Nome do Modelo *
                </label>
                <input
                  v-model="form.name"
                  type="text"
                  placeholder="ex: atualizacao_pedido_games_safari"
                  class="w-full px-3.5 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:outline-none"
                  @input="sanitizeName"
                />
                <span class="block text-[11px] text-slate-400 mt-1">
                  Somente letras minúsculas, números e underline (_)
                </span>
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Idioma *
                </label>
                <select
                  v-model="form.language"
                  class="w-full px-3.5 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:outline-none"
                >
                  <option v-for="lang in languages" :key="lang.value" :value="lang.value">
                    {{ lang.label }}
                  </option>
                </select>
              </div>
            </div>
          </div>

          <!-- Card de Conteúdo: Cabeçalho, Corpo, Rodapé -->
          <div class="p-6 rounded-2xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/80 shadow-sm space-y-5">
            <div>
              <h3 class="text-base font-bold text-slate-900 dark:text-white">Conteúdo</h3>
              <p class="text-xs text-slate-500 mt-0.5">
                Para engajar os clientes de forma eficaz e reduzir o risco de bloqueio, siga a
                <a href="https://business.facebook.com/policies/whatsapp_business_messaging" target="_blank" class="text-primary-600 hover:underline">
                  Política de Mensagens do WhatsApp Business
                </a>
              </p>
            </div>

            <!-- Seção de Cabeçalho Opcional -->
            <div>
              <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-2">
                Cabeçalho (Opcional)
              </label>
              <div class="grid grid-cols-5 gap-2">
                <button
                  v-for="hdr in headerOptions"
                  :key="hdr.id"
                  type="button"
                  class="flex items-center justify-center gap-1.5 py-2 px-2 rounded-xl text-xs font-medium border transition-colors"
                  :class="form.header_type === hdr.id ? 'border-primary-500 bg-primary-50 text-primary-700 dark:bg-primary-950 dark:text-primary-300 font-bold' : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-900 text-slate-600 dark:text-slate-300'"
                  @click="setHeaderType(hdr.id)"
                >
                  <span class="truncate">{{ hdr.label }}</span>
                </button>
              </div>

              <!-- Input complementar do Cabeçalho -->
              <div v-if="form.header_type !== 'NONE'" class="mt-3">
                <input
                  v-if="form.header_type === 'TEXT'"
                  v-model="form.header_content"
                  type="text"
                  placeholder="Texto do título do cabeçalho (máx 60 caracteres)"
                  maxlength="60"
                  class="w-full px-3.5 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:outline-none"
                />
                <input
                  v-else
                  v-model="form.header_content"
                  type="url"
                  :placeholder="`URL pública de exemplo da ${form.header_type.toLowerCase()} (ex: https://gamessafari.com/...jpg)`"
                  class="w-full px-3.5 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:outline-none"
                />
              </div>
            </div>

            <!-- Seção de Corpo da Mensagem (com Toolbar rica) -->
            <div>
              <div class="flex items-center justify-between mb-1.5">
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                  Corpo da Mensagem *
                </label>
                <span class="text-xs" :class="bodyLength > 1024 ? 'text-rose-500 font-bold' : 'text-slate-400'">
                  {{ bodyLength }}/1024
                </span>
              </div>

              <div class="rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 overflow-hidden focus-within:ring-2 focus-within:ring-primary-500">
                <textarea
                  ref="textareaRef"
                  v-model="form.body"
                  rows="6"
                  maxlength="1024"
                  placeholder="Olá {{primeiro_nome}}, seu pedido na Games Safari foi recebido com sucesso!"
                  class="w-full p-4 bg-transparent border-0 text-sm text-slate-900 dark:text-white focus:ring-0 focus:outline-none resize-none leading-relaxed"
                />

                <!-- Toolbar Inferior do Editor -->
                <div class="relative flex items-center justify-between px-3 py-2 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-950">
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      title="Negrito (*texto*)"
                      class="w-8 h-8 rounded-lg flex items-center justify-center font-bold text-sm text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
                      @click="applyFormat('*')"
                    >
                      B
                    </button>
                    <button
                      type="button"
                      title="Itálico (_texto_)"
                      class="w-8 h-8 rounded-lg flex items-center justify-center italic text-sm text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800 font-serif"
                      @click="applyFormat('_')"
                    >
                      I
                    </button>
                    <button
                      type="button"
                      title="Tachado (~texto~)"
                      class="w-8 h-8 rounded-lg flex items-center justify-center line-through text-sm text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
                      @click="applyFormat('~')"
                    >
                      S
                    </button>

                    <!-- Inserção de Campos Dinâmicos do Sistema -->
                    <div class="relative">
                      <button
                        type="button"
                        title="Inserir Campos do Sistema / Variáveis"
                        class="px-2.5 h-8 rounded-lg flex items-center gap-1 font-mono text-xs font-semibold text-primary-600 bg-primary-50 dark:bg-primary-950 hover:bg-primary-100 dark:hover:bg-primary-900 transition-colors"
                        @click="isVariableMenuOpen = !isVariableMenuOpen"
                      >
                        <span>{ }</span>
                        <span class="text-[11px]">Variável</span>
                      </button>

                      <!-- Popover de Variáveis do Sistema -->
                      <div
                        v-if="isVariableMenuOpen"
                        class="absolute bottom-10 left-0 w-64 rounded-2xl bg-white dark:bg-slate-800 shadow-2xl border border-slate-200 dark:border-slate-700 p-2 z-50 animate-in fade-in slide-in-from-bottom-2"
                      >
                        <div class="p-1 border-b border-slate-100 dark:border-slate-700/80 mb-2">
                          <p class="text-xs font-bold text-slate-700 dark:text-slate-200">Campos do Sistema</p>
                          <input
                            v-model="variableSearch"
                            type="text"
                            placeholder="Buscar campos..."
                            class="w-full mt-1 px-2.5 py-1 text-xs rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 focus:outline-none focus:ring-1 focus:ring-primary-500"
                          />
                        </div>

                        <div class="max-h-48 overflow-y-auto space-y-1">
                          <button
                            v-for="v in filteredVariables"
                            :key="v.key"
                            type="button"
                            class="w-full flex items-center justify-between px-2 py-1.5 rounded-lg text-left hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                            @click="insertVariable(v.key)"
                          >
                            <span class="text-xs font-mono font-medium text-slate-800 dark:text-slate-200">
                              {{ v.label }}
                            </span>
                            <span class="text-[10px] text-slate-400">Inserir</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Seção de Rodapé Opcional -->
            <div>
              <div class="flex items-center justify-between mb-1.5">
                <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                  Rodapé (Opcional)
                </label>
                <span class="text-xs text-slate-400">{{ footerLength }}/60</span>
              </div>
              <input
                v-model="form.footer"
                type="text"
                maxlength="60"
                placeholder="ex: Para não receber mais promoções, responda PARAR"
                class="w-full px-3.5 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary-500 focus:outline-none"
              />
            </div>

            <!-- Seção de Botões de Ação -->
            <div class="pt-2 border-t border-slate-100 dark:border-slate-800">
              <div class="flex items-center justify-between mb-2">
                <div>
                  <h4 class="text-xs font-semibold text-slate-700 dark:text-slate-300">
                    Botões de Ação (Opcional)
                  </h4>
                  <p class="text-[11px] text-slate-400">
                    Você pode adicionar até 3 botões (Links externos ou Respostas Rápidas).
                  </p>
                </div>
                <button
                  type="button"
                  class="px-3 py-1.5 text-xs font-semibold rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-800 dark:text-slate-200"
                  :disabled="form.buttons.length >= 3"
                  @click="addButton"
                >
                  + Adicionar botão
                </button>
              </div>

              <!-- Lista de Botões Adicionados -->
              <div class="space-y-2 mt-2">
                <div
                  v-for="(btn, idx) in form.buttons"
                  :key="idx"
                  class="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50"
                >
                  <select
                    v-model="btn.type"
                    class="px-2 py-1 rounded-lg text-xs border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-800 dark:text-white"
                  >
                    <option value="URL">Link (URL)</option>
                    <option value="QUICK_REPLY">Resposta Rápida</option>
                    <option value="PHONE_NUMBER">Ligar para Número</option>
                  </select>

                  <input
                    v-model="btn.text"
                    type="text"
                    placeholder="Texto do Botão (ex: Ver Pedido)"
                    class="flex-1 px-3 py-1 rounded-lg text-xs border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-800 dark:text-white"
                  />

                  <input
                    v-if="btn.type === 'URL'"
                    v-model="btn.url"
                    type="url"
                    placeholder="https://gamessafari.com"
                    class="flex-1 px-3 py-1 rounded-lg text-xs border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-800 dark:text-white"
                  />

                  <button
                    type="button"
                    class="p-1 text-slate-400 hover:text-rose-500"
                    @click="removeButton(idx)"
                  >
                    ✕
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Bottom Action Bar Step 2 -->
          <div class="flex items-center justify-between pt-6 border-t border-slate-200 dark:border-slate-800">
            <div class="flex items-center gap-3">
              <button
                type="button"
                class="px-5 py-2.5 rounded-xl border border-slate-300 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-medium text-sm hover:bg-slate-100 dark:hover:bg-slate-800 flex items-center gap-1.5"
                @click="goToStep1"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
                <span>Anterior</span>
              </button>

              <span class="text-xs text-slate-400 italic">
                A edição não estará disponível durante a revisão
              </span>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                class="px-4 py-2.5 rounded-xl border border-emerald-600 text-emerald-600 dark:text-emerald-400 font-semibold text-sm hover:bg-emerald-50 dark:hover:bg-emerald-950 transition-colors"
                :disabled="isSubmitting || !isStep2Valid"
                @click="submitTemplate('APPROVED')"
              >
                Aprovar Direto
              </button>

              <button
                type="button"
                class="px-6 py-2.5 rounded-xl bg-primary-600 hover:bg-primary-700 text-white font-semibold text-sm shadow-md transition-all flex items-center gap-2"
                :disabled="isSubmitting || !isStep2Valid"
                @click="submitTemplate('PENDING')"
              >
                <span v-if="isSubmitting">Enviando...</span>
                <span v-else>Enviar para revisão</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Coluna Direita: Preview em Tempo Real no Smartphone (5 colunas) -->
        <div class="lg:col-span-5 sticky top-8 flex flex-col items-center">
          <div class="w-full flex items-center justify-between mb-3 px-2">
            <span class="text-xs font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
              Preview em Tempo Real
            </span>
            <span class="text-[11px] px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 font-medium">
              Simulador WhatsApp
            </span>
          </div>

          <WhatsAppPhonePreview
            :template="form"
            contact-name="Games Safari Oficial"
            avatar-url="https://gamessafari.com/cdn/shop/files/logo_png_sem_controle.png"
          />
        </div>
      </div>
    </div>
  </div>
</template>
