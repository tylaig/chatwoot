<script setup>
import { ref, onMounted, computed, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { useAlert } from 'dashboard/composables';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

import WorkflowsAPI from 'dashboard/api/workflows';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';
import WorkflowNodeCard from './components/WorkflowNodeCard.vue';
import WorkflowNodeConfigPanel from './components/WorkflowNodeConfigPanel.vue';
import WorkflowNodeSelectorModal from './components/WorkflowNodeSelectorModal.vue';
import WorkflowTemplatePickerModal from './components/WorkflowTemplatePickerModal.vue';

const route = useRoute();
const router = useRouter();

const workflowId = computed(() => route.params.workflowId);
const workflow = ref(null);
const availableTemplates = ref([]);

const isSaving = ref(false);
const saveStatus = ref('Salvo');
const isPublishing = ref(false);
const showAddModal = ref(false);
const showTemplatePicker = ref(false);
const connectingContext = ref(null); // { nodeId, handleId }

// Vue Flow Nodes e Edges reativos
const elements = ref([]);
const selectedNodeId = ref(null);

const {
  viewport,
  onConnect,
  onNodeClick,
  onPaneClick,
  addNodes,
  addEdges,
  getViewport,
  zoomIn,
  zoomOut,
  fitView,
} = useVueFlow();

const zoomPercent = computed(() => {
  const z = viewport.value?.zoom || 1;
  return `${Math.round(z * 100)}%`;
});

const selectedNode = computed(() => {
  if (!selectedNodeId.value) return null;
  return elements.value.find(el => el.id === selectedNodeId.value) || null;
});

// Helper de cor semântica para arestas
const getEdgeColor = handleId => {
  if (handleId === 'true' || handleId === 'REPLIED' || handleId === 'SUCCESS') {
    return '#10B981';
  }
  if (handleId === 'false' || handleId === 'TIMEOUT' || handleId === 'ERROR') {
    return '#F43F5E';
  }
  if (handleId === 'Instagram') {
    return '#3B82F6';
  }
  if (handleId === 'Google') {
    return '#10B981';
  }
  if (handleId === 'Referral') {
    return '#F59E0B';
  }
  return '#64748B';
};

// Buscar Workflow
const fetchWorkflow = async () => {
  try {
    const res = await WorkflowsAPI.getWorkflow(workflowId.value);
    workflow.value = res.data;
    const draft = res.data.draft_version || { nodes: [], edges: [] };

    // Se não houver nós (fluxo novo), cria o nó inicial de Webhook Trigger exatamente como na referência
    let rawNodes = draft.nodes || [];
    const rawEdges = draft.edges || [];

    if (rawNodes.length === 0) {
      rawNodes = [
        {
          id: 'node_trigger_1',
          type: 'custom',
          position: { x: 80, y: 320 },
          data: {
            type: 'webhook_trigger',
            config: {
              custom_title: 'Webhook Trigger',
              endpoint: '/public/api/v1/webhook_dispatches/default',
            },
          },
        },
      ];
    } else {
      // Normaliza para o renderer 'custom' do VueFlow
      rawNodes = rawNodes.map(n => ({
        ...n,
        type: 'custom',
        data: {
          type: n.data?.type || n.type,
          config: n.data?.config || n.config || {},
        },
      }));
    }

    elements.value = [...rawNodes, ...rawEdges];

    if (rawNodes.length > 0) {
      selectedNodeId.value = rawNodes[0].id;
    }

    nextTick(() => {
      fitView({ padding: 0.2 });
    });
  } catch (err) {
    useAlert('Erro ao carregar workflow.');
  }
};

const fetchTemplates = async () => {
  try {
    const res = await whatsappTemplatesAPI.getTemplates();
    availableTemplates.value = res.data.templates || [];
  } catch (err) {
    useAlert('Erro ao carregar templates.');
  }
};

onMounted(() => {
  fetchWorkflow();
  fetchTemplates();
});

// Autosave com debounce
let saveTimeout = null;
const triggerAutoSave = () => {
  saveStatus.value = 'Salvando...';
  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(async () => {
    try {
      isSaving.value = true;
      const nodes = elements.value
        .filter(el => !el.source)
        .map(n => ({
          id: n.id,
          type: n.data?.type || n.type,
          position: n.position,
          data: n.data,
          config: n.data?.config || {},
        }));
      const edges = elements.value.filter(el => el.source);

      await WorkflowsAPI.updateWorkflow(
        workflowId.value,
        { name: workflow.value?.name || 'Workflow' },
        {
          nodes,
          edges,
          viewport: getViewport(),
        }
      );
      saveStatus.value = 'Salvo há poucos instantes';
    } catch (err) {
      saveStatus.value = 'Erro ao salvar';
    } finally {
      isSaving.value = false;
    }
  }, 700);
};

// Conectar Edges
onConnect(params => {
  const edgeColor = getEdgeColor(params.sourceHandle);

  const newEdge = {
    ...params,
    id: `edge_${params.source}_${params.target}_${Date.now()}`,
    type: 'smoothstep',
    animated: true,
    style: { stroke: edgeColor, strokeWidth: 2 },
  };
  addEdges([newEdge]);
  triggerAutoSave();
});

// Seleção de Nó
onNodeClick(e => {
  selectedNodeId.value = e.node.id;
});

onPaneClick(() => {
  selectedNodeId.value = null;
});

// Atualizar Configuração vinda do Painel Lateral
const handleUpdateNodeConfig = newConfig => {
  const target = elements.value.find(el => el.id === selectedNodeId.value);
  if (target) {
    target.data = {
      ...target.data,
      config: newConfig,
    };
    triggerAutoSave();
  }
};

// Excluir Nó
const handleDeleteNode = nodeId => {
  elements.value = elements.value.filter(
    el => el.id !== nodeId && el.source !== nodeId && el.target !== nodeId
  );
  if (selectedNodeId.value === nodeId) {
    selectedNodeId.value = null;
  }
  triggerAutoSave();
};

// Adicionar nó via botão (+) flutuante do card
const handleAddNext = ctx => {
  connectingContext.value = ctx;
  showAddModal.value = true;
};

// Inserir nó selecionado da paleta
const handleInsertNode = nodeMeta => {
  showAddModal.value = false;
  const parentId = connectingContext.value?.nodeId;
  const parentNode = parentId
    ? elements.value.find(n => n.id === parentId)
    : null;

  const newX = parentNode ? parentNode.position.x + 360 : 350;
  const newY = parentNode ? parentNode.position.y : 300;

  const newNodeId = `node_${Date.now()}`;
  const newNode = {
    id: newNodeId,
    type: 'custom',
    position: { x: newX, y: newY },
    data: {
      type: nodeMeta.type,
      config: JSON.parse(JSON.stringify(nodeMeta.defaultConfig || {})),
    },
  };

  addNodes([newNode]);

  // Se veio de conexão (+) cria a aresta automaticamente com o estilo do reference pack
  if (parentNode) {
    const handleId = connectingContext.value?.handleId || 'output';
    const edgeColor = getEdgeColor(handleId);

    addEdges([
      {
        id: `edge_${parentId}_${newNodeId}`,
        source: parentId,
        sourceHandle: handleId,
        target: newNodeId,
        type: 'smoothstep',
        animated: true,
        style: { stroke: edgeColor, strokeWidth: 2 },
      },
    ]);
  }

  selectedNodeId.value = newNodeId;
  connectingContext.value = null;
  triggerAutoSave();
};

// Modal de Templates WhatsApp
const handleOpenTemplatePicker = () => {
  showTemplatePicker.value = true;
};

const handleSelectTemplate = tpl => {
  showTemplatePicker.value = false;
  if (!selectedNode.value) return;

  const updatedConfig = {
    ...selectedNode.value.data.config,
    template_name: tpl.name,
    template_language: tpl.language || 'pt_BR',
    template_category: tpl.category || 'MARKETING',
    status: tpl.status || 'APPROVED',
  };
  handleUpdateNodeConfig(updatedConfig);
};

// Publicar Workflow
const handlePublish = async () => {
  try {
    isPublishing.value = true;
    await WorkflowsAPI.publishWorkflow(
      workflowId.value,
      'Versão publicada via Visual Builder'
    );
    await fetchWorkflow();
  } catch (err) {
    useAlert('Erro ao publicar workflow.');
  } finally {
    isPublishing.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-col flex-1 w-full h-full bg-n-background text-n-slate-12 overflow-hidden select-none"
  >
    <!-- TOP HEADER (ESTILO SEMÂNTICO CHATWOOT DESIGN TOKENS) -->
    <header
      class="h-14 px-6 border-b border-n-weak bg-n-solid-1 flex items-center justify-between z-20 shrink-0"
    >
      <div class="flex items-center gap-4">
        <button
          type="button"
          class="p-1.5 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="router.push({ name: 'workflows_index' })"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            />
          </svg>
        </button>

        <div>
          <div class="flex items-center gap-2.5">
            <h1 class="text-sm font-bold text-n-slate-12 tracking-tight">
              {{ workflow?.name || 'Webhook Inbound Flow' }}
            </h1>
            <span
              class="text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider"
              :class="
                workflow?.status === 'active'
                  ? 'bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30'
                  : 'bg-amber-500/20 text-amber-600 dark:text-amber-400 border border-amber-500/30'
              "
            >
              {{ workflow?.status || 'ACTIVE' }}
            </span>
          </div>
          <p class="text-[11px] text-n-slate-11 font-sans mt-0.5">
            {{ saveStatus }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button
          type="button"
          class="px-3.5 py-1.5 rounded-xl border border-n-weak bg-n-solid-2 hover:bg-n-alpha-2 text-xs font-semibold text-n-slate-12 transition-colors flex items-center gap-1.5"
          @click="
            router.push({
              name: 'workflow_executions',
              params: { workflowId: workflowId },
            })
          "
        >
          <span>📊</span>
          <span>Ver Execuções</span>
        </button>

        <button
          type="button"
          class="px-3.5 py-1.5 rounded-xl border border-n-weak bg-n-solid-2 hover:bg-n-alpha-2 text-xs font-semibold text-n-slate-12 transition-colors flex items-center gap-1.5"
        >
          <span>▷</span>
          <span>Testar</span>
        </button>

        <button
          type="button"
          class="px-4 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center gap-1.5 disabled:opacity-50"
          :disabled="isPublishing"
          @click="handlePublish"
        >
          <span>🚀</span>
          <span>{{
            isPublishing ? 'Publicando...' : 'Publicar Alterações'
          }}</span>
        </button>

        <button
          type="button"
          class="text-n-slate-9 hover:text-n-slate-12 p-1 rounded-lg"
        >
          •••
        </button>
      </div>
    </header>

    <!-- ÁREA CENTRAL COM CANVAS INFINITO E PAINEL LATERAL -->
    <div class="flex flex-1 overflow-hidden relative">
      <!-- VUE FLOW CANVAS -->
      <div class="flex-1 h-full relative bg-n-background">
        <VueFlow
          v-model="elements"
          :default-viewport="{ zoom: 1 }"
          :min-zoom="0.2"
          :max-zoom="2"
          fit-view-on-init
          class="h-full w-full"
        >
          <Background pattern-color="#94A3B8" :gap="20" :size="1.5" />

          <!-- CONTROLES CUSTOMIZADOS FLUTUANTES NO CANTO INFERIOR ESQUERDO -->
          <div
            class="absolute left-6 bottom-6 z-10 flex items-center gap-1 p-1 bg-n-solid-1/90 border border-n-weak rounded-xl shadow-xl backdrop-blur-md"
          >
            <button
              type="button"
              class="w-7 h-7 flex items-center justify-center text-xs text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded-lg transition-colors"
              title="Alternar Painel"
              @click="showAddModal = !showAddModal"
            >
              📖
            </button>
            <div class="w-px h-4 bg-n-weak my-auto" />
            <button
              type="button"
              class="w-7 h-7 flex items-center justify-center text-xs text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded-lg transition-colors"
              title="Diminuir Zoom"
              @click="zoomOut"
            >
              -
            </button>
            <span class="text-[11px] font-mono px-2 text-n-slate-12">{{
              zoomPercent
            }}</span>
            <button
              type="button"
              class="w-7 h-7 flex items-center justify-center text-xs text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded-lg transition-colors"
              title="Aumentar Zoom"
              @click="zoomIn"
            >
              +
            </button>
            <div class="w-px h-4 bg-n-weak my-auto" />
            <button
              type="button"
              class="w-7 h-7 flex items-center justify-center text-xs text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded-lg transition-colors"
              title="Enquadrar Visão"
              @click="fitView({ padding: 0.2 })"
            >
              ⛶
            </button>
          </div>

          <!-- MINIMAPA TRANSLÚCIDO NO CANTO INFERIOR DIREITO -->
          <div
            class="absolute right-6 bottom-6 z-10 w-36 h-24 rounded-xl bg-n-solid-1/80 border border-n-weak shadow-xl pointer-events-none overflow-hidden p-2 flex items-center justify-center backdrop-blur-sm"
          >
            <div
              class="relative w-full h-full flex items-center justify-center"
            >
              <div
                class="w-5 h-3 bg-blue-500/40 border border-blue-400 rounded-sm"
              />
              <div class="w-4 h-0.5 bg-n-slate-9 mx-0.5" />
              <div class="flex flex-col gap-1.5">
                <div
                  class="w-5 h-2.5 bg-emerald-500/40 border border-emerald-400 rounded-sm"
                />
                <div
                  class="w-5 h-2.5 bg-rose-500/40 border border-rose-400 rounded-sm"
                />
              </div>
            </div>
          </div>

          <!-- RENDERER CUSTOMIZADO PARA TODOS OS NODES -->
          <template #node-custom="{ id, data, selected }">
            <WorkflowNodeCard
              :id="id"
              :data="data"
              :selected="selected"
              @add-next="handleAddNext"
            />
          </template>
        </VueFlow>

        <!-- PALETA LATERAL ADICIONAR AÇÃO FLUTUANTE (ESTILO REFERENCE PACK) -->
        <WorkflowNodeSelectorModal
          :show="showAddModal"
          @close="showAddModal = false"
          @select="handleInsertNode"
        />
      </div>

      <!-- PAINEL LATERAL DIREITO DE CONFIGURAÇÃO (100% FIEL AO DESIGN SYSTEM) -->
      <WorkflowNodeConfigPanel
        :node="
          selectedNode
            ? {
                id: selectedNode.id,
                type: selectedNode.data?.type,
                config: selectedNode.data?.config,
              }
            : null
        "
        :available-templates="availableTemplates"
        @update-config="handleUpdateNodeConfig"
        @delete-node="handleDeleteNode"
        @close="selectedNodeId = null"
        @open-template-picker="handleOpenTemplatePicker"
      />
    </div>

    <!-- MODAL SELETOR DE TEMPLATES WHATSAPP COM PREVIEW E FILTROS -->
    <WorkflowTemplatePickerModal
      :show="showTemplatePicker"
      :templates="availableTemplates"
      :selected-template-name="selectedNode?.data?.config?.template_name"
      @close="showTemplatePicker = false"
      @select="handleSelectTemplate"
    />
  </div>
</template>

<style>
/* Customizações para Vue Flow Dark Mode fiel ao Chatwoot */
.vue-flow__edge-path {
  stroke-dasharray: 5;
  animation: dashdraw 0.5s linear infinite;
}
@keyframes dashdraw {
  from {
    stroke-dashoffset: 10;
  }
  to {
    stroke-dashoffset: 0;
  }
}
</style>
