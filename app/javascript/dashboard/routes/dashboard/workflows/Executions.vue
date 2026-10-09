<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import WorkflowsAPI from 'dashboard/api/workflows';

const route = useRoute();
const router = useRouter();

const workflowId = computed(() => route.params.workflowId);
const workflow = ref(null);
const executions = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const statusFilter = ref('ALL');

const fetchExecutions = async () => {
  try {
    isLoading.value = true;
    const [wfRes, execsRes] = await Promise.all([
      WorkflowsAPI.getWorkflow(workflowId.value),
      WorkflowsAPI.getExecutions({ workflow_id: workflowId.value }),
    ]);
    workflow.value = wfRes.data;
    executions.value = execsRes.data.executions || [];
  } catch (err) {
    console.error('Erro ao buscar execuções:', err);
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

const formatDuration = (start, end) => {
  if (!start) return '-';
  const s = new Date(start).getTime();
  const e = end ? new Date(end).getTime() : Date.now();
  const diff = Math.max(0, e - s);
  if (diff < 1000) return `${diff} ms`;
  if (diff < 60000) return `${(diff / 1000).toFixed(1)}s`;
  return `${Math.floor(diff / 60000)}m ${Math.floor((diff % 60000) / 1000)}s`;
};

onMounted(() => {
  fetchExecutions();
});
</script>

<template>
  <div class="flex flex-col h-full bg-n-background text-n-slate-12 overflow-hidden select-none">
    <!-- HEADER DA PÁGINA -->
    <header class="h-16 px-6 border-b border-n-weak bg-n-solid-1 flex items-center justify-between shrink-0">
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
          <span>←</span>
          <span>Voltar ao Builder</span>
        </button>
        <div class="w-px h-5 bg-n-weak" />
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-sm font-bold text-n-slate-12">Histórico de Execuções</h1>
            <span class="text-xs text-n-slate-11">•</span>
            <span class="text-xs font-mono text-n-slate-11">
              {{ workflow?.name || 'Carregando...' }}
            </span>
          </div>
          <p class="text-[11px] text-n-slate-11 font-sans mt-0.5">
            {{ executions.length }} execuções registradas para este fluxo
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
          <span :class="isLoading ? 'animate-spin' : ''">🔄</span>
          <span>Atualizar Lista</span>
        </button>
      </div>
    </header>

    <!-- BARRA DE FILTROS E BUSCA -->
    <div class="p-6 pb-4 flex flex-col md:flex-row gap-3 items-center justify-between shrink-0">
      <div class="relative w-full md:w-80 flex items-center">
        <span class="absolute left-3.5 text-xs text-n-slate-9 pointer-events-none">🔍</span>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Buscar por ID, contato ou gatilho..."
          class="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-n-blue-9 transition-colors"
        />
      </div>

      <div class="flex items-center gap-3 w-full md:w-auto">
        <div class="flex items-center gap-2">
          <span class="text-xs text-n-slate-11">Filtrar Status:</span>
          <select
            v-model="statusFilter"
            class="px-3 py-2 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-n-blue-9"
          >
            <option value="ALL">Todos os Status</option>
            <option value="COMPLETED">Concluídos (Completed)</option>
            <option value="RUNNING">Executando (Running)</option>
            <option value="WAITING">Aguardando (Waiting)</option>
            <option value="FAILED">Falhas (Failed)</option>
          </select>
        </div>
      </div>
    </div>

    <!-- TABELA DE EXECUÇÕES -->
    <div class="flex-1 overflow-y-auto px-6 pb-6">
      <div class="border border-n-weak rounded-2xl bg-n-solid-1 overflow-hidden shadow-sm">
        <table class="w-full text-left border-collapse text-xs">
          <thead>
            <tr class="border-b border-n-weak bg-n-alpha-1 text-[11px] font-semibold text-n-slate-11 uppercase tracking-wider">
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
                  :class="
                    exec.status === 'completed'
                      ? 'bg-n-teal-3 text-n-teal-11 border border-n-teal-7'
                      : exec.status === 'running'
                        ? 'bg-n-blue-3 text-n-blue-11 border border-n-blue-7 animate-pulse'
                        : exec.status === 'waiting'
                          ? 'bg-n-amber-3 text-n-amber-11 border border-n-amber-7'
                          : exec.status === 'failed'
                            ? 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-7'
                            : 'bg-n-slate-3 text-n-slate-11 border border-n-slate-7'
                  "
                >
                  <span
                    class="w-1.5 h-1.5 rounded-full"
                    :class="
                      exec.status === 'completed'
                        ? 'bg-n-teal-9'
                        : exec.status === 'running'
                          ? 'bg-n-blue-9'
                          : exec.status === 'waiting'
                            ? 'bg-n-amber-9'
                            : exec.status === 'failed'
                              ? 'bg-n-ruby-9'
                              : 'bg-n-slate-9'
                    "
                  />
                  {{ exec.status }}
                </span>
              </td>

              <!-- GATILHO -->
              <td class="py-3.5 px-4 font-mono text-n-slate-11">
                <span class="inline-flex items-center gap-1">
                  <span>⚡</span>
                  <span>{{ exec.trigger_type || 'manual' }}</span>
                </span>
              </td>

              <!-- CONTATO -->
              <td class="py-3.5 px-4 text-n-slate-12">
                <div v-if="exec.contact" class="flex flex-col">
                  <span class="font-medium text-n-slate-12">{{ exec.contact.name || 'Contato sem nome' }}</span>
                  <span class="text-[11px] text-n-slate-11 font-mono">{{ exec.contact.phone_number || exec.contact.email || '' }}</span>
                </div>
                <span v-else class="text-n-slate-11">-</span>
              </td>

              <!-- DATA DE INÍCIO -->
              <td class="py-3.5 px-4 text-n-slate-11 font-mono text-[11px]">
                {{ formatDate(exec.started_at || exec.created_at) }}
              </td>

              <!-- DURAÇÃO -->
              <td class="py-3.5 px-4 text-n-slate-11 font-mono text-[11px]">
                {{ formatDuration(exec.started_at || exec.created_at, exec.completed_at || exec.finished_at) }}
              </td>

              <!-- AÇÃO: VER GRAFO -->
              <td class="py-3.5 px-4 text-right" @click.stop>
                <button
                  type="button"
                  class="px-3.5 py-1.5 rounded-xl bg-n-blue-9 hover:bg-n-blue-10 text-white font-semibold text-xs transition-all shadow-sm inline-flex items-center gap-1.5 cursor-pointer"
                  @click="goToExecutionGraph(exec.id)"
                >
                  <span>Ver Grafo</span>
                  <span>→</span>
                </button>
              </td>
            </tr>

            <!-- EMPTY STATE -->
            <tr v-if="!filteredExecutions.length">
              <td colspan="7" class="py-12 text-center text-n-slate-11">
                <div class="flex flex-col items-center justify-center gap-2">
                  <span class="text-2xl">📋</span>
                  <p class="font-medium">Nenhuma execução encontrada.</p>
                  <p class="text-[11px] text-n-slate-9">
                    {{ isLoading ? 'Buscando registros...' : 'Execute este workflow para visualizar o histórico de execuções aqui.' }}
                  </p>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>