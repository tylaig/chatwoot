<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WorkflowsAPI from 'dashboard/api/workflows';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const PER_PAGE = 8;
const STATUS_META = {
  active: {
    label: 'Ativo',
    pill: 'bg-green-500/15 text-green-700 dark:text-green-300',
    dot: 'bg-green-500',
  },
  paused: {
    label: 'Pausado',
    pill: 'bg-n-amber-9/15 text-n-amber-11',
    dot: 'bg-n-amber-9',
  },
  draft: {
    label: 'Rascunho',
    pill: 'bg-n-alpha-2 text-n-slate-11',
    dot: 'bg-n-slate-8',
  },
};
const EXECUTION_STATUS = {
  completed: {
    label: 'Concluída',
    classes: 'text-green-600 dark:text-green-400',
    icon: 'i-lucide-circle-check',
  },
  failed: {
    label: 'Falhou',
    classes: 'text-n-ruby-11',
    icon: 'i-lucide-circle-alert',
  },
  running: {
    label: 'Executando',
    classes: 'text-n-blue-11',
    icon: 'i-lucide-loader-circle',
  },
  waiting: {
    label: 'Aguardando',
    classes: 'text-n-amber-11',
    icon: 'i-lucide-hourglass',
  },
  cancelled: {
    label: 'Cancelada',
    classes: 'text-n-slate-11',
    icon: 'i-lucide-x',
  },
};
const TABS = [
  { id: 'overview', label: 'Visão geral', icon: 'i-lucide-layout-dashboard' },
  { id: 'executions', label: 'Execuções', icon: 'i-lucide-chart-column' },
  { id: 'settings', label: 'Configurações', icon: 'i-lucide-settings-2' },
];
const INPUT_CLASS =
  'reset-base w-full h-9 m-0 px-3 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10';
const SELECT_CLASS =
  'h-9 m-0 py-0 ps-3 pe-8 text-xs rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 w-auto';

const router = useRouter();

const workflows = ref([]);
const stats = ref({ total: 0, active: 0, drafts: 0, paused: 0 });
const currentTab = ref('all');
const searchQuery = ref('');
const selectedSort = ref('recent');
const isLoading = ref(true);
const page = ref(1);

const selectedWorkflow = ref(null);
const drawerTab = ref('overview');
const executions = ref([]);
const isLoadingExecutions = ref(false);
const openMenuId = ref(null);
const settingsForm = ref({ name: '', description: '' });
const isSavingSettings = ref(false);
const pendingArchive = ref(null);

const createDialog = ref(null);
const archiveDialog = ref(null);
const newWorkflowName = ref('');
const newWorkflowDesc = ref('');

const statusMeta = status => STATUS_META[status] || STATUS_META.draft;

const fetchWorkflows = async () => {
  try {
    isLoading.value = true;
    const res = await WorkflowsAPI.getWorkflows({ status: currentTab.value });
    workflows.value = res.data.workflows || [];
    stats.value = res.data.stats || stats.value;
    const stillListed = workflows.value.find(
      wf => wf.id === selectedWorkflow.value?.id
    );
    selectedWorkflow.value = stillListed || workflows.value[0] || null;
  } catch (err) {
    useAlert('Erro ao carregar workflows.');
  } finally {
    isLoading.value = false;
  }
};

onMounted(fetchWorkflows);

const handleTabChange = tab => {
  currentTab.value = tab;
  fetchWorkflows();
};

const openBuilder = (wf, query = {}) =>
  router.push({
    name: 'workflow_builder',
    params: { workflowId: wf.id },
    query,
  });

const openExecutions = wf =>
  router.push({ name: 'workflow_executions', params: { workflowId: wf.id } });

const openCreate = () => {
  newWorkflowName.value = '';
  newWorkflowDesc.value = '';
  createDialog.value?.open();
};

const handleCreateWorkflow = async () => {
  if (!newWorkflowName.value.trim()) return;
  try {
    const res = await WorkflowsAPI.createWorkflow({
      name: newWorkflowName.value.trim(),
      description: newWorkflowDesc.value,
      trigger_type: 'webhook',
      status: 'draft',
    });
    createDialog.value?.close();
    openBuilder(res.data);
  } catch (err) {
    useAlert('Erro ao criar workflow.');
  }
};

const loadExecutions = async () => {
  if (!selectedWorkflow.value) return;
  isLoadingExecutions.value = true;
  try {
    const res = await WorkflowsAPI.getWorkflowExecutions(
      selectedWorkflow.value.id
    );
    executions.value = res.data.slice(0, 8);
  } catch (err) {
    useAlert('Erro ao carregar execuções.');
  } finally {
    isLoadingExecutions.value = false;
  }
};

watch(selectedWorkflow, wf => {
  settingsForm.value = {
    name: wf?.name || '',
    description: wf?.description || '',
  };
  if (drawerTab.value === 'executions') loadExecutions();
});

watch(drawerTab, tab => {
  if (tab === 'executions') loadExecutions();
});

const saveSettings = async () => {
  const name = settingsForm.value.name.trim();
  if (!name) {
    useAlert('O nome do workflow é obrigatório.');
    return;
  }
  isSavingSettings.value = true;
  try {
    await WorkflowsAPI.updateWorkflow(selectedWorkflow.value.id, {
      name,
      description: settingsForm.value.description,
    });
    useAlert('Configurações salvas.');
    await fetchWorkflows();
  } catch (err) {
    useAlert(err.response?.data?.error?.join(' ') || 'Erro ao salvar.');
  } finally {
    isSavingSettings.value = false;
  }
};

const toggleActive = async wf => {
  openMenuId.value = null;
  try {
    if (wf.status === 'active') {
      await WorkflowsAPI.pauseWorkflow(wf.id);
      useAlert('Workflow pausado.');
    } else {
      await WorkflowsAPI.activateWorkflow(wf.id);
      useAlert('Workflow ativado.');
    }
    await fetchWorkflows();
  } catch (err) {
    useAlert(err.response?.data?.error?.join(' ') || 'Erro ao alterar status.');
  }
};

const duplicateWorkflow = async wf => {
  openMenuId.value = null;
  const res = await WorkflowsAPI.duplicateWorkflow(wf.id);
  useAlert('Workflow duplicado.');
  await fetchWorkflows();
  selectedWorkflow.value =
    workflows.value.find(item => item.id === res.data.id) ||
    selectedWorkflow.value;
};

const requestArchive = wf => {
  openMenuId.value = null;
  pendingArchive.value = wf;
  archiveDialog.value?.open();
};

const confirmArchive = async () => {
  await WorkflowsAPI.deleteWorkflow(pendingArchive.value.id);
  archiveDialog.value?.close();
  useAlert('Workflow arquivado.');
  if (selectedWorkflow.value?.id === pendingArchive.value.id) {
    selectedWorkflow.value = null;
  }
  pendingArchive.value = null;
  fetchWorkflows();
};

const copyWebhook = async path => {
  await copyTextToClipboard(`${window.location.origin}${path}`);
  useAlert('URL do webhook copiada.');
};

const formatStamp = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const executionTotal = wf =>
  Number(wf.execution_stats?.total || 0).toLocaleString('pt-BR');

const successRate = wf => Number(wf.execution_stats?.success_rate || 0);

const formatDuration = seconds => {
  if (seconds == null) return '—';
  const total = Math.round(Number(seconds));
  const minutes = Math.floor(total / 60);
  return minutes <= 0 ? `${total % 60}s` : `${minutes}m ${total % 60}s`;
};

const filteredWorkflows = computed(() => {
  const term = searchQuery.value.trim().toLowerCase();
  const list = workflows.value.filter(
    wf =>
      !term ||
      wf.name.toLowerCase().includes(term) ||
      wf.description?.toLowerCase().includes(term)
  );
  return [...list].sort((a, b) => {
    if (selectedSort.value === 'executions') {
      return (b.execution_stats?.total || 0) - (a.execution_stats?.total || 0);
    }
    if (selectedSort.value === 'name') return a.name.localeCompare(b.name);
    return new Date(b.updated_at || 0) - new Date(a.updated_at || 0);
  });
});

const pageCount = computed(() =>
  Math.max(1, Math.ceil(filteredWorkflows.value.length / PER_PAGE))
);
const pagedWorkflows = computed(() => {
  const start = (page.value - 1) * PER_PAGE;
  return filteredWorkflows.value.slice(start, start + PER_PAGE);
});
const pageStart = computed(() =>
  filteredWorkflows.value.length ? (page.value - 1) * PER_PAGE + 1 : 0
);
const pageEnd = computed(() =>
  Math.min(page.value * PER_PAGE, filteredWorkflows.value.length)
);

watch([searchQuery, selectedSort, currentTab], () => {
  page.value = 1;
});
watch(pageCount, count => {
  if (page.value > count) page.value = count;
});

const statusTabs = computed(() => [
  { id: 'all', label: 'Todos', count: stats.value.total },
  { id: 'active', label: 'Ativos', count: stats.value.active },
  { id: 'paused', label: 'Pausados', count: stats.value.paused },
  { id: 'draft', label: 'Rascunhos', count: stats.value.drafts },
]);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-1 w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-x-auto overflow-y-hidden"
  >
    <div class="flex flex-1 flex-col min-w-[46rem] border-e border-n-weak">
      <header
        class="px-6 py-5 border-b border-n-weak bg-n-solid-1 flex items-center justify-between gap-4"
      >
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">Workflows</h1>
          <p class="text-sm text-n-slate-11 mt-0.5">
            Automatize conversas com fluxos visuais e ações integradas.
          </p>
        </div>
        <button
          type="button"
          class="h-10 ps-3 pe-4 rounded-xl bg-n-brand text-white text-sm font-semibold shadow-sm hover:opacity-90 flex items-center gap-2"
          @click="openCreate"
        >
          <span class="i-lucide-plus size-4" />
          Novo workflow
        </button>
      </header>

      <div
        class="flex items-center gap-6 px-6 pt-3 border-b border-n-weak text-sm"
      >
        <button
          v-for="tab in statusTabs"
          :key="tab.id"
          type="button"
          class="pb-3 flex items-center gap-2 font-medium border-b-2 transition-colors"
          :class="
            currentTab === tab.id
              ? 'text-n-slate-12 border-n-brand'
              : 'text-n-slate-11 border-transparent hover:text-n-slate-12'
          "
          @click="handleTabChange(tab.id)"
        >
          {{ tab.label }}
          <span
            class="px-1.5 py-px rounded-md bg-n-alpha-2 text-[0.6875rem] text-n-slate-11"
          >
            {{ tab.count || 0 }}
          </span>
        </button>
      </div>

      <div class="px-6 py-4 flex items-center gap-3">
        <div class="relative flex-1">
          <span
            class="i-lucide-search size-4 absolute start-3 top-1/2 -translate-y-1/2 text-n-slate-10"
          />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar workflows…"
            class="reset-base w-full h-9 m-0 ps-9 pe-3 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
          />
        </div>
        <select v-model="selectedSort" :class="SELECT_CLASS">
          <option value="recent">Mais recentes</option>
          <option value="executions">Mais execuções</option>
          <option value="name">Nome (A–Z)</option>
        </select>
      </div>

      <div class="flex flex-1 flex-col min-h-0 overflow-auto px-6 pb-4">
        <div class="rounded-2xl border border-n-weak bg-n-solid-1">
          <table class="w-full text-start text-sm">
            <thead>
              <tr
                class="border-b border-n-weak text-[0.6875rem] font-semibold text-n-slate-11 uppercase tracking-wide"
              >
                <th class="py-3 px-4 text-start">Nome</th>
                <th class="py-3 px-4 text-start">Status</th>
                <th class="py-3 px-4 text-start">Atualizado</th>
                <th class="py-3 px-4 text-start">Execuções</th>
                <th class="py-3 px-4" />
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="wf in pagedWorkflows"
                :key="wf.id"
                class="cursor-pointer transition-colors"
                :class="
                  selectedWorkflow?.id === wf.id
                    ? 'bg-n-brand/5'
                    : 'hover:bg-n-alpha-1'
                "
                @click="selectedWorkflow = wf"
                @dblclick="openBuilder(wf)"
              >
                <td class="py-3 px-4">
                  <div class="flex items-center gap-3 min-w-0">
                    <div
                      class="size-9 rounded-xl flex items-center justify-center shrink-0 bg-n-amber-9/15 text-n-amber-11"
                    >
                      <span class="i-lucide-webhook size-4" />
                    </div>
                    <div class="min-w-0">
                      <p class="font-medium text-n-slate-12 truncate">
                        {{ wf.name }}
                      </p>
                      <p class="text-xs text-n-slate-11 truncate max-w-[20rem]">
                        {{ wf.description || 'Sem descrição' }}
                      </p>
                    </div>
                  </div>
                </td>
                <td class="py-3 px-4">
                  <span
                    class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-xs font-medium"
                    :class="statusMeta(wf.status).pill"
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="statusMeta(wf.status).dot"
                    />
                    {{ statusMeta(wf.status).label }}
                  </span>
                </td>
                <td class="py-3 px-4 text-xs text-n-slate-11">
                  {{ formatStamp(wf.updated_at) }}
                </td>
                <td class="py-3 px-4">
                  <p class="text-sm text-n-slate-12">
                    {{ executionTotal(wf) }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{ successRate(wf) }}% sucesso
                  </p>
                </td>
                <td class="py-3 px-4 text-end">
                  <OnClickOutside
                    class="relative inline-block"
                    @trigger="openMenuId === wf.id && (openMenuId = null)"
                  >
                    <button
                      type="button"
                      class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
                      title="Ações"
                      @click.stop="
                        openMenuId = openMenuId === wf.id ? null : wf.id
                      "
                    >
                      <span class="i-lucide-ellipsis size-4" />
                    </button>
                    <div
                      v-if="openMenuId === wf.id"
                      class="absolute end-0 top-9 z-30 w-52 p-1 rounded-xl bg-n-solid-2 border border-n-weak shadow-xl text-start"
                      @click.stop
                    >
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="openBuilder(wf)"
                      >
                        <span class="i-lucide-pencil size-4 text-n-slate-11" />
                        Abrir editor
                      </button>
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="openExecutions(wf)"
                      >
                        <span
                          class="i-lucide-chart-column size-4 text-n-slate-11"
                        />
                        Execuções
                      </button>
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="duplicateWorkflow(wf)"
                      >
                        <span class="i-lucide-copy size-4 text-n-slate-11" />
                        Duplicar
                      </button>
                      <button
                        v-if="wf.active_version"
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
                        @click="toggleActive(wf)"
                      >
                        <span
                          class="size-4 text-n-slate-11"
                          :class="
                            wf.status === 'active'
                              ? 'i-lucide-pause'
                              : 'i-lucide-play'
                          "
                        />
                        {{ wf.status === 'active' ? 'Pausar' : 'Ativar' }}
                      </button>
                      <div class="my-1 h-px bg-n-weak" />
                      <button
                        type="button"
                        class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-ruby-11 hover:bg-n-ruby-9/10"
                        @click="requestArchive(wf)"
                      >
                        <span class="i-lucide-archive size-4" /> Arquivar
                      </button>
                    </div>
                  </OnClickOutside>
                </td>
              </tr>
              <tr v-if="!isLoading && !pagedWorkflows.length">
                <td colspan="5" class="py-16 text-center">
                  <span
                    class="i-lucide-workflow size-8 text-n-slate-9 inline-block"
                  />
                  <p class="mt-2 text-sm text-n-slate-11">
                    Nenhum workflow encontrado.
                  </p>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div
        class="shrink-0 px-6 py-3 border-t border-n-weak flex items-center justify-between text-xs text-n-slate-11"
      >
        <span
          >Mostrando {{ pageStart }}–{{ pageEnd }} de
          {{ filteredWorkflows.length }} workflows</span
        >
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="flex items-center justify-center size-7 rounded-lg border border-n-weak disabled:opacity-40"
            title="Página anterior"
            :disabled="page <= 1"
            @click="page -= 1"
          >
            <span class="i-lucide-chevron-left size-4" />
          </button>
          <span class="font-mono">{{ page }} / {{ pageCount }}</span>
          <button
            type="button"
            class="flex items-center justify-center size-7 rounded-lg border border-n-weak disabled:opacity-40"
            title="Próxima página"
            :disabled="page >= pageCount"
            @click="page += 1"
          >
            <span class="i-lucide-chevron-right size-4" />
          </button>
        </div>
      </div>
    </div>

    <aside
      v-if="selectedWorkflow"
      class="w-[24rem] shrink-0 bg-n-solid-1 flex flex-col min-h-0"
    >
      <div class="px-5 pt-5 pb-4 border-b border-n-weak">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="size-10 rounded-xl flex items-center justify-center shrink-0 bg-n-amber-9/15 text-n-amber-11"
            >
              <span class="i-lucide-webhook size-5" />
            </div>
            <div class="min-w-0">
              <h3 class="text-base font-semibold text-n-slate-12 truncate">
                {{ selectedWorkflow.name }}
              </h3>
              <p class="text-xs text-n-slate-11">
                {{
                  selectedWorkflow.active_version
                    ? `Versão v${selectedWorkflow.active_version.version_number}`
                    : 'Nunca publicado'
                }}
                <template v-if="selectedWorkflow.created_by?.name">
                  · {{ selectedWorkflow.created_by.name }}
                </template>
              </p>
            </div>
          </div>
          <span
            class="shrink-0 inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-xs font-medium"
            :class="statusMeta(selectedWorkflow.status).pill"
          >
            <span
              class="size-1.5 rounded-full"
              :class="statusMeta(selectedWorkflow.status).dot"
            />
            {{ statusMeta(selectedWorkflow.status).label }}
          </span>
        </div>
        <div class="flex gap-1 mt-4 p-0.5 rounded-lg bg-n-alpha-1">
          <button
            v-for="tab in TABS"
            :key="tab.id"
            type="button"
            class="flex-1 flex items-center justify-center gap-1.5 h-8 px-1 rounded-md text-xs font-medium whitespace-nowrap transition-colors"
            :class="
              drawerTab === tab.id
                ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="drawerTab = tab.id"
          >
            <span class="size-3.5" :class="tab.icon" />
            {{ tab.label }}
          </button>
        </div>
      </div>

      <div class="flex-1 min-h-0 overflow-y-auto p-5 space-y-5">
        <template v-if="drawerTab === 'overview'">
          <p class="text-sm text-n-slate-11 leading-relaxed">
            {{ selectedWorkflow.description || 'Sem descrição cadastrada.' }}
          </p>
          <div class="grid grid-cols-2 gap-2.5">
            <div class="p-3 rounded-xl bg-n-alpha-1">
              <p class="flex items-center gap-1.5 text-xs text-n-slate-11">
                <span class="i-lucide-chart-column size-3.5" /> Execuções
              </p>
              <p class="mt-1 text-lg font-semibold text-n-slate-12">
                {{ executionTotal(selectedWorkflow) }}
              </p>
            </div>
            <div class="p-3 rounded-xl bg-n-alpha-1">
              <p class="flex items-center gap-1.5 text-xs text-n-slate-11">
                <span class="i-lucide-circle-check size-3.5" /> Sucesso
              </p>
              <p
                class="mt-1 text-lg font-semibold text-green-600 dark:text-green-400"
              >
                {{ successRate(selectedWorkflow) }}%
              </p>
            </div>
            <div class="p-3 rounded-xl bg-n-alpha-1">
              <p class="flex items-center gap-1.5 text-xs text-n-slate-11">
                <span class="i-lucide-timer size-3.5" /> Tempo médio
              </p>
              <p class="mt-1 text-lg font-semibold text-n-slate-12">
                {{
                  formatDuration(
                    selectedWorkflow.execution_stats?.avg_duration_seconds
                  )
                }}
              </p>
            </div>
            <div class="p-3 rounded-xl bg-n-alpha-1">
              <p class="flex items-center gap-1.5 text-xs text-n-slate-11">
                <span class="i-lucide-triangle-alert size-3.5" /> Falhas
              </p>
              <p class="mt-1 text-lg font-semibold text-n-ruby-11">
                {{ selectedWorkflow.execution_stats?.failed || 0 }}
              </p>
            </div>
          </div>
          <div class="p-3.5 rounded-xl border border-n-weak space-y-2">
            <p
              class="flex items-center gap-1.5 text-xs font-medium text-n-slate-12"
            >
              <span class="i-lucide-webhook size-3.5 text-n-amber-11" /> Gatilho
              webhook
            </p>
            <div
              v-if="selectedWorkflow.webhook_path"
              class="flex items-center gap-2 p-2 rounded-lg bg-n-alpha-1"
            >
              <span
                class="flex-1 min-w-0 truncate font-mono text-[0.6875rem] text-n-slate-11"
                >{{ selectedWorkflow.webhook_path }}</span
              >
              <button
                type="button"
                class="flex items-center justify-center size-6 rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
                title="Copiar URL"
                @click="copyWebhook(selectedWorkflow.webhook_path)"
              >
                <span class="i-lucide-copy size-3.5" />
              </button>
            </div>
            <button
              v-else
              type="button"
              class="w-full h-8 rounded-lg border border-dashed border-n-strong text-xs text-n-slate-11 hover:text-n-slate-12 hover:border-n-brand"
              @click="openBuilder(selectedWorkflow, { select: 'trigger' })"
            >
              Gerar URL no editor
            </button>
          </div>
        </template>

        <template v-else-if="drawerTab === 'executions'">
          <div v-if="isLoadingExecutions" class="py-10 flex justify-center">
            <span
              class="i-lucide-loader-circle size-5 animate-spin text-n-slate-10"
            />
          </div>
          <p
            v-else-if="!executions.length"
            class="py-10 text-center text-sm text-n-slate-11"
          >
            Nenhuma execução ainda.
          </p>
          <div
            v-else
            class="rounded-xl border border-n-weak divide-y divide-n-weak"
          >
            <button
              v-for="execution in executions"
              :key="execution.id"
              type="button"
              class="w-full flex items-center gap-3 px-3 py-2.5 text-start hover:bg-n-alpha-1"
              @click="
                router.push({
                  name: 'workflow_execution_detail',
                  params: {
                    workflowId: selectedWorkflow.id,
                    executionId: execution.id,
                  },
                })
              "
            >
              <span
                class="size-4 shrink-0"
                :class="[
                  (
                    EXECUTION_STATUS[execution.status] ||
                    EXECUTION_STATUS.cancelled
                  ).icon,
                  (
                    EXECUTION_STATUS[execution.status] ||
                    EXECUTION_STATUS.cancelled
                  ).classes,
                ]"
              />
              <div class="flex-1 min-w-0">
                <p class="text-sm text-n-slate-12 truncate">
                  {{ execution.contact?.name || `Execução #${execution.id}` }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{ formatStamp(execution.created_at) }}
                </p>
              </div>
              <span
                class="text-xs font-medium"
                :class="
                  (
                    EXECUTION_STATUS[execution.status] ||
                    EXECUTION_STATUS.cancelled
                  ).classes
                "
              >
                {{
                  (
                    EXECUTION_STATUS[execution.status] || {
                      label: execution.status,
                    }
                  ).label
                }}
              </span>
            </button>
          </div>
          <button
            type="button"
            class="text-xs font-medium text-n-brand hover:underline"
            @click="openExecutions(selectedWorkflow)"
          >
            Ver todas as execuções
          </button>
        </template>

        <template v-else>
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
              >Nome</label
            >
            <input
              v-model="settingsForm.name"
              type="text"
              :class="INPUT_CLASS"
            />
          </div>
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
              >Descrição</label
            >
            <textarea
              v-model="settingsForm.description"
              rows="3"
              class="w-full m-0 h-auto px-3 py-2 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            />
          </div>
          <button
            type="button"
            class="w-full h-9 rounded-lg bg-n-brand text-white text-sm font-medium hover:opacity-90 disabled:opacity-50"
            :disabled="isSavingSettings"
            @click="saveSettings"
          >
            {{ isSavingSettings ? 'Salvando…' : 'Salvar alterações' }}
          </button>
          <div class="pt-4 border-t border-n-weak space-y-2">
            <button
              v-if="selectedWorkflow.active_version"
              type="button"
              class="w-full h-9 rounded-lg border border-n-weak text-sm text-n-slate-12 hover:bg-n-alpha-2 flex items-center justify-center gap-2"
              @click="toggleActive(selectedWorkflow)"
            >
              <span
                class="size-4"
                :class="
                  selectedWorkflow.status === 'active'
                    ? 'i-lucide-pause'
                    : 'i-lucide-play'
                "
              />
              {{
                selectedWorkflow.status === 'active'
                  ? 'Pausar workflow'
                  : 'Ativar workflow'
              }}
            </button>
            <button
              type="button"
              class="w-full h-9 rounded-lg border border-n-weak text-sm text-n-slate-12 hover:bg-n-alpha-2 flex items-center justify-center gap-2"
              @click="duplicateWorkflow(selectedWorkflow)"
            >
              <span class="i-lucide-copy size-4" /> Duplicar workflow
            </button>
            <button
              type="button"
              class="w-full h-9 rounded-lg text-sm text-n-ruby-11 hover:bg-n-ruby-9/10 flex items-center justify-center gap-2"
              @click="requestArchive(selectedWorkflow)"
            >
              <span class="i-lucide-archive size-4" /> Arquivar workflow
            </button>
          </div>
        </template>
      </div>

      <div class="p-5 border-t border-n-weak space-y-2">
        <button
          type="button"
          class="w-full h-10 rounded-xl bg-n-brand text-white text-sm font-semibold hover:opacity-90 flex items-center justify-center gap-2"
          @click="openBuilder(selectedWorkflow)"
        >
          <span class="i-lucide-pencil size-4" />
          Abrir no editor
        </button>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="h-9 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 flex items-center justify-center gap-1.5"
            @click="openExecutions(selectedWorkflow)"
          >
            <span class="i-lucide-chart-column size-3.5" /> Execuções
          </button>
          <button
            type="button"
            class="h-9 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 flex items-center justify-center gap-1.5"
            title="Abre o gatilho no editor para escutar uma requisição de teste"
            @click="openBuilder(selectedWorkflow, { select: 'trigger' })"
          >
            <span class="i-lucide-radio size-3.5" /> Testar webhook
          </button>
        </div>
      </div>
    </aside>

    <Dialog
      ref="createDialog"
      title="Novo workflow"
      description="Comece com um gatilho de webhook e adicione blocos no editor."
      confirm-button-label="Criar e abrir editor"
      cancel-button-label="Cancelar"
      :disable-confirm-button="!newWorkflowName.trim()"
      @confirm="handleCreateWorkflow"
    >
      <div class="space-y-3">
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
            >Nome</label
          >
          <input
            v-model="newWorkflowName"
            type="text"
            placeholder="Ex.: Boas-vindas WhatsApp"
            :class="INPUT_CLASS"
          />
        </div>
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
            >Descrição</label
          >
          <textarea
            v-model="newWorkflowDesc"
            rows="3"
            placeholder="Para que serve este fluxo?"
            class="w-full m-0 h-auto px-3 py-2 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
          />
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="archiveDialog"
      type="alert"
      title="Arquivar workflow?"
      :description="`“${pendingArchive?.name || ''}” deixa de receber execuções e sai da lista.`"
      confirm-button-label="Arquivar"
      cancel-button-label="Cancelar"
      @confirm="confirmArchive"
    />
  </div>
</template>
