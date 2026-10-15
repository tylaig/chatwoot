<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRouter } from 'vue-router';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import whatsappTemplatesApi from 'dashboard/api/whatsappTemplates';
import { templateVariables } from './metaTemplate';
import {
  SAMPLE_TEMPLATE_VARIABLES,
  previewTemplateText,
  templateButtons,
} from './templatePreview';

const router = useRouter();
const templates = ref([]);
const contentTab = ref('visual');
const stats = ref({ total: 0, approved: 0, pending: 0, rejected: 0 });
const isLoading = ref(true);
const isSyncing = ref(false);
const searchQuery = ref('');
const selectedInbox = ref('ALL');
const selectedLanguage = ref('ALL');
const selectedCategory = ref('ALL');
const selectedStatus = ref('ALL');
const previewTemplate = ref(null);
const drawerOpen = ref(false);
const isWideLayout = ref(false);
const activeDrawerTab = ref('details');
const openMenuId = ref(null);
const page = ref(1);
const perPage = 8;
const defaultPreviewBody =
  'Olá {{1}}! 👋\nBem-vindo à Games Safari!\n\nAqui você encontra os melhores jogos e ofertas exclusivas. Qualquer dúvida, é só nos chamar por aqui. 🚀';

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const res = await whatsappTemplatesApi.getTemplates();
    templates.value = res.data.templates || [];
    stats.value = res.data.stats || {
      total: 0,
      approved: 0,
      pending: 0,
      rejected: 0,
    };
    if (previewTemplate.value) {
      previewTemplate.value =
        templates.value.find(tpl => tpl.id === previewTemplate.value.id) ||
        templates.value[0] ||
        null;
    } else if (templates.value.length) {
      previewTemplate.value = templates.value[0];
    }
  } catch (err) {
    useAlert('Erro ao carregar templates.');
  } finally {
    isLoading.value = false;
  }
};

const syncTemplates = async () => {
  if (isSyncing.value) return;

  isSyncing.value = true;
  try {
    const res = await whatsappTemplatesApi.syncTemplates();
    await fetchTemplates();
    useAlert(res.data.message || 'Templates sincronizados.');
  } catch (err) {
    const error = err.response?.data?.error;
    useAlert(
      Array.isArray(error)
        ? error.join(' ')
        : error || 'Não foi possível sincronizar os templates.'
    );
  } finally {
    isSyncing.value = false;
  }
};

let wideLayoutQuery;

const syncWideLayout = () => {
  isWideLayout.value = wideLayoutQuery?.matches || false;
};

onMounted(() => {
  wideLayoutQuery = window.matchMedia('(min-width: 1280px)');
  syncWideLayout();
  wideLayoutQuery.addEventListener('change', syncWideLayout);
  fetchTemplates();
});

onBeforeUnmount(() => {
  wideLayoutQuery?.removeEventListener('change', syncWideLayout);
});

const filteredTemplates = computed(() => {
  return templates.value.filter(tpl => {
    const matchesSearch =
      !searchQuery.value ||
      tpl.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      tpl.body?.toLowerCase().includes(searchQuery.value.toLowerCase());
    const matchesCat =
      selectedCategory.value === 'ALL' ||
      tpl.category === selectedCategory.value;
    const matchesLang =
      selectedLanguage.value === 'ALL' ||
      tpl.language === selectedLanguage.value;
    const matchesStat =
      selectedStatus.value === 'ALL' || tpl.status === selectedStatus.value;
    return matchesSearch && matchesCat && matchesLang && matchesStat;
  });
});

const pageCount = computed(() =>
  Math.max(1, Math.ceil(filteredTemplates.value.length / perPage))
);

const pagedTemplates = computed(() => {
  const start = (page.value - 1) * perPage;
  return filteredTemplates.value.slice(start, start + perPage);
});

const pageStart = computed(() =>
  filteredTemplates.value.length ? (page.value - 1) * perPage + 1 : 0
);

const pageEnd = computed(() =>
  Math.min(page.value * perPage, filteredTemplates.value.length)
);

watch([searchQuery, selectedCategory, selectedLanguage, selectedStatus], () => {
  page.value = 1;
});

watch(pageCount, count => {
  if (page.value > count) page.value = count;
});

const categoryClass = category => {
  const value = (category || '').toUpperCase();
  if (value === 'UTILITY') return 'bg-green-500/20 text-green-400';
  if (value === 'MARKETING_LITE') return 'bg-n-violet-9/20 text-n-violet-11';
  if (value === 'AUTHENTICATION') return 'bg-n-amber-9/20 text-n-amber-11';
  return 'bg-n-violet-9/20 text-n-violet-11';
};

const languageLabel = code => {
  if (!code || code === 'pt_BR') return 'Português (Brasil) — pt_BR';
  if (code === 'en' || code === 'en_US') return 'English — en_US';
  if (code === 'es' || code === 'es_ES') return 'Español — es';
  return code;
};

const statusHint = status => {
  const value = (status || '').toUpperCase();
  if (value === 'APPROVED') return 'Aprovado pela Meta e pronto para uso.';
  if (value === 'PENDING') return 'Aguardando revisão da Meta.';
  if (value === 'REJECTED') return 'Rejeitado pela Meta.';
  return status || '—';
};

const statusLabel = status => {
  const value = (status || '').toUpperCase();
  if (value === 'APPROVED') return 'Aprovado';
  if (value === 'PENDING') return 'Pendente';
  if (value === 'REJECTED') return 'Rejeitado';
  return status || '—';
};

const categoryLabel = category => {
  const value = (category || '').toUpperCase();
  if (value === 'MARKETING_LITE') return 'Marketing Lite';
  if (value === 'MARKETING') return 'Marketing';
  if (value === 'UTILITY') return 'Utilidade';
  if (value === 'AUTHENTICATION') return 'Autenticação';
  return category || 'Marketing';
};

const handleSelectTemplate = tpl => {
  previewTemplate.value = tpl;
  drawerOpen.value = true;
  contentTab.value = 'visual';
  activeDrawerTab.value = 'details';
};

const closeDrawer = () => {
  drawerOpen.value = false;
};

const openEditor = tpl => {
  openMenuId.value = null;
  router.push({
    name: 'whatsapp_templates_edit',
    params: { templateId: tpl.id },
  });
};

const formatStamp = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const formatStampCompact = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const showDrawer = computed(
  () => previewTemplate.value && (isWideLayout.value || drawerOpen.value)
);

const previewBody = computed(() =>
  previewTemplateText(previewTemplate.value?.body || defaultPreviewBody)
);

const previewActions = computed(() => templateButtons(previewTemplate.value));

const displayedVariables = computed(() => {
  const stored = previewTemplate.value?.variables;
  if (Array.isArray(stored) && stored.length) return stored;
  const body = previewTemplate.value?.body || '';
  const seen = new Set();
  return [...body.matchAll(/\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/g)]
    .filter(match => {
      if (seen.has(match[1])) return false;
      seen.add(match[1]);
      return true;
    })
    .map(match => ({
      key: `{{${match[1]}}}`,
      name: match[1] === '1' ? 'Nome do cliente' : `Variável ${match[1]}`,
      sample_value: SAMPLE_TEMPLATE_VARIABLES[match[1]] || '—',
    }));
});

const duplicateTemplate = async tpl => {
  const source = tpl || previewTemplate.value;
  if (!source) return;
  openMenuId.value = null;
  const suffix = Date.now().toString(36);
  try {
    const variables = source.variables?.length
      ? source.variables
      : templateVariables(
          source.header_type,
          source.header_content,
          source.body,
          {}
        ).map(item => ({
          ...item,
          sample_value: item.key === '1' ? 'Maria' : `exemplo ${item.key}`,
        }));
    await whatsappTemplatesApi.createTemplate({
      name: `${source.name}_copia_${suffix}`.slice(0, 512),
      category: source.category,
      language: source.language,
      status: 'APPROVED',
      header_type: source.header_type,
      header_content: source.header_content,
      body: source.body,
      footer: source.footer,
      buttons: source.buttons || [],
      variables,
    });
    await fetchTemplates();
    useAlert('Template duplicado.');
  } catch (err) {
    useAlert('Erro ao duplicar template.');
  }
};

const removeTemplate = async tpl => {
  const source = tpl || previewTemplate.value;
  if (!source) return;
  openMenuId.value = null;
  try {
    await whatsappTemplatesApi.deleteTemplate(source.id);
    if (previewTemplate.value?.id === source.id) previewTemplate.value = null;
    await fetchTemplates();
    useAlert('Template excluído.');
  } catch (err) {
    useAlert('Erro ao excluir template.');
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    class="flex flex-1 w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-hidden"
  >
    <div class="flex flex-1 flex-col min-w-0 min-h-0">
      <header
        class="px-6 py-5 border-b border-n-weak bg-n-solid-1 flex flex-wrap items-center justify-between gap-4"
      >
        <div class="min-w-0">
          <h1 class="text-xl font-semibold text-n-slate-12">Templates</h1>
          <p class="text-sm text-n-slate-11 mt-0.5">
            Gerencie modelos de mensagens aprovados pela Meta para usar nos seus
            workflows.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <button
            type="button"
            class="h-10 px-3.5 rounded-xl border border-n-weak bg-n-solid-1 hover:bg-n-alpha-2 text-sm font-medium text-n-slate-12 transition-colors flex items-center gap-1.5 disabled:opacity-60"
            :disabled="isSyncing"
            @click="syncTemplates"
          >
            <span
              class="i-lucide-refresh-cw size-4"
              :class="{ 'animate-spin': isSyncing }"
            />
            <span>{{ isSyncing ? 'Sincronizando' : 'Sincronizar' }}</span>
          </button>

          <button
            type="button"
            class="h-10 ps-3 pe-4 rounded-xl bg-n-brand hover:opacity-90 text-white text-sm font-semibold shadow-sm flex items-center gap-2"
            @click="router.push({ name: 'whatsapp_templates_new' })"
          >
            <span class="i-lucide-plus size-4" />
            <span>Criar template</span>
          </button>
        </div>
      </header>

      <!-- BARRA DE PESQUISA E FILTROS HORIZONTAIS (ESTILO REFERENCE PACK) -->
      <div class="px-6 py-4 flex flex-wrap items-center gap-3">
        <div class="relative flex-1 min-w-[12rem]">
          <span
            class="i-lucide-search size-4 absolute start-3 top-1/2 -translate-y-1/2 text-n-slate-10"
          />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar templates..."
            class="reset-base w-full h-9 m-0 ps-9 pe-3 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
          />
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Inbox</span>
            <select
              v-model="selectedInbox"
              class="reset-base w-auto h-9 m-0 py-0 ps-3 pe-8 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            >
              <option value="ALL">Todos</option>
              <option value="1">Suporte - WhatsApp</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Idioma</span>
            <select
              v-model="selectedLanguage"
              class="reset-base w-auto h-9 m-0 py-0 ps-3 pe-8 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            >
              <option value="ALL">Todos</option>
              <option value="pt_BR">pt_BR</option>
              <option value="en_US">en_US</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Categoria</span>
            <select
              v-model="selectedCategory"
              class="reset-base w-auto h-9 m-0 py-0 ps-3 pe-8 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            >
              <option value="ALL">Todas</option>
              <option value="MARKETING">Marketing</option>
              <option value="MARKETING_LITE">Marketing Lite</option>
              <option value="UTILITY">Utilidade</option>
              <option value="AUTHENTICATION">Autenticação</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Status</span>
            <select
              v-model="selectedStatus"
              class="reset-base w-auto h-9 m-0 py-0 ps-3 pe-8 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            >
              <option value="ALL">Todos</option>
              <option value="APPROVED">Aprovado</option>
              <option value="PENDING">Pendente</option>
              <option value="REJECTED">Rejeitado</option>
            </select>
          </div>
        </div>
      </div>

      <!-- TABELA DE TEMPLATES -->
      <div class="flex flex-1 flex-col min-h-0 min-w-0 overflow-auto px-6 pb-4">
        <div class="min-w-0 rounded-2xl border border-n-weak bg-n-solid-1">
          <table class="w-full table-fixed text-left border-collapse text-sm">
            <thead>
              <tr
                class="border-b border-n-weak text-[0.6875rem] font-semibold text-n-slate-11 uppercase tracking-wide"
              >
                <th class="py-3 px-4">Nome do Template</th>
                <th class="py-3 px-4 w-28">Categoria</th>
                <th class="py-3 px-4 w-20">Idioma</th>
                <th class="py-3 px-4 w-28">Status</th>
                <th class="py-3 px-4 w-36">Última Atualização</th>
                <th class="py-3 px-4 w-14 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="tpl in pagedTemplates"
                :key="tpl.id"
                class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
                :class="previewTemplate?.id === tpl.id ? 'bg-n-brand/5' : ''"
                @click="handleSelectTemplate(tpl)"
              >
                <td class="py-3 px-4 max-w-0">
                  <div class="flex items-center gap-3 min-w-0">
                    <div
                      class="size-9 rounded-xl bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0"
                    >
                      <span class="i-lucide-file-text size-4" />
                    </div>
                    <div class="min-w-0">
                      <p class="font-medium text-n-slate-12 truncate">
                        {{ tpl.name }}
                      </p>
                      <p class="text-xs text-n-slate-11 font-normal truncate">
                        {{ tpl.body }}
                      </p>
                    </div>
                  </div>
                </td>

                <td class="py-3 px-4">
                  <span
                    class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium"
                    :class="categoryClass(tpl.category)"
                  >
                    {{ categoryLabel(tpl.category) }}
                  </span>
                </td>

                <td class="py-3 px-4 text-xs text-n-slate-11">
                  {{ tpl.language || 'pt_BR' }}
                </td>

                <td class="py-3 px-4">
                  <span
                    class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-xs font-medium"
                    :class="
                      tpl.status === 'APPROVED' || tpl.status === 'approved'
                        ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                        : tpl.status === 'PENDING'
                          ? 'bg-n-amber-9/15 text-n-amber-11'
                          : 'bg-n-ruby-9/15 text-n-ruby-11'
                    "
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="
                        tpl.status === 'APPROVED' || tpl.status === 'approved'
                          ? 'bg-green-500'
                          : tpl.status === 'PENDING'
                            ? 'bg-n-amber-9'
                            : 'bg-n-ruby-9'
                      "
                    />
                    {{ statusLabel(tpl.status) }}
                  </span>
                </td>

                <td class="py-3 px-4 text-xs text-n-slate-11 whitespace-nowrap">
                  {{ formatStampCompact(tpl.updated_at || tpl.created_at) }}
                </td>

                <td class="py-3 px-4 text-end" @click.stop>
                  <OnClickOutside
                    class="relative inline-block"
                    @trigger="openMenuId === tpl.id && (openMenuId = null)"
                  >
                    <button
                      type="button"
                      class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 ms-auto"
                      title="Ações"
                      @click="
                        openMenuId = openMenuId === tpl.id ? null : tpl.id
                      "
                    >
                      <span class="i-lucide-ellipsis size-4" />
                    </button>
                    <div
                      v-if="openMenuId === tpl.id"
                      class="absolute end-0 top-9 z-30 w-48 p-1 rounded-xl bg-n-solid-2 border border-n-weak shadow-xl text-start"
                    >
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="openEditor(tpl)"
                      >
                        <span class="i-lucide-pencil size-4 text-n-slate-11" />
                        Editar
                      </button>
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="duplicateTemplate(tpl)"
                      >
                        <span class="i-lucide-copy size-4 text-n-slate-11" />
                        Duplicar
                      </button>
                      <div class="my-1 h-px bg-n-weak" />
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-ruby-11 hover:bg-n-ruby-9/10"
                        @click="removeTemplate(tpl)"
                      >
                        <span class="i-lucide-trash-2 size-4" />
                        Excluir
                      </button>
                    </div>
                  </OnClickOutside>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div
        class="shrink-0 px-6 py-3 border-t border-n-weak flex flex-wrap items-center justify-between gap-2 text-xs text-n-slate-11"
      >
        <span>
          Mostrando {{ pageStart }}–{{ pageEnd }} de
          {{ filteredTemplates.length }} templates
        </span>
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-40"
            :disabled="page <= 1"
            @click="page -= 1"
          >
            <span class="i-lucide-chevron-left size-4" />
          </button>
          <span>{{ page }} / {{ pageCount }}</span>
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-40"
            :disabled="page >= pageCount"
            @click="page += 1"
          >
            <span class="i-lucide-chevron-right size-4" />
          </button>
        </div>
      </div>
    </div>

    <div
      v-if="showDrawer && !isWideLayout"
      class="fixed inset-0 z-30 bg-n-alpha-black1"
      @click="closeDrawer"
    />
    <div
      v-if="showDrawer"
      class="bg-n-solid-1 border-s border-n-weak flex flex-col min-h-0 overflow-y-auto"
      :class="
        isWideLayout
          ? 'w-[24rem] shrink-0'
          : 'fixed inset-y-0 end-0 z-40 w-[min(24rem,100%)] shadow-2xl'
      "
    >
      <div class="px-5 py-5 space-y-5">
        <div
          class="flex items-center justify-between gap-3 pb-4 border-b border-n-weak"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="size-9 rounded-xl bg-n-brand/15 text-n-brand flex items-center justify-center shrink-0"
            >
              <span class="i-lucide-file-text size-4" />
            </div>
            <div class="min-w-0">
              <h3 class="text-sm font-semibold text-n-slate-12 truncate">
                {{ previewTemplate.name }}
              </h3>
              <div class="flex items-center gap-2 mt-0.5">
                <span
                  class="text-[10px] px-2 py-0.5 rounded-md font-medium"
                  :class="categoryClass(previewTemplate.category)"
                >
                  {{ categoryLabel(previewTemplate.category) }}
                </span>
                <span
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[10px] font-medium"
                  :class="
                    previewTemplate.status === 'APPROVED'
                      ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                      : previewTemplate.status === 'PENDING'
                        ? 'bg-n-amber-9/15 text-n-amber-11'
                        : 'bg-n-ruby-9/15 text-n-ruby-11'
                  "
                >
                  <span
                    class="size-1.5 rounded-full"
                    :class="
                      previewTemplate.status === 'APPROVED'
                        ? 'bg-green-500'
                        : previewTemplate.status === 'PENDING'
                          ? 'bg-n-amber-9'
                          : 'bg-n-ruby-9'
                    "
                  />
                  {{ statusLabel(previewTemplate.status) }}
                </span>
              </div>
            </div>
          </div>
          <button
            v-if="!isWideLayout"
            type="button"
            class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:bg-n-alpha-2 shrink-0"
            title="Fechar"
            @click="closeDrawer"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <div class="flex border-b border-n-weak text-xs">
          <button
            type="button"
            class="pb-2 px-3 font-medium transition-colors"
            :class="
              activeDrawerTab === 'details'
                ? 'text-n-brand border-b-2 border-n-brand'
                : 'text-n-slate-11'
            "
            @click="activeDrawerTab = 'details'"
          >
            Detalhes
          </button>
          <button
            type="button"
            class="pb-2 px-3 font-medium transition-colors"
            :class="
              activeDrawerTab === 'history'
                ? 'text-n-brand border-b-2 border-n-brand'
                : 'text-n-slate-11'
            "
            @click="activeDrawerTab = 'history'"
          >
            Histórico
          </button>
        </div>

        <div
          v-if="activeDrawerTab === 'details'"
          class="p-3.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 text-xs"
        >
          <h4 class="font-semibold text-n-slate-12">Informações do template</h4>
          <div class="grid grid-cols-2 gap-2 text-[11px] text-n-slate-11">
            <div>
              <span class="text-n-slate-10 block">Nome</span>
              <span class="font-medium text-n-slate-12 break-all">{{
                previewTemplate.name
              }}</span>
            </div>
            <div>
              <span class="text-n-slate-10 block">Categoria</span>
              <span class="text-n-slate-12">{{
                categoryLabel(previewTemplate.category)
              }}</span>
            </div>
            <div>
              <span class="text-n-slate-10 block">Idioma</span>
              <span class="text-n-slate-12 break-words">{{
                languageLabel(previewTemplate.language)
              }}</span>
            </div>
            <div>
              <span class="text-n-slate-10 block">Status</span>
              <span class="font-medium text-n-slate-12">{{
                statusLabel(previewTemplate.status)
              }}</span>
              <span class="block text-n-slate-10">{{
                statusHint(previewTemplate.status)
              }}</span>
            </div>
          </div>
        </div>

        <div v-if="activeDrawerTab === 'details'" class="space-y-3">
          <div class="flex items-center justify-between">
            <h4 class="text-xs font-semibold text-n-slate-12">
              Conteúdo do template
            </h4>
            <div
              class="flex rounded-lg bg-n-alpha-1 p-0.5 border border-n-weak"
            >
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-medium rounded"
                :class="
                  contentTab === 'visual'
                    ? 'bg-n-brand text-white'
                    : 'text-n-slate-11'
                "
                @click="contentTab = 'visual'"
              >
                Visualização
              </button>
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-medium rounded"
                :class="
                  contentTab === 'json'
                    ? 'bg-n-brand text-white'
                    : 'text-n-slate-11'
                "
                @click="contentTab = 'json'"
              >
                Código JSON
              </button>
            </div>
          </div>

          <div
            v-if="contentTab === 'json'"
            class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak"
          >
            <pre
              class="text-[10px] font-mono text-n-slate-12 whitespace-pre-wrap"
              >{{ JSON.stringify(previewTemplate, null, 2) }}</pre
            >
          </div>
          <div
            v-else
            class="p-4 rounded-2xl bg-[#F6F1E7] border border-[#E6DCC8] text-slate-900 text-xs shadow-sm space-y-2 relative"
          >
            <p class="whitespace-pre-line leading-relaxed font-sans">
              {{ previewBody }}
            </p>
            <div class="text-[10px] text-slate-400 text-right">12:30</div>

            <div
              v-if="previewActions.length"
              class="pt-2 border-t border-green-600/20 space-y-1.5"
            >
              <div
                v-for="label in previewActions"
                :key="label"
                class="w-full py-1.5 px-3 rounded-lg bg-white text-n-brand font-semibold text-center text-[11px]"
              >
                {{ label }}
              </div>
            </div>
          </div>
        </div>

        <div
          v-if="activeDrawerTab === 'details'"
          class="p-3.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 text-xs"
        >
          <h4 class="font-semibold text-n-slate-12">Variáveis do template</h4>
          <p
            v-if="!displayedVariables.length"
            class="text-[11px] text-n-slate-10"
          >
            Nenhuma variável cadastrada.
          </p>
          <div v-else class="space-y-1 text-[11px]">
            <div
              v-for="variable in displayedVariables"
              :key="variable.key || variable.name"
              class="flex items-center gap-2 text-n-slate-12"
            >
              <span
                class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
                >{ }</span
              >
              <span class="font-medium truncate">{{
                variable.key || variable.name
              }}</span>
              <span class="text-n-slate-11 truncate">{{ variable.name }}</span>
              <span class="text-n-slate-10 truncate ms-auto">{{
                variable.sample_value || '—'
              }}</span>
            </div>
          </div>
        </div>

        <div
          v-else-if="activeDrawerTab === 'history'"
          class="space-y-2 text-xs text-n-slate-12"
        >
          <div
            class="p-3.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2"
          >
            <div class="flex justify-between gap-3">
              <span class="text-n-slate-11">Criado em</span>
              <span>{{ formatStamp(previewTemplate.created_at) }}</span>
            </div>
            <div class="flex justify-between gap-3">
              <span class="text-n-slate-11">Atualizado em</span>
              <span>{{ formatStamp(previewTemplate.updated_at) }}</span>
            </div>
            <div class="flex justify-between gap-3">
              <span class="text-n-slate-11">Status</span>
              <span>{{ statusHint(previewTemplate.status) }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="px-5 py-4 mt-auto border-t border-n-weak space-y-2">
        <button
          type="button"
          class="w-full h-9 px-3 rounded-xl bg-n-brand hover:opacity-90 text-white text-sm font-semibold inline-flex items-center justify-center gap-1.5"
          @click="openEditor(previewTemplate)"
        >
          <span class="i-lucide-pencil size-3.5" />
          Editar template
        </button>
        <button
          type="button"
          class="w-full py-2 px-3 rounded-xl border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 inline-flex items-center justify-center gap-1.5"
          @click="router.push({ name: 'workflows_index' })"
        >
          <span class="i-lucide-workflow size-3.5" />
          Usar no workflow
        </button>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="py-2 px-2 rounded-xl border border-n-ruby-9/30 text-xs font-medium text-n-ruby-11 hover:bg-n-ruby-9/10 inline-flex items-center justify-center gap-1.5"
            @click="removeTemplate"
          >
            <span class="i-lucide-trash-2 size-3.5" />
            Excluir
          </button>
          <button
            type="button"
            class="py-2 px-2 rounded-xl border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 inline-flex items-center justify-center gap-1.5"
            @click="duplicateTemplate"
          >
            <span class="i-lucide-copy size-3.5" />
            Duplicar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
