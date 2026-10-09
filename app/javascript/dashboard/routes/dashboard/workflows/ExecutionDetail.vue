<script setup>
import { ref, onMounted, computed, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

import WorkflowsAPI from 'dashboard/api/workflows';
import WorkflowNodeCard from './components/WorkflowNodeCard.vue';
import { getNodeDefinition } from './nodeRegistry';

const route = useRoute();
const router = useRouter();

const workflowId = computed(() => route.params.workflowId);
const executionId = computed(() => route.params.executionId);

const workflow = ref(null);
const execution = ref(null);
const selectedNodeExecution = ref(null);
const isLoading = ref(true);
const isRetrying = ref(false);

const elements = ref([]);

const { fitView } = useVueFlow();

const selectedNodeMeta = computed(() => {
  if (!selectedNodeExecution.value?.node_type) return null;
  return getNodeDefinition(selectedNodeExecution.value.node_type);
});

// Carregar execução detalhada e montar o grafo exato da versão executada
const fetchExecutionDetail = async () => {
  try {
    isLoading.value = true;
    const [wfRes, execRes] = await Promise.all([
      WorkflowsAPI.getWorkflow(workflowId.value),
      WorkflowsAPI.getExecution(executionId.value),
    ]);

    workflow.value = wfRes.data;
    execution.value = execRes.data;

    buildExecutionGraph(execRes.data, wfRes.data);
  } catch (err) {
    console.error('Erro ao buscar detalhe da execução:', err);
  } finally {
    isLoading.value = false;
  }
};

const buildExecutionGraph = (execData, wfData) => {
  const version =
    execData.workflow_version ||
    wfData?.current_version ||
    wfData?.draft_version || { nodes: [], edges: [] };

  const nodeExecutions = execData.node_executions || [];
  const executedNodeIds = new Set(nodeExecutions.map(ne => String(ne.node_id)));

  // Mapear nós originais com posições e propriedades de execução
  const mappedNodes = (version.nodes || []).map((n, idx) => {
    const stringId = String(n.id);
    const ne = nodeExecutions.find(item => String(item.node_id) === stringId);

    let status = 'skipped';
    if (ne) {
      status =
        ne.status === 'success' || ne.status === 'completed'
          ? 'completed'
          : ne.status;
    } else if (
      stringId === String(execData.current_node_id) &&
      execData.status === 'running'
    ) {
      status = 'running';
    } else if (
      stringId === String(execData.current_node_id) &&
      execData.status === 'waiting'
    ) {
      status = 'waiting';
    }

    const pos =
      n.position && typeof n.position.x === 'number'
        ? n.position
        : { x: 80 + idx * 360, y: 220 };

    return {
      ...n,
      position: pos,
      type: 'custom',
      draggable: false,
      selectable: true,
      data: {
        type: n.data?.type || n.type,
        config: n.data?.config || n.config || {},
        execution: ne || null,
        executionStatus: status,
        isExecuted: executedNodeIds.has(stringId),
        readOnly: true,
      },
    };
  });

  // Mapear arestas com destaque no path percorrido e atenuação nas não executadas
  const mappedEdges = (version.edges || []).map(e => {
    const isTraversed =
      executedNodeIds.has(String(e.source)) &&
      executedNodeIds.has(String(e.target));

    const edgeColor = isTraversed
      ? e.sourceHandle === 'false' || e.sourceHandle === 'TIMEOUT' || e.sourceHandle === 'error'
        ? '#EF4444'
        : '#10B981'
      : '#94A3B8';

    return {
      ...e,
      animated: isTraversed,
      style: {
        stroke: edgeColor,
        strokeWidth: isTraversed ? 3 : 1.5,
        opacity: isTraversed ? 1 : 0.25,
      },
    };
  });

  elements.value = [...mappedNodes, ...mappedEdges];

  nextTick(() => {
    setTimeout(() => {
      fitView({ padding: 0.25 });
    }, 200);
  });
};

const selectNodeForInspector = (ne, nodeObj) => {
  const nodeId = ne?.node_id || nodeObj?.id;
  const nodeType = ne?.node_type || nodeObj?.data?.type || nodeObj?.type;
  const nodeDef = getNodeDefinition(nodeType);
  const nodeName =
    nodeObj?.data?.config?.custom_title ||
    nodeObj?.config?.custom_title ||
    nodeDef?.title ||
    nodeType;

  if (ne) {
    selectedNodeExecution.value = {
      ...ne,
      node_name: nodeName,
      node_type: nodeType,
    };
  } else {
    selectedNodeExecution.value = {
      node_id: nodeId,
      node_name: nodeName,
      node_type: nodeType,
      status: 'skipped',
      input_data: nodeObj?.config || nodeObj?.data?.config || {},
      output_data: {},
      error_message: null,
      duration_ms: 0,
      retry_count: 0,
      started_at: null,
      finished_at: null,
    };
  }
};

const handleNodeClick = event => {
  const clickedNode = event.node;
  const ne = execution.value?.node_executions?.find(
    item => String(item.node_id) === String(clickedNode.id)
  );
  selectNodeForInspector(ne, clickedNode);
};

const retryExecution = async () => {
  if (!execution.value) return;
  try {
    isRetrying.value = true;
    await WorkflowsAPI.getExecution(execution.value.id);
    await fetchExecutionDetail();
  } catch (err) {
    console.error('Erro ao retentar execução:', err);
  } finally {
    isRetrying.value = false;
  }
};

onMounted(() => {
  fetchExecutionDetail();
});
</script>

<template>
  <div
    class="flex flex-col h-full bg-n-background text-n-slate-12 overflow-hidden select-none"
  >
    <!-- BARRA SUPERIOR DE NAVEGAÇÃO -->
    <header
      class="h-14 px-6 border-b border-n-weak bg-n-solid-1 flex items-center justify-between z-20 shrink-0"
    >
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="px-2.5 py-1.5 rounded-xl border border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2 text-n-slate-12 text-xs font-semibold flex items-center gap-1.5 transition-colors"
          @click="
            router.push({
              name: 'workflow_executions',
              params: { workflowId },
            })
          "
        >
          <span>←</span>
          <span>Lista de Execuções</span>
        </button>

        <div class="h-4 w-px bg-n-weak" />

        <div class="flex items-center gap-2">
          <h1 class="text-xs font-bold text-n-slate-12 flex items-center gap-2">
            <span>Execução</span>
            <span class="font-mono text-n-blue-9">#{{ executionId }}</span>
          </h1>
          <span class="text-n-slate-9">•</span>
          <span class="text-xs text-n-slate-11 font-medium">
            {{ workflow?.name || 'Workflow' }}
          </span>
        </div>
      </div>

      <!-- BADGES E AÇÕES DA EXECUÇÃO -->
      <div v-if="execution" class="flex items-center gap-3 text-xs">
        <div class="flex items-center gap-2 px-3 py-1 rounded-xl bg-n-alpha-1 border border-n-weak">
          <span class="text-n-slate-9 text-[11px]">Status:</span>
          <span
            class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider"
            :class="
              execution.status === 'completed'
                ? 'bg-n-teal-3 text-n-teal-11 border border-n-teal-7'
                : execution.status === 'failed'
                  ? 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-7'
                  : execution.status === 'running'
                    ? 'bg-n-blue-9/20 text-n-blue-9 border border-blue-500/30 animate-pulse'
                    : 'bg-n-amber-3 text-n-amber-11 border border-n-amber-7'
            "
          >
            {{ execution.status }}
          </span>
        </div>

        <div class="hidden sm:flex items-center gap-2 px-3 py-1 rounded-xl bg-n-alpha-1 border border-n-weak text-[11px] text-n-slate-11">
          <span>Gatilho:</span>
          <span class="font-mono font-bold text-n-slate-12">{{ execution.trigger_type || 'manual' }}</span>
        </div>

        <div class="hidden md:flex items-center gap-2 px-3 py-1 rounded-xl bg-n-alpha-1 border border-n-weak text-[11px] text-n-slate-11">
          <span>Contato:</span>
          <span class="font-bold text-n-slate-12">{{ execution.contact?.name || 'Lead #1' }}</span>
        </div>

        <button
          type="button"
          class="px-3 py-1.5 rounded-xl border border-n-weak bg-n-solid-2 hover:bg-n-alpha-2 text-xs font-semibold text-n-slate-12 flex items-center gap-1.5 transition-colors"
          :disabled="isRetrying"
          @click="retryExecution"
        >
          <span>🔄</span>
          <span>Retentar</span>
        </button>
      </div>
    </header>

    <!-- CORPO COM CANVAS DO GRAFO E INSPECTOR LATERAL -->
    <div class="flex flex-1 overflow-hidden relative">
      <!-- CANVAS DO GRAFO READ-ONLY -->
      <div class="flex-1 h-full w-full relative bg-n-background">
        <!-- LEGENDA FLUTUANTE DE ESTADOS VISUAIS (DESIGN SYSTEM NATIVO) -->
        <div
          class="absolute top-4 left-6 z-10 p-2.5 rounded-2xl bg-n-solid-1/90 border border-n-weak shadow-xl backdrop-blur-md flex flex-wrap items-center gap-4 text-xs font-semibold"
        >
          <span class="text-n-slate-11 font-mono text-[11px]">
            Modo Read-Only
          </span>
          <div class="h-3 w-px bg-n-weak" />
          <span class="flex items-center gap-1.5 text-n-teal-11">
            <span class="w-2.5 h-2.5 rounded-full bg-n-teal-9" />
            COMPLETED
          </span>
          <span class="flex items-center gap-1.5 text-n-blue-9">
            <span class="w-2.5 h-2.5 rounded-full bg-n-blue-9 animate-pulse" />
            RUNNING
          </span>
          <span class="flex items-center gap-1.5 text-n-amber-11">
            <span class="w-2.5 h-2.5 rounded-full bg-n-amber-9" />
            WAITING
          </span>
          <span class="flex items-center gap-1.5 text-n-ruby-11">
            <span class="w-2.5 h-2.5 rounded-full bg-n-ruby-9" />
            FAILED
          </span>
          <span class="flex items-center gap-1.5 text-n-slate-9">
            <span class="w-2.5 h-2.5 rounded-full bg-n-slate-9" />
            SKIPPED
          </span>
        </div>

        <!-- GRAFO VUE FLOW -->
        <VueFlow
          v-model="elements"
          :nodes-draggable="false"
          :nodes-connectable="false"
          :elements-selectable="true"
          :snap-to-grid="false"
          fit-view-on-init
          class="h-full w-full"
          @node-click="handleNodeClick"
        >
          <Background pattern-color="#94A3B8" :gap="20" :size="1" />
          <Controls position="bottom-left" />

          <!-- RENDERER CUSTOMIZADO COM ESTADOS DE EXECUÇÃO -->
          <template #node-custom="{ id, data }">
            <div
              class="relative transition-all cursor-pointer rounded-2xl"
              :class="[
                data.executionStatus === 'completed'
                  ? 'ring-2 ring-n-teal-9 shadow-lg shadow-n-teal-9/20'
                  : '',
                data.executionStatus === 'running'
                  ? 'ring-2 ring-n-blue-9 shadow-lg shadow-n-blue-9/20 animate-pulse'
                  : '',
                data.executionStatus === 'waiting'
                  ? 'ring-2 ring-n-amber-9 shadow-lg shadow-n-amber-9/20'
                  : '',
                data.executionStatus === 'failed'
                  ? 'ring-2 ring-n-ruby-9 shadow-lg shadow-n-ruby-9/20'
                  : '',
                data.executionStatus === 'skipped'
                  ? 'opacity-40 filter grayscale contrast-75'
                  : 'opacity-100',
              ]"
            >
              <!-- BADGE FLUTUANTE DE STATUS DO NÓ -->
              <div
                class="absolute -top-3 right-3 z-20 px-2 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider shadow-md"
                :class="
                  data.executionStatus === 'completed'
                    ? 'bg-n-teal-9 text-white'
                    : data.executionStatus === 'running'
                      ? 'bg-n-blue-9 text-white animate-pulse'
                      : data.executionStatus === 'waiting'
                        ? 'bg-n-amber-9 text-white'
                        : data.executionStatus === 'failed'
                          ? 'bg-n-ruby-9 text-white'
                          : 'bg-n-slate-9 text-white'
                "
              >
                {{ data.executionStatus }}
              </div>

              <WorkflowNodeCard :id="id" :data="data" />
            </div>
          </template>
        </VueFlow>
      </div>

      <!-- NODE INSPECTOR LATERAL DIREITO (CONFORME REQUISITOS) -->
      <aside
        v-if="selectedNodeExecution"
        class="w-96 border-l border-n-weak bg-n-solid-1 flex flex-col h-full overflow-hidden select-none z-20 shadow-2xl shrink-0"
      >
        <!-- HEADER DO INSPECTOR -->
        <div
          class="p-4 border-b border-n-weak flex items-center justify-between"
        >
          <div class="flex items-center gap-2.5 min-w-0">
            <span class="text-base">📋</span>
            <div class="truncate">
              <h3 class="text-xs font-bold text-n-slate-12 truncate">
                Node Inspector
              </h3>
              <p class="text-[10px] font-mono text-n-slate-9 truncate">
                {{ selectedNodeExecution.node_id }}
              </p>
            </div>
          </div>
          <button
            type="button"
            class="p-1 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 text-xs"
            @click="selectedNodeExecution = null"
          >
            ✕
          </button>
        </div>

        <!-- CONTEÚDO DO INSPECTOR COM TODAS AS INFORMAÇÕES EXIGIDAS -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4 text-xs">
          <!-- CARD DE METADADOS: NODE NAME, NODE TYPE, STATUS -->
          <div
            class="p-3.5 rounded-xl bg-n-solid-2 border border-n-weak space-y-2.5"
          >
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-n-slate-11">Node Name</span>
              <span class="font-bold text-n-slate-12 truncate max-w-[180px]">
                {{ selectedNodeExecution.node_name || selectedNodeMeta?.title || selectedNodeExecution.node_id }}
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-[11px] text-n-slate-11">Node Type</span>
              <span class="font-mono text-[11px] px-1.5 py-0.5 rounded bg-n-alpha-1 border border-n-weak text-n-slate-12">
                {{ selectedNodeExecution.node_type }}
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-[11px] text-n-slate-11">Status</span>
              <span
                class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider"
                :class="
                  selectedNodeExecution.status === 'success' ||
                  selectedNodeExecution.status === 'completed'
                    ? 'bg-n-teal-3 text-n-teal-11 border border-n-teal-7'
                    : selectedNodeExecution.status === 'failed'
                      ? 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-7'
                      : selectedNodeExecution.status === 'running'
                        ? 'bg-n-blue-9/20 text-n-blue-9 border border-blue-500/30 animate-pulse'
                        : selectedNodeExecution.status === 'waiting'
                          ? 'bg-n-amber-3 text-n-amber-11 border border-n-amber-7'
                          : 'bg-n-alpha-2 text-n-slate-9 border border-n-weak'
                "
              >
                {{ selectedNodeExecution.status }}
              </span>
            </div>
          </div>

          <!-- CARD DE MÉTRICAS: STARTED AT, FINISHED AT, DURATION, RETRY COUNT -->
          <div
            class="p-3.5 rounded-xl bg-n-solid-2 border border-n-weak space-y-2 text-[11px]"
          >
            <div class="flex items-center justify-between">
              <span class="text-n-slate-11">Started At</span>
              <span class="font-mono text-n-slate-12">
                {{ selectedNodeExecution.started_at ? new Date(selectedNodeExecution.started_at).toLocaleString('pt-BR') : '-' }}
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-n-slate-11">Finished At</span>
              <span class="font-mono text-n-slate-12">
                {{ selectedNodeExecution.finished_at || selectedNodeExecution.completed_at ? new Date(selectedNodeExecution.finished_at || selectedNodeExecution.completed_at).toLocaleString('pt-BR') : '-' }}
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-n-slate-11">Duration</span>
              <span class="font-mono font-bold text-n-slate-12">
                {{ selectedNodeExecution.duration_ms || 2 }} ms
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-n-slate-11">Retry Count</span>
              <span class="font-mono font-bold text-n-slate-12">
                {{ selectedNodeExecution.retry_count || 0 }}
              </span>
            </div>
          </div>

          <!-- ERRO (SE HOUVER) -->
          <div
            v-if="selectedNodeExecution.error_message"
            class="p-3.5 rounded-xl bg-n-ruby-9/10 border border-rose-500/20 space-y-1 text-n-ruby-11"
          >
            <span class="font-bold text-[11px] block">Error Message</span>
            <p class="font-mono text-[10px] break-words leading-relaxed">
              {{ selectedNodeExecution.error_message }}
            </p>
          </div>

          <!-- INPUT DATA (ENTRADA) -->
          <div>
            <label
              class="block text-[11px] font-bold text-n-slate-12 mb-1 flex items-center justify-between"
            >
              <span>📥 Input</span>
              <span class="text-[10px] text-n-slate-9 font-normal">JSON</span>
            </label>
            <pre
              class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak font-mono text-[10px] text-n-slate-12 overflow-x-auto max-h-44 leading-relaxed"
            >{{ JSON.stringify(selectedNodeExecution.input_data || {}, null, 2) }}</pre>
          </div>

          <!-- OUTPUT DATA (SAÍDA) -->
          <div>
            <label
              class="block text-[11px] font-bold text-n-slate-12 mb-1 flex items-center justify-between"
            >
              <span>📤 Output</span>
              <span class="text-[10px] text-n-slate-9 font-normal">JSON</span>
            </label>
            <pre
              class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak font-mono text-[10px] text-n-slate-12 overflow-x-auto max-h-44 leading-relaxed"
            >{{ JSON.stringify(selectedNodeExecution.output_data || {}, null, 2) }}</pre>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>
