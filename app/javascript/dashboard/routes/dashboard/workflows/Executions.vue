<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import WorkflowsAPI from 'dashboard/api/workflows';

const route = useRoute();
const router = useRouter();

const PER_PAGE = 25;
const STATUS_META = {
  completed: {
    label: 'Concluída',
    pill: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-7',
    dot: 'bg-n-teal-9',
  },
  running: {
    label: 'Executando',
    pill: 'bg-n-iris-3 text-n-iris-11 border border-n-iris-7',
    dot: 'bg-n-iris-9',
  },
  waiting: {
    label: 'Aguardando',
    pill: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-7',
    dot: 'bg-n-amber-9',
  },
  failed: {
    label: 'Falhou',
    pill: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-7',
    dot: 'bg-n-ruby-9',
  },
  cancelled: {
    label: 'Cancelada',
    pill: 'bg-n-slate-3 text-n-slate-11 border border-n-slate-7',
    dot: 'bg-n-slate-9',
  },
  paused: {
    label: 'Pausada',
    pill: 'bg-n-slate-3 text-n-slate-11 border border-n-slate-7',
    dot: 'bg-n-slate-9',
  },
};

const workflowId = computed(() => route.params.workflowId);
const workflow = ref(null);
const executions = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const statusFilter = ref('ALL');
const page = ref(1);
const totalCount = ref(0);
const totalPages = ref(1);

const statusMeta = status => STATUS_META[status] || STATUS_META.cancelled;

const fetchExecutions = async () => {
  try {
    isLoading.value = true;
    const params = { workflow_id: workflowId.value, page: page.value };
    if (statusFilter.value !== 'ALL') params.status = statusFilter.value;
    const [wfRes, execsRes] = await Promise.all([
      WorkflowsAPI.getWorkflow(workflowId.value),
      WorkflowsAPI.getExecutions(params),
    ]);
    workflow.value = wfRes.data;
    executions.value = execsRes.data.executions || [];
    totalCount.value =
      execsRes.data.meta?.total_count ?? executions.value.length;
    totalPages.value = execsRes.data.meta?.total_pages || 1;
  } catch {
    executions.value = [];
  } finally {
    isLoading.value = false;
  }
};

const goToExecutionGraph = execId => {
  router.push({
    name: 'workflow_execution_detail',
    params: {
      workflowId: workflowId.value,
      executionId: execId,
    },
  });
};

const filteredExecutions = computed(() => {
  return executions.value.filter(e => {
    const matchesStatus =
      statusFilter.value === 'ALL' ||
      e.status?.toLowerCase() === statusFilter.value.toLowerCase();
    const matchesSearch =
      !searchQuery.value ||
      String(e.id).includes(searchQuery.value) ||
      (e.contact?.name &&
        e.contact.name
          .toLowerCase()
          .includes(searchQuery.value.toLowerCase())) ||
      (e.trigger_type &&
        e.trigger_type.toLowerCase().includes(searchQuery.value.toLowerCase()));

    return matchesStatus && matchesSearch;
  });
});

const formatDate = dateStr => {
  if (!dateStr) return '-';
  try {
    const d = new Date(dateStr);
    return d.toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  } catch {
    return dateStr;
  }
};

const formatDuration = exec => {
  if (['running', 'waiting'].includes(exec.status) && !exec.finished_at) {
    return 'Em andamento';
  }
  const start = exec.started_at || exec.created_at;
  const end = exec.finished_at;
  if (!start || !end) return '—';
  const diff = Math.max(0, new Date(end).getTime() - new Date(start).getTime());
  if (diff < 1000) return `${diff} ms`;
  if (diff < 60000) return `${(diff / 1000).toFixed(1)}s`;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 60) return `${minutes}m ${Math.floor((diff % 60000) / 1000)}s`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
};

const pageStart = computed(() =>
  totalCount.value ? (page.value - 1) * PER_PAGE + 1 : 0
);
const pageEnd = computed(() =>
  executions.value.length
    ? Math.min(
        page.value * PER_PAGE,
        pageStart.value + executions.value.length - 1
      )
    : 0
);

watch(statusFilter, () => {
  if (page.value !== 1) page.value = 1;
  else fetchExecutions();
});
watch(page, fetchExecutions);
watch(workflowId, () => {
  searchQuery.value = '';
  if (statusFilter.value !== 'ALL') statusFilter.value = 'ALL';
  else if (page.value !== 1) page.value = 1;
  else fetchExecutions();
});

onMounted(fetchExecutions);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-1 flex-col w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-x-auto overflow-y-hidden"
  >
    <!-- HEADER DA PÁGINA -->
    <header
      class="h-16 px-6 border-b border-n-weak bg-n-solid-1 flex items-center justify-between shrink-0"
    >
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="px-3 py-1.5 rounded-xl border border-n-weak bg-n-solid-2 hover:bg-n-alpha-2 text-xs font-semibold text-n-slate-12 transition-colors flex items-center gap-1.5"
          @click="
            router.push({
              name: 'workflow_builder',
              params: { workflowId: workflowId },
            })
          "
        >
          <span class="i-lucide-arrow-left size-4" />
          <span>Voltar ao Builder</span>
        </button>
        <div class="w-px h-5 bg-n-weak" />
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-sm font-bold text-n-slate-12">
              Histórico de Execuções
            </h1>
            <span class="size-1 rounded-full bg-n-slate-9" />
            <span class="text-xs font-mono text-n-slate-11">
              {{ workflow?.name || 'Carregando...' }}
            </span>
          </div>
          <p class="text-[11px] text-n-slate-11 font-sans mt-0.5">
            {{ totalCount }} execuções registradas para este fluxo
          </p>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button
          type="button"
          class="px-3 py-1.5 rounded-xl border border-n-weak bg-n-solid-2 hover:bg-n-alpha-2 text-xs font-semibold text-n-slate-12 transition-colors flex items-center gap-1.5"
          :disabled="isLoading"
          @click="fetchExecutions"
        >
          <span
            class="i-lucide-refresh-cw size-4"
            :class="isLoading ? 'animate-spin' : ''"
          />
          <span>Atualizar Lista</span>
        </button>
      </div>
    </header>

    <!-- BARRA DE FILTROS E BUSCA -->
    <div
      class="p-6 pb-4 flex flex-col md:flex-row gap-3 items-center justify-between shrink-0"
    >
      <div class="relative w-full md:w-80">
        <span
          class="i-lucide-search size-3.5 absolute start-3.5 top-1/2 -translate-y-1/2 text-n-slate-9 pointer-events-none"
        />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Buscar por ID, contato ou gatilho..."
          class="reset-base w-full h-9 m-0 ps-9 pe-4 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-n-brand transition-colors"
        />
      </div>

      <div class="flex items-center gap-2 w-full md:w-auto">
        <span class="text-xs text-n-slate-11 whitespace-nowrap">Status</span>
        <select
          v-model="statusFilter"
          class="reset-base h-9 m-0 w-auto py-0 ps-3 pe-8 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
        >
          <option value="ALL">Todos</option>
          <option value="completed">Concluídas</option>
          <option value="running">Executando</option>
          <option value="waiting">Aguardando</option>
          <option value="failed">Falhas</option>
          <option value="cancelled">Canceladas</option>
        </select>
      </div>
    </div>

    <!-- TABELA DE EXECUÇÕES -->
    <div class="flex-1 overflow-auto px-6 pb-6">
      <div
        class="min-w-[48rem] border border-n-weak rounded-2xl bg-n-solid-1 shadow-sm"
      >
        <table class="w-full text-left border-collapse text-xs">
          <thead>
            <tr
              class="border-b border-n-weak bg-n-alpha-1 text-[11px] font-semibold text-n-slate-11 uppercase tracking-wider"
            >
              <th class="py-3 px-4">ID</th>
              <th class="py-3 px-4">Status</th>
              <th class="py-3 px-4">Gatilho</th>
              <th class="py-3 px-4">Contato</th>
              <th class="py-3 px-4">Iniciado em</th>
              <th class="py-3 px-4">Duração</th>
              <th class="py-3 px-4 text-right">Ações</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="exec in filteredExecutions"
              :key="exec.id"
              class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
              @click="goToExecutionGraph(exec.id)"
            >
              <!-- ID -->
              <td class="py-3.5 px-4 font-mono font-bold text-n-slate-12">
                #{{ exec.id }}
              </td>

              <!-- STATUS BADGE -->
              <td class="py-3.5 px-4">
                <span
                  class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1.5"
                  :class="statusMeta(exec.status).pill"
                >
                  <span
                    class="w-1.5 h-1.5 rounded-full"
                    :class="statusMeta(exec.status).dot"
                  />
                  {{ statusMeta(exec.status).label }}
                </span>
                <p
                  v-if="exec.error_message"
                  class="mt-1 max-w-56 text-[11px] text-n-ruby-11 line-clamp-2"
                  :title="exec.error_message"
                >
                  {{ exec.error_message }}
                </p>
              </td>

              <!-- GATILHO -->
              <td class="py-3.5 px-4 font-mono text-n-slate-11">
                <span class="inline-flex items-center gap-1">
                  <span class="i-lucide-webhook size-3.5" />
                  <span>{{ exec.trigger_type || 'manual' }}</span>
                </span>
              </td>

              <!-- CONTATO -->
              <td class="py-3.5 px-4 text-n-slate-12">
                <div v-if="exec.contact" class="flex flex-col">
                  <span class="font-medium text-n-slate-12">{{
                    exec.contact.name || 'Contato sem nome'
                  }}</span>
                  <span class="text-[11px] text-n-slate-11 font-mono">{{
                    exec.contact.phone_number || exec.contact.email || ''
                  }}</span>
                </div>
                <span v-else class="text-n-slate-11">-</span>
              </td>

              <!-- DATA DE INÍCIO -->
              <td class="py-3.5 px-4 text-n-slate-11 font-mono text-[11px]">
                {{ formatDate(exec.started_at || exec.created_at) }}
              </td>

              <!-- DURAÇÃO -->
              <td class="py-3.5 px-4 text-n-slate-11 font-mono text-[11px]">
                {{ formatDuration(exec) }}
              </td>

              <!-- AÇÃO: VER GRAFO -->
              <td class="py-3.5 px-4 text-right" @click.stop>
                <button
                  type="button"
                  class="px-3.5 py-1.5 rounded-xl bg-n-blue-9 hover:bg-n-blue-10 text-white font-semibold text-xs transition-all shadow-sm inline-flex items-center gap-1.5 cursor-pointer"
                  @click="goToExecutionGraph(exec.id)"
                >
                  <span>Ver Grafo</span>
                  <span class="i-lucide-arrow-right size-3.5" />
                </button>
              </td>
            </tr>

            <!-- EMPTY STATE -->
            <tr v-if="!filteredExecutions.length">
              <td colspan="7" class="py-12 text-center text-n-slate-11">
                <div class="flex flex-col items-center justify-center gap-2">
                  <span class="i-lucide-clipboard-list size-6" />
                  <p class="font-medium">Nenhuma execução encontrada.</p>
                  <p class="text-[11px] text-n-slate-9">
                    {{
                      isLoading
                        ? 'Buscando registros...'
                        : 'Execute este workflow para visualizar o histórico de execuções aqui.'
                    }}
                  </p>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div
      class="shrink-0 px-6 py-3 border-t border-n-weak flex items-center justify-between text-xs text-n-slate-11"
    >
      <span>
        Mostrando {{ pageStart }}–{{ pageEnd }} de {{ totalCount }} execuções
      </span>
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="flex items-center justify-center size-7 rounded-lg border border-n-weak disabled:opacity-40"
          title="Página anterior"
          :disabled="page <= 1 || isLoading"
          @click="page -= 1"
        >
          <span class="i-lucide-chevron-left size-4" />
        </button>
        <span class="font-mono">{{ page }} / {{ totalPages }}</span>
        <button
          type="button"
          class="flex items-center justify-center size-7 rounded-lg border border-n-weak disabled:opacity-40"
          title="Próxima página"
          :disabled="page >= totalPages || isLoading"
          @click="page += 1"
        >
          <span class="i-lucide-chevron-right size-4" />
        </button>
      </div>
    </div>
  </div>
</template>
