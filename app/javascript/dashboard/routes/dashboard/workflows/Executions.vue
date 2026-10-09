<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import WorkflowsAPI from 'dashboard/api/workflows';

const route = useRoute();
const router = useRouter();

const workflowId = computed(() => route.params.workflowId);
const executions = ref([]);
const selectedExecution = ref(null);
const isLoading = ref(true);

const fetchExecutions = async () => {
  try {
    isLoading.value = true;
    const res = await WorkflowsAPI.getExecutions({ workflow_id: workflowId.value });
    executions.value = res.data || [];
    if (executions.value.length > 0) {
      inspectExecution(executions.value[0].id);
    }
  } catch (err) {
    console.error('Erro ao buscar execuções:', err);
  } finally {
    isLoading.value = false;
  }
};

const inspectExecution = async (id) => {
  try {
    const res = await WorkflowsAPI.getExecution(id);
    selectedExecution.value = res.data;
  } catch (err) {
    console.error('Erro ao detalhar execução:', err);
  }
};

const handleCancelExecution = async (id) => {
  try {
    await WorkflowsAPI.cancelExecution(id);
    await inspectExecution(id);
    await fetchExecutions();
  } catch (err) {
    console.error('Erro ao cancelar execução:', err);
  }
};

onMounted(() => {
  fetchExecutions();
});
</script>

<template>
  <div class="flex flex-col h-full bg-slate-50 dark:bg-slate-950 overflow-hidden">
    <!-- HEADER -->
    <header class="h-14 px-6 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="p-1.5 rounded-lg text-slate-500 hover:bg-slate-100"
          @click="router.push({ name: 'workflows_index' })"
        >
          ← Voltar
        </button>
        <h1 class="text-sm font-bold text-slate-900 dark:text-white">
          Histórico de Execuções do Workflow
        </h1>
      </div>
    </header>

    <div class="flex flex-1 overflow-hidden">
      <!-- LISTA DE EXECUÇÕES À ESQUERDA -->
      <div class="w-80 border-r border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 overflow-y-auto">
        <div class="p-3 border-b border-slate-100 dark:border-slate-800 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
          Últimas Execuções ({{ executions.length }})
        </div>

        <div class="divide-y divide-slate-100 dark:divide-slate-800">
          <div
            v-for="exec in executions"
            :key="exec.id"
            class="p-3 hover:bg-slate-50 dark:hover:bg-slate-800/40 cursor-pointer transition-colors"
            :class="selectedExecution?.id === exec.id ? 'bg-primary-50/20 border-l-4 border-primary-500' : ''"
            @click="inspectExecution(exec.id)"
          >
            <div class="flex items-center justify-between mb-1">
              <span class="font-mono text-xs font-bold text-slate-900 dark:text-white">
                #{{ exec.id }}
              </span>
              <span
                class="px-2 py-0.5 rounded-full text-[9px] font-bold uppercase"
                :class="[
                  exec.status === 'completed' ? 'bg-emerald-100 text-emerald-700' : '',
                  exec.status === 'running' ? 'bg-sky-100 text-sky-700 animate-pulse' : '',
                  exec.status === 'waiting' ? 'bg-amber-100 text-amber-700' : '',
                  exec.status === 'failed' ? 'bg-rose-100 text-rose-700' : '',
                ]"
              >
                {{ exec.status }}
              </span>
            </div>

            <p class="text-xs font-semibold text-slate-700 dark:text-slate-300 truncate">
              {{ exec.contact?.name || 'Contato Sem Nome' }}
            </p>
            <p class="text-[10px] text-slate-400">
              {{ new Date(exec.created_at).toLocaleTimeString('pt-BR') }} • {{ exec.trigger_type }}
            </p>
          </div>
        </div>
      </div>

      <!-- DETALHE DA EXECUÇÃO E TELEMETRIA DE NODES -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6">
        <div v-if="selectedExecution" class="space-y-6">
          <!-- CARD DE RESUMO -->
          <div class="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm flex items-center justify-between">
            <div>
              <h2 class="text-base font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <span>Execução #{{ selectedExecution.id }}</span>
                <span class="text-xs px-2.5 py-0.5 rounded-full font-bold uppercase bg-slate-100 text-slate-700">
                  {{ selectedExecution.status }}
                </span>
              </h2>
              <p class="text-xs text-slate-500 mt-1">
                Contato: <span class="font-semibold text-slate-800 dark:text-slate-200">{{ selectedExecution.contact?.name }} ({{ selectedExecution.contact?.phone_number }})</span> •
                Conversa: <span class="font-semibold text-slate-800 dark:text-slate-200">#{{ selectedExecution.conversation?.display_id }}</span>
              </p>
            </div>

            <button
              v-if="selectedExecution.status === 'waiting' || selectedExecution.status === 'running'"
              type="button"
              class="px-3 py-1.5 rounded-xl border border-rose-300 text-rose-600 text-xs font-semibold hover:bg-rose-50"
              @click="handleCancelExecution(selectedExecution.id)"
            >
              Cancelar Execução
            </button>
          </div>

          <!-- HISTÓRICO DE NODES EXECUTADOS -->
          <div class="space-y-3">
            <h3 class="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Passos Executados (Telemetria)
            </h3>

            <div class="space-y-2.5">
              <div
                v-for="(nExec, idx) in selectedExecution.node_executions"
                :key="nExec.id"
                class="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-start justify-between shadow-sm"
              >
                <div class="flex items-start gap-3">
                  <div
                    class="w-6 h-6 rounded-full flex items-center justify-center font-bold text-xs"
                    :class="[
                      nExec.status === 'success' ? 'bg-emerald-100 text-emerald-700' : '',
                      nExec.status === 'waiting' ? 'bg-amber-100 text-amber-700' : '',
                      nExec.status === 'failed' ? 'bg-rose-100 text-rose-700' : '',
                    ]"
                  >
                    {{ idx + 1 }}
                  </div>

                  <div>
                    <h4 class="text-xs font-bold text-slate-900 dark:text-white">
                      {{ nExec.node_type }}
                    </h4>
                    <p class="text-[10px] font-mono text-slate-400">ID: {{ nExec.node_id }}</p>

                    <!-- Detalhe do Output / Erro -->
                    <div v-if="nExec.output_data && Object.keys(nExec.output_data).length > 0" class="mt-2 p-2 rounded-lg bg-slate-50 dark:bg-slate-800 text-[11px] font-mono">
                      {{ nExec.output_data }}
                    </div>

                    <p v-if="nExec.error_message" class="text-xs font-semibold text-rose-600 mt-1">
                      ⚠️ {{ nExec.error_message }}
                    </p>
                  </div>
                </div>

                <div class="text-right text-[10px] text-slate-400 font-mono">
                  <span>{{ nExec.duration_ms }}ms</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-else class="p-12 text-center text-slate-400 text-xs">
          Selecione uma execução para ver os detalhes e telemetria.
        </div>
      </div>
    </div>
  </div>
</template>
