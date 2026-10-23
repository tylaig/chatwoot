<script setup>
import { ref, onMounted, onBeforeUnmount, computed, watch } from 'vue';
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
    pill: 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/35',
    dot: 'bg-emerald-400',
  },
  paused: {
    label: 'Pausado',
    pill: 'bg-amber-500/15 text-amber-300 border border-amber-500/35',
    dot: 'bg-amber-400',
  },
  draft: {
    label: 'Rascunho',
    pill: 'bg-slate-500/15 text-slate-300 border border-slate-500/30',
    dot: 'bg-slate-400',
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
const drawerOpen = ref(false);
const isWideLayout = ref(false);
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

let wideLayoutQuery;

const syncWideLayout = () => {
  isWideLayout.value = wideLayoutQuery?.matches || false;
};

const selectWorkflow = wf => {
  selectedWorkflow.value = wf;
  drawerOpen.value = true;
};

const closeDrawer = () => {
  drawerOpen.value = false;
};

const showDrawer = computed(
  () => selectedWorkflow.value && (isWideLayout.value || drawerOpen.value)
);

onMounted(() => {
  wideLayoutQuery = window.matchMedia('(min-width: 1280px)');
  syncWideLayout();
  wideLayoutQuery.addEventListener('change', syncWideLayout);
  fetchWorkflows();
});

onBeforeUnmount(() => {
  wideLayoutQuery?.removeEventListener('change', syncWideLayout);
});

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

const formatStampCompact = value => {
  if (!value) return '—';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
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

const totalExecutionsAll = computed(() =>
  workflows.value.reduce(
    (acc, wf) => acc + Number(wf.execution_stats?.total || 0),
    0
  )
);

const avgSuccessRateAll = computed(() => {
  const withExecs = workflows.value.filter(
    wf => Number(wf.execution_stats?.total || 0) > 0
  );
  if (!withExecs.length) return 0;
  const sum = withExecs.reduce(
    (acc, wf) => acc + Number(wf.execution_stats?.success_rate || 0),
    0
  );
  return Math.round(sum / withExecs.length);
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="msc-workflows-page flex flex-1 w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-hidden"
  >
    <div class="flex flex-1 flex-col min-w-0 min-h-0 overflow-y-auto">
      <header
        class="px-6 py-5 border-b border-emerald-500/15 bg-[#070E13]/90 backdrop-blur-md flex flex-wrap items-center justify-between gap-4 shrink-0"
      >
        <div class="min-w-0">
          <div class="flex items-center gap-2 text-xs text-emerald-400/90 font-medium mb-1">
            <span class="i-lucide-workflow size-3.5" />
            <span>Automação Visual Omnichannel</span>
          </div>
          <h1 class="text-xl font-bold text-white tracking-tight">Workflows</h1>
          <p class="text-sm text-slate-400 mt-0.5">
            Crie e gerencie fluxos visuais, gatilhos de webhook e ações automatizadas no seu atendimento.
          </p>
        </div>
        <button
          type="button"
          class="msc-cta-emerald h-10 ps-3.5 pe-4 rounded-xl bg-emerald-500 text-[#03120D] text-sm font-bold shadow-lg flex items-center gap-2 transition-all"
          @click="openCreate"
        >
          <span class="i-lucide-plus size-4 stroke-[2.5]" />
          Novo workflow
        </button>
      </header>

      <!-- 4 KPI Summary Cards (GPT Image 2.5 Target Spec) -->
      <div class="px-6 pt-5 pb-2 grid grid-cols-2 lg:grid-cols-4 gap-3.5 shrink-0">
        <div
          class="msc-wf-kpi-card p-4 rounded-2xl bg-[#0A1319]/90 border border-emerald-500/20 flex items-center gap-3.5 shadow-lg"
        >
          <div
            class="size-11 rounded-xl bg-emerald-500/15 border border-emerald-500/35 text-emerald-400 flex items-center justify-center shrink-0"
          >
            <span class="i-lucide-network size-5" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-slate-400 truncate">Total de Fluxos</p>
            <p class="text-xl font-bold text-white leading-tight mt-0.5">
              {{ stats.total || workflows.length || 0 }}
            </p>
            <p class="text-[11px] text-emerald-400/80 truncate mt-0.5">Todos os workflows criados</p>
          </div>
        </div>

        <div
          class="msc-wf-kpi-card p-4 rounded-2xl bg-[#0A1319]/90 border border-cyan-500/20 flex items-center gap-3.5 shadow-lg"
        >
          <div
            class="size-11 rounded-xl bg-cyan-500/15 border border-cyan-500/35 text-cyan-400 flex items-center justify-center shrink-0"
          >
            <span class="i-lucide-play-circle size-5" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-slate-400 truncate">Ativos</p>
            <p class="text-xl font-bold text-white leading-tight mt-0.5">
              {{ stats.active || 0 }}
            </p>
            <p class="text-[11px] text-cyan-400/80 truncate mt-0.5">Em execução no momento</p>
          </div>
        </div>

        <div
          class="msc-wf-kpi-card p-4 rounded-2xl bg-[#0A1319]/90 border border-violet-500/20 flex items-center gap-3.5 shadow-lg"
        >
          <div
            class="size-11 rounded-xl bg-violet-500/15 border border-violet-500/35 text-violet-400 flex items-center justify-center shrink-0"
          >
            <span class="i-lucide-activity size-5" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-slate-400 truncate">Execuções Totais</p>
            <p class="text-xl font-bold text-white leading-tight mt-0.5">
              {{ totalExecutionsAll }}
            </p>
            <p class="text-[11px] text-violet-400/80 truncate mt-0.5">Total de disparos processados</p>
          </div>
        </div>

        <div
          class="msc-wf-kpi-card p-4 rounded-2xl bg-[#0A1319]/90 border border-amber-500/20 flex items-center gap-3.5 shadow-lg"
        >
          <div
            class="size-11 rounded-xl bg-amber-500/15 border border-amber-500/35 text-amber-400 flex items-center justify-center shrink-0"
          >
            <span class="i-lucide-sparkles size-5" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-slate-400 truncate">Taxa Média de Sucesso</p>
            <p class="text-xl font-bold text-white leading-tight mt-0.5">
              {{ avgSuccessRateAll }}%
            </p>
            <p class="text-[11px] text-amber-400/80 truncate mt-0.5">Das execuções realizadas</p>
          </div>
        </div>
      </div>

      <!-- Filter Pills & Search Toolbar -->
      <div class="px-6 py-3.5 flex flex-wrap items-center justify-between gap-3 shrink-0">
        <div class="flex items-center gap-2 overflow-x-auto py-0.5">
          <button
            v-for="tab in statusTabs"
            :key="tab.id"
            type="button"
            class="px-3.5 py-1.5 rounded-full flex items-center gap-2 text-xs font-semibold transition-all border"
            :class="
              currentTab === tab.id
                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/45 shadow-sm shadow-emerald-500/10'
                : 'bg-[#0A1319]/80 text-slate-400 border-white/10 hover:text-white hover:border-emerald-500/30'
            "
            @click="handleTabChange(tab.id)"
          >
            {{ tab.label }}
            <span
              class="px-1.5 py-0.5 rounded-full text-[0.6875rem] font-bold"
              :class="
                currentTab === tab.id
                  ? 'bg-emerald-500/25 text-emerald-200'
                  : 'bg-white/[0.06] text-slate-400'
              "
            >
              {{ tab.count || 0 }}
            </span>
          </button>
        </div>

        <div class="flex items-center gap-2.5 flex-1 max-w-md min-w-[15rem]">
          <div class="relative flex-1">
            <span
              class="i-lucide-search size-4 absolute start-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
            />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar workflows…"
              class="msc-wf-search-input reset-base w-full h-9 m-0 ps-10 pe-3 text-sm rounded-xl bg-[#0A1319] border border-white/10 focus:border-emerald-500/50 text-white placeholder:text-slate-500"
            />
          </div>
          <select v-model="selectedSort" :class="SELECT_CLASS">
            <option value="recent">Mais recentes</option>
            <option value="executions">Mais execuções</option>
            <option value="name">Nome (A–Z)</option>
          </select>
        </div>
      </div>

      <div class="flex flex-1 flex-col min-h-0 min-w-0 px-4 sm:px-6 pb-4">
        <div
          class="msc-wf-table-wrap min-h-0 min-w-0 flex-1 overflow-auto rounded-2xl border border-emerald-500/20 bg-[#081015]/90 shadow-xl"
        >
          <table class="w-full text-start text-sm">
            <thead>
              <tr
                class="border-b border-white/[0.07] bg-[#0B151C]/90 text-[0.6875rem] font-semibold text-slate-400 uppercase tracking-wider"
              >
                <th class="py-3.5 px-4 text-start">Nome</th>
                <th class="py-3.5 px-4 w-28 sm:w-32 text-start">Status</th>
                <th class="py-3.5 px-4 w-36 text-start hidden lg:table-cell">Taxa de Sucesso</th>
                <th class="py-3.5 px-4 w-24 sm:w-28 text-start hidden sm:table-cell">Execuções</th>
                <th class="py-3.5 px-4 w-32 text-start hidden xl:table-cell">Última atualização</th>
                <th class="py-3.5 px-4 w-12" />
              </tr>
            </thead>
            <tbody class="divide-y divide-white/[0.06]">
              <tr
                v-for="wf in pagedWorkflows"
                :key="wf.id"
                class="msc-wf-row cursor-pointer transition-all"
                :class="
                  selectedWorkflow?.id === wf.id
                    ? 'msc-wf-row-selected bg-emerald-500/[0.09]'
                    : 'hover:bg-white/[0.03]'
                "
                @click="selectWorkflow(wf)"
                @dblclick="openBuilder(wf)"
              >
                <td class="py-3.5 px-4">
                  <div class="flex items-center gap-3 min-w-0">
                    <div
                      class="size-10 rounded-xl flex items-center justify-center shrink-0 bg-emerald-500/15 text-emerald-400"
                      style="border: 1px solid rgba(16, 185, 129, 0.38);"
                    >
                      <span class="i-lucide-webhook size-5" />
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="font-semibold text-white truncate">
                        {{ wf.name }}
                      </p>
                      <p class="text-xs text-slate-400 truncate mt-0.5 max-w-[14rem] sm:max-w-[20rem] lg:max-w-[24rem]">
                        {{ wf.description || 'Sem descrição' }}
                      </p>
                    </div>
                  </div>
                </td>
                <td class="py-3.5 px-4">
                  <span
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap"
                    :class="statusMeta(wf.status).pill"
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="statusMeta(wf.status).dot"
                    />
                    {{ statusMeta(wf.status).label }}
                  </span>
                </td>
                <td class="py-3.5 px-4 hidden lg:table-cell">
                  <div class="flex flex-col gap-1 pr-3">
                    <span class="text-xs font-semibold text-emerald-300">
                      {{ successRate(wf) }}%
                    </span>
                    <div class="w-full h-1.5 rounded-full bg-white/10 overflow-hidden">
                      <div
                        class="h-full rounded-full bg-emerald-500"
                        :style="{ width: `${Math.max(6, successRate(wf))}%` }"
                      />
                    </div>
                  </div>
                </td>
                <td class="py-3.5 px-4 hidden sm:table-cell">
                  <p class="text-sm font-semibold text-white">
                    {{ executionTotal(wf) }}
                  </p>
                  <p class="text-[11px] text-slate-400 truncate">disparos</p>
                </td>
                <td class="py-3.5 px-4 text-xs text-slate-300 whitespace-nowrap font-mono hidden xl:table-cell">
                  {{ formatStampCompact(wf.updated_at) }}
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
        class="shrink-0 px-6 py-3 border-t border-n-weak flex flex-wrap items-center justify-between gap-2 text-xs text-n-slate-11"
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

    <div
      v-if="showDrawer && !isWideLayout"
      class="fixed inset-0 z-30 bg-n-alpha-black1"
      @click="closeDrawer"
    />
    <aside
      v-if="showDrawer"
      class="msc-wf-drawer bg-[#070E13]/95 backdrop-blur-md border-s border-emerald-500/20 flex flex-col min-h-0"
      :class="
        isWideLayout
          ? 'w-[25rem] shrink-0'
          : 'fixed inset-y-0 end-0 z-40 w-[min(25rem,100%)] shadow-2xl'
      "
    >
      <div class="px-5 pt-5 pb-4 border-b border-white/[0.07]">
        <!-- Hero Banner Card inside Drawer (GPT Image 2.5 Target Spec) -->
        <div
          class="msc-wf-hero-card p-4 rounded-2xl border border-emerald-500/30 shadow-lg relative overflow-hidden"
        >
          <div class="flex items-start justify-between gap-3 relative z-10">
            <div class="flex items-center gap-3 min-w-0">
              <div
                class="size-11 rounded-xl flex items-center justify-center shrink-0 bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 shadow-md shadow-emerald-500/20"
              >
                <span class="i-lucide-webhook size-5" />
              </div>
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <h3 class="text-base font-bold text-white truncate">
                    {{ selectedWorkflow.name }}
                  </h3>
                </div>
                <p class="text-xs text-slate-300 mt-0.5 truncate">
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
            <div class="flex items-center gap-1.5 shrink-0">
              <span
                class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold"
                :class="statusMeta(selectedWorkflow.status).pill"
              >
                <span
                  class="size-1.5 rounded-full"
                  :class="statusMeta(selectedWorkflow.status).dot"
                />
                {{ statusMeta(selectedWorkflow.status).label }}
              </span>
              <button
                v-if="!isWideLayout"
                type="button"
                class="flex items-center justify-center size-7 rounded-lg text-slate-300 hover:bg-white/10 shrink-0"
                title="Fechar"
                @click="closeDrawer"
              >
                <span class="i-lucide-x size-4" />
              </button>
            </div>
          </div>
          <p class="mt-3 text-xs text-slate-300/90 leading-relaxed line-clamp-2">
            {{ selectedWorkflow.description || 'Fluxo de automação visual omnichannel.' }}
          </p>
        </div>

        <div class="flex gap-1 mt-4 p-1 rounded-xl bg-[#0B141B] border border-white/[0.07]">
          <button
            v-for="tab in TABS"
            :key="tab.id"
            type="button"
            class="flex-1 flex items-center justify-center gap-1.5 h-8 px-2 rounded-lg text-xs font-semibold whitespace-nowrap transition-all"
            :class="
              drawerTab === tab.id
                ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/35 shadow-sm'
                : 'text-slate-400 hover:text-white'
            "
            @click="drawerTab = tab.id"
          >
            <span class="size-3.5" :class="tab.icon" />
            {{ tab.label }}
          </button>
        </div>
      </div>

      <div class="flex-1 min-h-0 overflow-y-auto p-5 space-y-4">
        <template v-if="drawerTab === 'overview'">
          <div>
            <h4 class="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2.5">
              Métricas de Desempenho
            </h4>
            <div class="grid grid-cols-2 gap-2.5">
              <div class="p-3.5 rounded-xl bg-[#0B141B] border border-white/[0.07] flex items-start gap-3">
                <div class="size-9 rounded-lg bg-amber-500/15 border border-amber-500/30 text-amber-400 flex items-center justify-center shrink-0">
                  <span class="i-lucide-zap size-4" />
                </div>
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-slate-400">Execuções</p>
                  <p class="mt-0.5 text-lg font-bold text-white leading-tight">
                    {{ executionTotal(selectedWorkflow) }}
                  </p>
                </div>
              </div>
              <div class="p-3.5 rounded-xl bg-[#0B141B] border border-white/[0.07] flex items-start gap-3">
                <div class="size-9 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 flex items-center justify-center shrink-0">
                  <span class="i-lucide-circle-check size-4" />
                </div>
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-slate-400">Sucesso</p>
                  <p class="mt-0.5 text-lg font-bold text-emerald-400 leading-tight">
                    {{ successRate(selectedWorkflow) }}%
                  </p>
                </div>
              </div>
              <div class="p-3.5 rounded-xl bg-[#0B141B] border border-white/[0.07] flex items-start gap-3">
                <div class="size-9 rounded-lg bg-cyan-500/15 border border-cyan-500/30 text-cyan-400 flex items-center justify-center shrink-0">
                  <span class="i-lucide-timer size-4" />
                </div>
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-slate-400">Tempo médio</p>
                  <p class="mt-0.5 text-lg font-bold text-white leading-tight">
                    {{
                      formatDuration(
                        selectedWorkflow.execution_stats?.avg_duration_seconds
                      )
                    }}
                  </p>
                </div>
              </div>
              <div class="p-3.5 rounded-xl bg-[#0B141B] border border-white/[0.07] flex items-start gap-3">
                <div class="size-9 rounded-lg bg-rose-500/15 border border-rose-500/30 text-rose-400 flex items-center justify-center shrink-0">
                  <span class="i-lucide-triangle-alert size-4" />
                </div>
                <div class="min-w-0">
                  <p class="text-[11px] font-medium text-slate-400">Falhas</p>
                  <p class="mt-0.5 text-lg font-bold text-rose-400 leading-tight">
                    {{ selectedWorkflow.execution_stats?.failed || 0 }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div class="msc-wf-webhook-box p-4 rounded-2xl bg-[#0B141B] border border-emerald-500/20 space-y-3">
            <div class="flex items-center gap-2.5">
              <div class="size-8 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 flex items-center justify-center shrink-0">
                <span class="i-lucide-webhook size-4" />
              </div>
              <div class="min-w-0">
                <p class="text-xs font-bold text-white">Gatilho Webhook</p>
                <p class="text-[11px] text-slate-400 truncate">
                  Inicia o fluxo ao receber eventos HTTP
                </p>
              </div>
            </div>
            <div
              v-if="selectedWorkflow.webhook_path"
              class="flex items-center gap-2 p-2.5 rounded-xl bg-[#060C10] border border-white/10"
            >
              <span
                class="flex-1 min-w-0 truncate font-mono text-[0.6875rem] text-emerald-300"
                >{{ selectedWorkflow.webhook_path }}</span
              >
              <button
                type="button"
                class="flex items-center justify-center size-7 rounded-lg text-slate-300 hover:text-emerald-300 hover:bg-emerald-500/15"
                title="Copiar URL"
                @click="copyWebhook(selectedWorkflow.webhook_path)"
              >
                <span class="i-lucide-copy size-3.5" />
              </button>
            </div>
            <button
              v-else
              type="button"
              class="msc-wf-webhook-btn w-full h-9 px-3 rounded-xl border border-dashed border-emerald-500/35 text-xs font-medium text-emerald-300 hover:bg-emerald-500/10 flex items-center justify-between transition-all"
              @click="openBuilder(selectedWorkflow, { select: 'trigger' })"
            >
              <span class="flex items-center gap-1.5">
                <span class="i-lucide-plus size-3.5" />
                Configurar gatilho / Gerar URL no editor
              </span>
              <span class="i-lucide-chevron-right size-3.5" />
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

      <div class="p-5 border-t border-white/[0.07] space-y-2.5">
        <button
          type="button"
          class="msc-cta-emerald w-full h-10 rounded-xl bg-emerald-500 text-[#03120D] text-sm font-bold shadow-lg flex items-center justify-center gap-2 transition-all"
          @click="openBuilder(selectedWorkflow)"
        >
          <span class="i-lucide-external-link size-4 stroke-[2.2]" />
          Abrir no editor
        </button>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="h-9 rounded-xl bg-[#0B141B] border border-white/10 text-xs font-semibold text-slate-200 hover:border-emerald-500/40 hover:text-emerald-300 flex items-center justify-center gap-1.5 transition-all"
            @click="openExecutions(selectedWorkflow)"
          >
            <span class="i-lucide-chart-column size-3.5 text-emerald-400" /> Execuções
          </button>
          <button
            type="button"
            class="h-9 rounded-xl bg-[#0B141B] border border-white/10 text-xs font-semibold text-slate-200 hover:border-emerald-500/40 hover:text-emerald-300 flex items-center justify-center gap-1.5 transition-all"
            title="Abre o gatilho no editor para escutar uma requisição de teste"
            @click="openBuilder(selectedWorkflow, { select: 'trigger' })"
          >
            <span class="i-lucide-play size-3.5 text-emerald-400" /> Testar webhook
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
