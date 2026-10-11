<script setup>
import { ref, computed, onMounted } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import WhatsAppPhonePreview from './WhatsAppPhonePreview.vue';
import whatsappTemplatesApi from 'dashboard/api/whatsappTemplates';
import { templateVariables, validateMetaTemplate } from './metaTemplate';

const route = useRoute();
const router = useRouter();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

const templateId = computed(() => route.params.templateId);
const isEditing = computed(() => Boolean(templateId.value));
const existingStatus = ref('APPROVED');
const currentStep = ref(1);
const isSubmitting = ref(false);
const isLoadingTemplate = ref(false);

const form = ref({
  category: 'MARKETING_LITE',
  name: '',
  language: 'pt_BR',
  header_type: 'NONE', // NONE, TEXT, IMAGE, VIDEO, DOCUMENT
  header_content: '',
  header_media_name: '',
  body: '',
  footer: '',
  validity_hours: 24,
  buttons: [],
});

const isVariableMenuOpen = ref(false);
const variableSearch = ref('');
const textareaRef = ref(null);
const fileInput = ref(null);
const isUploading = ref(false);
const headerMediaSignedId = ref('');
const sampleValues = ref({});
const MEDIA_ACCEPT = {
  IMAGE: 'image/jpeg,image/png',
  VIDEO: 'video/mp4',
  DOCUMENT: 'application/pdf',
};
const MEDIA_LIMIT_MB = { IMAGE: 5, VIDEO: 16, DOCUMENT: 100 };
const FIELD_CLASS =
  'reset-base w-full h-10 m-0 px-3 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10';
const LABEL_CLASS = 'block text-xs font-medium text-n-slate-11 mb-1.5';

const systemVariables = [
  {
    key: 'nome_completo',
    label: 'nome-completo',
    desc: 'Nome completo do contato',
  },
  { key: 'primeiro_nome', label: 'primeiro-nome', desc: 'Primeiro nome' },
  { key: 'sobrenome', label: 'sobrenome', desc: 'Sobrenome' },
  { key: 'telefone', label: 'telefone', desc: 'Número de telefone' },
  { key: 'ddd', label: 'ddd', desc: 'DDD / código de área' },
  {
    key: 'nome_indicador',
    label: 'nome-indicador',
    desc: 'Nome do indicador / vendedor',
  },
  {
    key: 'link_pedido',
    label: 'link-pedido',
    desc: 'URL de rastreamento / pedido',
  },
  { key: 'valor_total', label: 'valor-total', desc: 'Valor total do pedido' },
  {
    key: 'codigo_rastreio',
    label: 'codigo-rastreio',
    desc: 'Código de rastreamento',
  },
  {
    key: 'nome_produto',
    label: 'nome-produto',
    desc: 'Nome do jogo / produto',
  },
];

const filteredVariables = computed(() => {
  const q = variableSearch.value.toLowerCase().trim();
  if (!q) return systemVariables;
  return systemVariables.filter(
    v => v.label.toLowerCase().includes(q) || v.desc.toLowerCase().includes(q)
  );
});

const categories = [
  {
    id: 'MARKETING_LITE',
    title: 'Marketing Lite',
    badge: 'Recomendado',
    icon: 'i-lucide-rocket',
    description:
      'Envie mensagens de marketing com maior alcance e limites flexíveis. Até 10% mais barato e entrega até 9% mais mensagens.',
  },
  {
    id: 'MARKETING',
    title: 'Marketing',
    badge: null,
    icon: 'i-lucide-megaphone',
    description:
      'Promova sua marca por meio de ofertas e campanhas. Ideal para reengajamento, upselling e aumento de conversões.',
  },
  {
    id: 'UTILITY',
    title: 'Utilidade',
    badge: null,
    icon: 'i-lucide-bell',
    description:
      'Mantenha os clientes informados com atualizações essenciais. Use para lembretes, confirmações e outras mensagens não promocionais.',
  },
];

const languages = [
  { value: 'pt_BR', label: 'Português (Brasil)' },
  { value: 'en_US', label: 'Inglês (Estados Unidos)' },
  { value: 'es', label: 'Espanhol' },
];

const headerOptions = [
  { id: 'NONE', label: 'Nenhum', icon: 'i-lucide-minus' },
  { id: 'TEXT', label: 'Título', icon: 'i-lucide-file-text' },
  { id: 'IMAGE', label: 'Imagem', icon: 'i-lucide-image' },
  { id: 'VIDEO', label: 'Vídeo', icon: 'i-lucide-video' },
  { id: 'DOCUMENT', label: 'Arquivo', icon: 'i-lucide-paperclip' },
];

const bodyLength = computed(() => form.value.body.length);
const footerLength = computed(() => (form.value.footer || '').length);

const isStep1Valid = computed(() => !!form.value.category);
const variableRows = computed(() =>
  templateVariables(
    form.value.header_type,
    form.value.header_content,
    form.value.body,
    sampleValues.value
  )
);

const templatePayload = computed(() => ({
  ...form.value,
  variables: variableRows.value,
}));
const metaIssues = computed(() =>
  validateMetaTemplate(templatePayload.value, { requirePublicSample: false })
);
const metaSubmitIssues = computed(() =>
  validateMetaTemplate(templatePayload.value, { requirePublicSample: true })
);
const previewSamples = computed(() =>
  Object.fromEntries(
    variableRows.value.map(row => [row.key, row.sample_value || ''])
  )
);
const metaSubmitHint = computed(
  () =>
    metaSubmitIssues.value.find(issue => !metaIssues.value.includes(issue)) ||
    ''
);

const whatsappInboxes = computed(() =>
  (inboxes.value || []).filter(
    inbox => inbox.channel_type === 'Channel::Whatsapp'
  )
);

const isStep2Valid = computed(() => {
  const nameClean = form.value.name.trim();
  const hasValidName = /^[a-z0-9_]+$/.test(nameClean);
  return hasValidName && metaIssues.value.length === 0;
});

const selectCategory = id => {
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

const setHeaderType = type => {
  if (form.value.header_type !== type) {
    form.value.header_content = '';
    form.value.header_media_name = '';
    headerMediaSignedId.value = '';
  }
  form.value.header_type = type;
};

const uploadMedia = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;

  const limit = MEDIA_LIMIT_MB[form.value.header_type] * 1024 * 1024;
  if (file.size > limit) {
    useAlert(
      `O arquivo passa de ${MEDIA_LIMIT_MB[form.value.header_type]} MB.`
    );
    return;
  }

  isUploading.value = true;
  try {
    const { data } = await whatsappTemplatesApi.uploadMedia(file);
    const fileUrl = data.file_url?.startsWith('http')
      ? data.file_url
      : `${window.location.origin}${data.file_url}`;
    headerMediaSignedId.value = data.blob_id;
    form.value.header_media_name = file.name;
    form.value.header_content = fileUrl;
  } catch (err) {
    useAlert(err.response?.data?.error || 'Não foi possível enviar o arquivo.');
  } finally {
    isUploading.value = false;
  }
};

const applyFormat = wrapper => {
  const textarea = textareaRef.value;
  if (!textarea) return;

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const selectedText = form.value.body.substring(start, end);

  const replacement = `${wrapper}${selectedText || 'texto'}${wrapper}`;
  form.value.body =
    form.value.body.substring(0, start) +
    replacement +
    form.value.body.substring(end);

  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(start + wrapper.length, end + wrapper.length);
  }, 50);
};

const insertVariable = varKey => {
  const textarea = textareaRef.value;
  const placeholder = `{{${varKey}}}`;

  if (!textarea) {
    form.value.body += placeholder;
    isVariableMenuOpen.value = false;
    return;
  }

  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  form.value.body =
    form.value.body.substring(0, start) +
    placeholder +
    form.value.body.substring(end);
  isVariableMenuOpen.value = false;

  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(
      start + placeholder.length,
      start + placeholder.length
    );
  }, 50);
};

const setSample = (row, value) => {
  sampleValues.value = {
    ...sampleValues.value,
    [`${row.component}:${row.key}`]: value,
  };
};

const addButton = () => {
  if (form.value.buttons.length >= 10) {
    useAlert('A Meta permite até 10 botões.');
    return;
  }
  form.value.buttons.push({
    type: 'URL',
    text: '',
    url: 'https://',
    phone_number: '',
  });
};

const removeButton = index => {
  form.value.buttons.splice(index, 1);
};

const submitTemplate = async (status = 'PENDING') => {
  if (!/^[a-z0-9_]+$/.test(form.value.name.trim())) {
    useAlert(
      'O nome do template só pode ter letras minúsculas, números e underline.'
    );
    return;
  }
  const issues =
    status === 'PENDING' ? metaSubmitIssues.value : metaIssues.value;
  if (issues.length) {
    useAlert(issues[0]);
    return;
  }

  isSubmitting.value = true;
  try {
    const payload = {
      ...form.value,
      status: isEditing.value ? existingStatus.value : status,
      variables: variableRows.value,
    };
    delete payload.header_media_name;
    if (headerMediaSignedId.value) {
      payload.header_media = headerMediaSignedId.value;
    }
    if (isEditing.value) {
      await whatsappTemplatesApi.updateTemplate(templateId.value, payload);
      if (status === 'PENDING') {
        await whatsappTemplatesApi.submitReview(templateId.value);
      }
    } else {
      payload.status = status;
      await whatsappTemplatesApi.createTemplate(payload);
    }
    let successMessage = 'Template enviado para revisão da Meta.';
    if (status === 'APPROVED') {
      successMessage = isEditing.value
        ? 'Template atualizado.'
        : 'Template salvo com as regras da Meta e disponível no fluxo.';
    }
    useAlert(successMessage);
    router.push({ name: 'whatsapp_templates_index' });
  } catch (err) {
    const errorMsg = err.response?.data?.error || 'Erro ao processar template.';
    useAlert(Array.isArray(errorMsg) ? errorMsg.join(', ') : errorMsg);
  } finally {
    isSubmitting.value = false;
  }
};

const loadTemplate = async () => {
  if (!templateId.value) return;
  isLoadingTemplate.value = true;
  try {
    const res = await whatsappTemplatesApi.getTemplate(templateId.value);
    const tpl = res.data;
    existingStatus.value = tpl.status || 'APPROVED';
    form.value = {
      category: tpl.category || 'MARKETING',
      name: tpl.name || '',
      language: tpl.language || 'pt_BR',
      header_type: tpl.header_type || 'NONE',
      header_content: tpl.header_content || '',
      header_media_name: tpl.header_media_name || '',
      body: tpl.body || '',
      footer: tpl.footer || '',
      validity_hours: 24,
      buttons: Array.isArray(tpl.buttons) ? tpl.buttons : [],
      inbox_id: tpl.inbox_id,
    };
    const samples = {};
    (tpl.variables || []).forEach(item => {
      const key = String(item.key || '').replace(/[{}]/g, '');
      if (!key) return;
      samples[`${item.component || 'body'}:${key}`] = item.sample_value || '';
    });
    sampleValues.value = samples;
    currentStep.value = 2;
  } catch (err) {
    useAlert('Não foi possível abrir o template.');
    router.push({ name: 'whatsapp_templates_index' });
  } finally {
    isLoadingTemplate.value = false;
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
  loadTemplate();
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-1 flex-col w-full h-full min-h-0 min-w-0 bg-n-background pb-20 text-n-slate-12 overflow-hidden md:pb-0"
  >
    <!-- Top Step Bar Header -->
    <div class="shrink-0 border-b border-n-weak bg-n-solid-1 px-4 py-3 sm:px-8">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-4">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="flex items-center gap-2 select-none"
            :class="
              currentStep === 1
                ? 'text-n-slate-12'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="currentStep = 1"
          >
            <span
              class="flex size-6 items-center justify-center rounded-full text-xs font-semibold"
              :class="
                currentStep > 1
                  ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                  : currentStep === 1
                    ? 'bg-n-brand text-white'
                    : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              <span v-if="currentStep > 1" class="i-lucide-check size-3.5" />
              <span v-else>1</span>
            </span>
            <span class="hidden text-sm font-medium sm:inline">Categoria</span>
          </button>

          <span class="h-px w-8 bg-n-weak" />

          <div
            class="flex items-center gap-2 select-none"
            :class="currentStep === 2 ? 'text-n-slate-12' : 'text-n-slate-11'"
          >
            <span
              class="flex size-6 items-center justify-center rounded-full text-xs font-semibold"
              :class="
                currentStep === 2
                  ? 'bg-n-brand text-white'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              2
            </span>
            <span class="hidden text-sm font-medium sm:inline">Conteúdo</span>
          </div>
        </div>

        <button
          type="button"
          class="h-9 px-3 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="$router.push({ name: 'whatsapp_templates_index' })"
        >
          <span class="sm:hidden">Voltar</span>
          <span class="hidden sm:inline">Cancelar</span>
        </button>
      </div>
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <div
        v-if="isLoadingTemplate"
        class="flex h-full items-center justify-center text-sm text-n-slate-11"
      >
        Carregando template...
      </div>

      <!-- Main Container -->
      <div v-else class="max-w-6xl w-full mx-auto p-4 sm:p-8">
        <!-- ETAPA 1: SELECIONAR CATEGORIA -->
        <div v-if="currentStep === 1" class="space-y-6">
          <div>
            <h2 class="text-xl font-semibold text-n-slate-12">Categoria</h2>
            <p class="mt-1 text-sm text-n-slate-11">
              Escolha o tipo de modelo que melhor se adapta à sua mensagem.
              <a
                href="https://business.facebook.com/latest/whatsapp_manager/message_templates"
                target="_blank"
                rel="noopener noreferrer"
                class="text-n-brand hover:underline"
              >
                Saiba mais
              </a>
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div
              v-for="cat in categories"
              :key="cat.id"
              class="relative flex cursor-pointer items-start gap-4 rounded-2xl border bg-n-solid-1 p-5 transition-colors"
              :class="
                form.category === cat.id
                  ? 'border-n-brand'
                  : 'border-n-weak hover:bg-n-alpha-1'
              "
              @click="selectCategory(cat.id)"
            >
              <div
                class="flex items-center justify-center size-10 rounded-xl bg-n-brand/10 text-n-brand shrink-0"
              >
                <span class="size-5" :class="cat.icon" />
              </div>

              <div class="flex-1 pr-6">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-n-slate-12">{{
                    cat.title
                  }}</span>
                  <span
                    v-if="cat.badge"
                    class="rounded-md bg-n-brand/10 px-2 py-0.5 text-[0.6875rem] font-medium text-n-brand"
                  >
                    {{ cat.badge }}
                  </span>
                </div>
                <p class="mt-1.5 text-xs leading-relaxed text-n-slate-11">
                  {{ cat.description }}
                </p>
              </div>

              <!-- Radio Button Circle -->
              <div class="absolute top-5 right-5">
                <div
                  class="flex size-5 items-center justify-center rounded-full border-2 transition-colors"
                  :class="
                    form.category === cat.id
                      ? 'border-n-brand bg-n-brand'
                      : 'border-n-weak bg-n-solid-1'
                  "
                >
                  <div
                    v-if="form.category === cat.id"
                    class="w-2 h-2 rounded-full bg-white"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Bottom Action Bar Step 1 -->
          <div
            class="flex items-center justify-between border-t border-n-weak pt-6"
          >
            <button
              type="button"
              class="h-10 rounded-xl border border-n-weak px-4 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
              @click="$router.push({ name: 'whatsapp_templates_index' })"
            >
              Cancelar
            </button>

            <button
              type="button"
              class="flex h-10 items-center gap-2 rounded-xl bg-n-brand px-4 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-40"
              :disabled="!isStep1Valid"
              @click="goToStep2"
            >
              <span>Próximo</span>
              <span class="i-lucide-arrow-right size-4" />
            </button>
          </div>
        </div>

        <!-- ETAPA 2: CONFIGURAR MODELO COM PREVIEW EM TEMPO REAL -->
        <div v-else class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
          <!-- Coluna Esquerda: Formulário de Configuração (7 colunas) -->
          <div class="lg:col-span-7 order-2 lg:order-1 space-y-6">
            <!-- Card de Cabeçalho e Identificação -->
            <div
              class="space-y-4 rounded-2xl border border-n-weak bg-n-solid-1 p-5"
            >
              <div>
                <h3 class="text-base font-semibold text-n-slate-12">
                  {{ isEditing ? 'Editar modelo' : 'Modelo' }}
                  {{
                    form.category === 'UTILITY'
                      ? 'Utilitário'
                      : form.category === 'MARKETING_LITE'
                        ? 'Marketing Lite'
                        : 'Marketing'
                  }}
                </h3>
                <p class="mt-1 text-xs text-n-slate-11">
                  O texto segue as regras da Meta: variáveis com exemplo, sem
                  variável no início ou no fim, e botões de até 25 caracteres.
                </p>
                <p
                  v-if="!whatsappInboxes.length"
                  class="text-xs text-n-amber-11 mt-2"
                >
                  Nenhuma inbox WhatsApp Cloud conectada. Você pode salvar o
                  template para o fluxo. O envio à Meta fica disponível depois
                  de conectar o número.
                </p>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label :class="LABEL_CLASS">Nome do modelo</label>
                  <input
                    v-model="form.name"
                    type="text"
                    placeholder="ex: atualizacao_pedido"
                    :class="FIELD_CLASS"
                    @input="sanitizeName"
                  />
                  <span class="mt-1.5 block text-[0.6875rem] text-n-slate-10">
                    Somente letras minúsculas, números e underline (_)
                  </span>
                </div>

                <div>
                  <label :class="LABEL_CLASS">Idioma</label>
                  <select v-model="form.language" :class="FIELD_CLASS">
                    <option
                      v-for="lang in languages"
                      :key="lang.value"
                      :value="lang.value"
                    >
                      {{ lang.label }}
                    </option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Card de Conteúdo: Cabeçalho, Corpo, Rodapé -->
            <div
              class="space-y-5 rounded-2xl border border-n-weak bg-n-solid-1 p-5"
            >
              <div>
                <h3 class="text-base font-semibold text-n-slate-12">
                  Conteúdo
                </h3>
                <p class="mt-1 text-xs text-n-slate-11">
                  Para engajar os clientes de forma eficaz e reduzir o risco de
                  bloqueio, siga a
                  <a
                    href="https://business.facebook.com/policies/whatsapp_business_messaging"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-n-brand hover:underline"
                  >
                    Política de Mensagens do WhatsApp Business
                  </a>
                </p>
              </div>

              <!-- Seção de Cabeçalho Opcional -->
              <div>
                <label :class="LABEL_CLASS">Cabeçalho</label>
                <div
                  class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2"
                >
                  <button
                    v-for="hdr in headerOptions"
                    :key="hdr.id"
                    type="button"
                    class="flex h-9 items-center justify-center gap-1.5 rounded-lg border px-2 text-xs font-medium transition-colors"
                    :class="
                      form.header_type === hdr.id
                        ? 'border-n-brand bg-n-brand/10 text-n-brand'
                        : 'border-n-weak bg-n-solid-1 text-n-slate-12 hover:bg-n-alpha-1'
                    "
                    @click="setHeaderType(hdr.id)"
                  >
                    <span class="size-3.5 shrink-0" :class="hdr.icon" />
                    <span class="truncate">{{ hdr.label }}</span>
                  </button>
                </div>

                <div v-if="form.header_type === 'TEXT'" class="mt-3">
                  <input
                    v-model="form.header_content"
                    type="text"
                    placeholder="Texto do título (máximo 60 caracteres)"
                    maxlength="60"
                    :class="FIELD_CLASS"
                  />
                </div>
                <div
                  v-else-if="form.header_type !== 'NONE'"
                  class="mt-3 space-y-3 rounded-xl border border-dashed border-n-weak bg-n-alpha-1 p-3"
                >
                  <div class="flex flex-col sm:flex-row sm:items-center gap-3">
                    <div
                      class="size-16 shrink-0 rounded-lg bg-n-alpha-1 overflow-hidden flex items-center justify-center"
                    >
                      <img
                        v-if="
                          form.header_type === 'IMAGE' && form.header_content
                        "
                        :src="form.header_content"
                        alt=""
                        class="size-full object-cover"
                      />
                      <span
                        v-else
                        class="size-6 text-n-slate-11"
                        :class="
                          headerOptions.find(
                            item => item.id === form.header_type
                          )?.icon
                        "
                      />
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="text-xs font-medium text-n-slate-12">
                        Exemplo de
                        {{
                          form.header_type === 'IMAGE'
                            ? 'imagem'
                            : form.header_type === 'VIDEO'
                              ? 'vídeo'
                              : 'documento'
                        }}
                      </p>
                      <p
                        v-if="form.header_media_name"
                        class="truncate text-xs text-n-slate-12"
                      >
                        {{ form.header_media_name }}
                      </p>
                      <p class="text-[0.6875rem] text-n-slate-11">
                        O arquivo fica no armazenamento do Chatwoot. JPEG ou PNG
                        até 5 MB, MP4 até 16 MB e PDF até 100 MB.
                      </p>
                    </div>
                    <button
                      type="button"
                      class="h-9 w-full sm:w-auto px-3 rounded-lg bg-n-brand text-white text-xs font-medium hover:opacity-90 disabled:opacity-50"
                      :disabled="isUploading"
                      @click="fileInput?.click()"
                    >
                      {{
                        isUploading
                          ? 'Enviando...'
                          : form.header_content
                            ? 'Trocar arquivo'
                            : 'Enviar arquivo'
                      }}
                    </button>
                    <input
                      ref="fileInput"
                      type="file"
                      class="hidden"
                      :accept="MEDIA_ACCEPT[form.header_type]"
                      @change="uploadMedia"
                    />
                  </div>
                </div>
              </div>

              <!-- Seção de Corpo da Mensagem (com Toolbar rica) -->
              <div>
                <div class="flex items-center justify-between mb-1.5">
                  <label class="text-xs font-medium text-n-slate-11">
                    Corpo da mensagem
                  </label>
                  <span
                    class="text-xs"
                    :class="
                      bodyLength > 1024
                        ? 'font-medium text-n-ruby-11'
                        : 'text-n-slate-10'
                    "
                  >
                    {{ bodyLength }}/1024
                  </span>
                </div>

                <div
                  class="overflow-hidden rounded-lg bg-n-solid-1 outline outline-1 outline-n-weak focus-within:outline-n-brand"
                >
                  <textarea
                    ref="textareaRef"
                    v-model="form.body"
                    rows="6"
                    maxlength="1024"
                    placeholder="Olá {{1}}, seu pedido foi recebido."
                    class="reset-base m-0 w-full resize-none border-0 bg-transparent p-3 text-sm leading-relaxed text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none"
                  />

                  <div
                    class="relative flex items-center justify-between border-t border-n-weak px-2 py-1.5"
                  >
                    <div class="flex items-center gap-1">
                      <button
                        type="button"
                        title="Negrito (*texto*)"
                        class="flex size-8 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
                        @click="applyFormat('*')"
                      >
                        <span class="i-lucide-bold size-4" />
                      </button>
                      <button
                        type="button"
                        title="Itálico (_texto_)"
                        class="flex size-8 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
                        @click="applyFormat('_')"
                      >
                        <span class="i-lucide-italic size-4" />
                      </button>
                      <button
                        type="button"
                        title="Tachado (~texto~)"
                        class="flex size-8 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
                        @click="applyFormat('~')"
                      >
                        <span class="i-lucide-strikethrough size-4" />
                      </button>

                      <OnClickOutside
                        class="relative"
                        @trigger="isVariableMenuOpen = false"
                      >
                        <button
                          type="button"
                          title="Inserir Campos do Sistema / Variáveis"
                          class="px-2.5 h-8 rounded-lg flex items-center gap-1.5 text-xs font-semibold text-n-brand bg-n-brand/10 hover:bg-n-brand/20 transition-colors"
                          @click="isVariableMenuOpen = !isVariableMenuOpen"
                        >
                          <span class="font-mono text-sm font-bold leading-none"
                            >{ }</span
                          >
                          <span class="text-[11px]">Variável</span>
                        </button>

                        <div
                          v-if="isVariableMenuOpen"
                          class="absolute bottom-10 start-0 w-72 rounded-xl bg-n-solid-2 shadow-xl border border-n-weak p-2 z-50"
                        >
                          <div class="p-1 border-b border-n-weak mb-2">
                            <p class="text-xs font-semibold text-n-slate-12">
                              Campos do Sistema
                            </p>
                            <div class="relative mt-1.5">
                              <span
                                class="i-lucide-search size-3.5 absolute start-2.5 top-1/2 -translate-y-1/2 text-n-slate-10"
                              />
                              <input
                                v-model="variableSearch"
                                type="text"
                                placeholder="Buscar campos..."
                                class="reset-base w-full m-0 h-8 ps-8 pe-2.5 py-0 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
                              />
                            </div>
                          </div>

                          <div class="max-h-48 overflow-y-auto space-y-0.5">
                            <button
                              v-for="v in filteredVariables"
                              :key="v.key"
                              type="button"
                              class="w-full flex items-center gap-2 px-2 py-1.5 rounded-lg text-left hover:bg-n-alpha-2 transition-colors"
                              @click="insertVariable(v.key)"
                            >
                              <span
                                class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
                                >{ }</span
                              >
                              <span class="min-w-0">
                                <span
                                  class="block text-xs font-medium text-n-slate-12 truncate"
                                >
                                  {{ v.label }}
                                </span>
                                <span
                                  class="block text-[10px] text-n-slate-11 truncate"
                                >
                                  {{ v.desc }}
                                </span>
                              </span>
                            </button>
                          </div>
                        </div>
                      </OnClickOutside>
                    </div>
                  </div>
                </div>
              </div>

              <div v-if="variableRows.length" class="space-y-2">
                <div>
                  <h4 class="text-xs font-medium text-n-slate-12">
                    Exemplos das variáveis
                  </h4>
                  <p class="text-[0.6875rem] text-n-slate-10">
                    A Meta exige um exemplo para cada variável. O nome começa
                    com letra minúscula, ou use a sequência 1, 2, 3.
                  </p>
                </div>
                <div
                  v-for="row in variableRows"
                  :key="`${row.component}:${row.key}`"
                  class="flex flex-col sm:flex-row sm:items-center gap-2"
                >
                  <span
                    class="inline-flex items-center gap-1 w-40 shrink-0 font-mono text-xs text-n-slate-11"
                  >
                    <span
                      class="font-mono text-sm font-bold leading-none text-n-iris-11"
                      >{ }</span
                    >
                    {{ row.key }}
                  </span>
                  <input
                    :value="sampleValues[`${row.component}:${row.key}`] || ''"
                    type="text"
                    placeholder="Exemplo enviado à Meta"
                    :class="FIELD_CLASS"
                    @input="setSample(row, $event.target.value)"
                  />
                </div>
              </div>

              <div
                v-if="metaIssues.length"
                class="p-3 rounded-xl bg-n-ruby-9/10 border border-n-ruby-8/40 space-y-1"
              >
                <p
                  v-for="issue in metaIssues"
                  :key="issue"
                  class="text-xs text-n-ruby-11"
                >
                  {{ issue }}
                </p>
              </div>

              <!-- Seção de Rodapé Opcional -->
              <div>
                <div class="flex items-center justify-between mb-1.5">
                  <label class="text-xs font-medium text-n-slate-11"
                    >Rodapé</label
                  >
                  <span class="text-xs text-n-slate-10"
                    >{{ footerLength }}/60</span
                  >
                </div>
                <input
                  v-model="form.footer"
                  type="text"
                  maxlength="60"
                  placeholder="ex: Para não receber mais promoções, responda PARAR"
                  :class="FIELD_CLASS"
                />
              </div>

              <!-- Seção de Botões de Ação -->
              <div class="border-t border-n-weak pt-4">
                <div class="mb-2 flex items-center justify-between gap-3">
                  <div>
                    <h4 class="text-xs font-medium text-n-slate-12">Botões</h4>
                    <p class="text-[0.6875rem] text-n-slate-10">
                      Até 10 botões. O texto tem no máximo 25 caracteres. URL
                      começa com https://.
                    </p>
                  </div>
                  <button
                    type="button"
                    class="inline-flex h-8 items-center gap-1.5 rounded-lg border border-n-weak px-2.5 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40"
                    :disabled="form.buttons.length >= 10"
                    @click="addButton"
                  >
                    <span class="i-lucide-plus size-3.5" />
                    Adicionar botão
                  </button>
                </div>

                <!-- Lista de Botões Adicionados -->
                <div class="space-y-2 mt-2">
                  <div
                    v-for="(btn, idx) in form.buttons"
                    :key="idx"
                    class="space-y-2 rounded-xl border border-n-weak bg-n-alpha-1 p-3"
                  >
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex flex-wrap gap-1">
                        <button
                          v-for="kind in [
                            { value: 'URL', label: 'Link' },
                            { value: 'QUICK_REPLY', label: 'Resposta' },
                            { value: 'PHONE_NUMBER', label: 'Telefone' },
                          ]"
                          :key="kind.value"
                          type="button"
                          class="h-7 px-2 rounded-lg text-[0.6875rem] font-medium"
                          :class="
                            btn.type === kind.value
                              ? 'bg-n-brand text-white'
                              : 'bg-n-alpha-2 text-n-slate-11'
                          "
                          @click="btn.type = kind.value"
                        >
                          {{ kind.label }}
                        </button>
                      </div>
                      <button
                        type="button"
                        class="flex items-center justify-center size-7 rounded-lg text-n-slate-11 hover:text-n-ruby-11 hover:bg-n-alpha-2"
                        title="Remover botão"
                        @click="removeButton(idx)"
                      >
                        <span class="i-lucide-x size-4" />
                      </button>
                    </div>
                    <input
                      v-model="btn.text"
                      type="text"
                      maxlength="25"
                      placeholder="Texto do botão (máx. 25)"
                      class="reset-base w-full h-9 m-0 px-3 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
                    />
                    <input
                      v-if="btn.type === 'URL'"
                      v-model="btn.url"
                      type="url"
                      placeholder="https://exemplo.com/pedido"
                      class="reset-base w-full h-9 m-0 px-3 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
                    />
                    <input
                      v-else-if="btn.type === 'PHONE_NUMBER'"
                      v-model="btn.phone_number"
                      type="tel"
                      placeholder="+5511999999999"
                      class="reset-base w-full h-9 m-0 px-3 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Coluna Direita: Preview em Tempo Real no Smartphone (5 colunas) -->
          <div
            class="lg:col-span-5 order-1 lg:order-2 lg:sticky lg:top-20 flex flex-col items-center"
          >
            <div class="w-full flex items-center justify-between mb-3 px-2">
              <span
                class="text-xs font-bold text-n-slate-11 uppercase tracking-wider"
              >
                Preview em tempo real
              </span>
              <span
                class="text-[11px] px-2 py-0.5 rounded-full bg-green-500/15 text-green-700 dark:text-green-300 font-medium"
              >
                Simulador WhatsApp
              </span>
            </div>

            <WhatsAppPhonePreview
              :template="form"
              :sample-variables="previewSamples"
              contact-name="Games Safari Oficial"
              avatar-url="https://gamessafari.com/cdn/shop/files/logo_png_sem_controle.png"
            />
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="!isLoadingTemplate && currentStep === 2"
      class="shrink-0 border-t border-n-weak bg-n-solid-1 px-4 py-3 sm:px-8"
    >
      <div
        class="max-w-6xl mx-auto flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex items-center gap-3">
          <button
            type="button"
            class="flex h-10 items-center gap-1.5 rounded-xl border border-n-weak px-4 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
            @click="goToStep1"
          >
            <span class="i-lucide-arrow-left size-4" />
            <span>Anterior</span>
          </button>

          <span class="hidden text-xs text-n-slate-10 sm:block">
            Salvar libera o template no fluxo. Enviar manda para a revisão da
            Meta.
          </span>
        </div>

        <div class="flex flex-col items-stretch gap-1 sm:items-end">
          <div
            class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2"
          >
            <button
              type="button"
              class="h-10 rounded-xl border border-n-weak px-4 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40"
              :disabled="isSubmitting || !isStep2Valid"
              @click="submitTemplate('APPROVED')"
            >
              {{ isEditing ? 'Salvar alterações' : 'Salvar para o fluxo' }}
            </button>

            <button
              type="button"
              class="flex h-10 items-center justify-center gap-2 rounded-xl bg-n-brand px-4 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-40"
              :disabled="isSubmitting || metaSubmitIssues.length > 0"
              @click="submitTemplate('PENDING')"
            >
              <span v-if="isSubmitting">Enviando...</span>
              <span v-else>Enviar para a Meta</span>
            </button>
          </div>
          <p
            v-if="metaSubmitHint"
            class="text-[11px] text-n-amber-11 sm:text-end"
          >
            {{ metaSubmitHint }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
