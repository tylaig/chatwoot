<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import WorkflowsAPI from 'dashboard/api/workflows';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';
import WorkflowNodeCard from './components/WorkflowNodeCard.vue';
import WorkflowNodeConfigPanel from './components/WorkflowNodeConfigPanel.vue';
import WorkflowNodeSelectorModal from './components/WorkflowNodeSelectorModal.vue';

const route = useRoute();
const router = useRouter();

const workflowId = computed(() => route.params.workflowId);
const workflow = ref(null);
const draftVersion = ref({ nodes: [], edges: [], viewport: { x: 0, y: 0, zoom: 1 } });
const selectedNode = ref(null);
const showAddModal = ref(false);
const connectingFromNode = ref(null);
const availableTemplates = ref([]);

const isSaving = ref(false);
const saveStatus = ref('Salvo');
const isPublishing = ref(false);

const fetchWorkflow = async () => {
  try {
    const res = await WorkflowsAPI.getWorkflow(workflowId.value);
    workflow.value = res.data;
    draftVersion.value = res.data.draft_version || { nodes: [], edges: [] };
    if (draftVersion.value.nodes.length > 0) {
      selectedNode.value = draftVersion.value.nodes[0];
    }
  } catch (err) {
    console.error('Erro ao carregar workflow:', err);
  }
};

const fetchTemplates = async () => {
  try {
    const res = await whatsappTemplatesAPI.getTemplates({ status: 'approved' });
    availableTemplates.value = res.data.templates || [];
  } catch (err) {
    console.error('Erro ao carregar templates:', err);
  }
};

onMounted(() => {
  fetchWorkflow();
  fetchTemplates();
});

// Seleção de nó
const handleSelectNode = (node) => {
  selectedNode.value = node;
};

// Abertura de modal para adicionar nó conectado
const handleAddNext = (parentNode) => {
  connectingFromNode.value = parentNode;
  showAddModal.value = true;
};

// Inserção do nó selecionado no grafo
const handleInsertNode = (nodeMeta) => {
  showAddModal.value = false;

  const parent = connectingFromNode.value;
  const newY = parent ? parent.position.y + 140 : 100;
  const newX = parent ? parent.position.x : 250;

  const newNode = {
    id: `node_${Date.now()}`,
    type: nodeMeta.type,
    position: { x: newX, y: newY },
    config: {
      custom_title: nodeMeta.title,
      delivery_mode: 'auto',
    },
  };

  draftVersion.value.nodes.push(newNode);

  if (parent) {
    draftVersion.value.edges.push({
      id: `edge_${parent.id}_${newNode.id}`,
      source: parent.id,
      target: newNode.id,
    });
  }

  selectedNode.value = newNode;
  triggerAutoSave();
};

// Atualização de configuração do nó
const handleUpdateNodeConfig = (newConfig) => {
  if (!selectedNode.value) return;
  selectedNode.value.config = newConfig;
  triggerAutoSave();
};

// Exclusão de nó
const handleDeleteNode = (nodeId) => {
  draftVersion.value.nodes = draftVersion.value.nodes.filter((n) => n.id !== nodeId);
  draftVersion.value.edges = draftVersion.value.edges.filter(
    (e) => e.source !== nodeId && e.target !== nodeId
  );
  selectedNode.value = null;
  triggerAutoSave();
};

// Autosave com debounce
let saveTimeout = null;
const triggerAutoSave = () => {
  saveStatus.value = 'Salvando...';
  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(async () => {
    try {
      isSaving.value = true;
      await WorkflowsAPI.updateWorkflow(workflowId.value, {}, draftVersion.value);
      saveStatus.value = 'Salvo';
    } catch (err) {
      saveStatus.value = 'Erro ao salvar';
    } finally {
      isSaving.value = false;
    }
  }, 800);
};

// Publicar Workflow
const handlePublish = async () => {
  try {
    isPublishing.value = true;
    await WorkflowsAPI.publishWorkflow(workflowId.value, 'Versão publicada');
    await fetchWorkflow();
  } catch (err) {
    console.error('Erro ao publicar:', err);
  } finally {
    isPublishing.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-full bg-slate-50 dark:bg-slate-950 overflow-hidden">
    <!-- BUILDER HEADER -->
    <header class="h-14 px-5 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between z-20">
      <div class="flex items-center gap-3">
        <button
          type="button"
          class="p-1.5 rounded-lg text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800"
          @click="router.push({ name: 'workflows_index' })"
        >
          ←
        </button>
        <div>
          <h1 class="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
            {{ workflow?.name || 'Carregando Workflow...' }}
            <span
              class="text-[10px] px-2 py-0.5 rounded-full uppercase font-bold"
              :class="workflow?.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'"
            >
              {{ workflow?.status || 'draft' }}
            </span>
          </h1>
          <p class="text-[11px] text-slate-400 font-mono">{{ saveStatus }}</p>
        </div>
      </div>

      <div class="flex items-center gap-2.5">
        <button
          type="button"
          class="px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-50"
          @click="router.push({ name: 'workflow_executions', params: { workflowId: workflowId } })"
        >
          Ver Execuções
        </button>

        <button
          type="button"
          class="px-4 py-1.5 rounded-xl bg-primary-500 hover:bg-primary-600 text-white text-xs font-bold shadow-md shadow-primary-500/20 transition-all flex items-center gap-1.5 disabled:opacity-50"
          :disabled="isPublishing"
          @click="handlePublish"
        >
          <span>🚀</span>
          <span>{{ isPublishing ? 'Publicando...' : 'Publicar Alterações' }}</span>
        </button>
      </div>
    </header>

    <!-- WORKSPACE CANVAS + SIDE PANEL -->
    <div class="flex flex-1 overflow-hidden relative">
      <!-- CANVAS CENTRAL -->
      <main class="flex-1 overflow-auto bg-dot-pattern p-10 relative flex flex-col items-center select-none">
        <!-- RENDER DOS NODES CONECTADOS -->
        <div class="flex flex-col items-center space-y-10 my-auto py-10">
          <template v-for="(node, index) in draftVersion.nodes" :key="node.id">
            <WorkflowNodeCard
              :node="node"
              :is-selected="selectedNode?.id === node.id"
              @select="handleSelectNode"
              @add-next="handleAddNext"
              @delete="handleDeleteNode"
            />

            <!-- Conector Visual Vertical -->
            <div
              v-if="index < draftVersion.nodes.length - 1"
              class="w-0.5 h-8 bg-slate-300 dark:bg-slate-700 -my-2"
            />
          </template>

          <!-- Botão para Adicionar Primeiro ou Próximo Bloco -->
          <button
            type="button"
            class="px-4 py-2 rounded-2xl border-2 border-dashed border-slate-300 dark:border-slate-700 text-xs font-semibold text-slate-500 hover:border-primary-500 hover:text-primary-600 transition-colors flex items-center gap-1.5"
            @click="handleAddNext(draftVersion.nodes[draftVersion.nodes.length - 1])"
          >
            <span>+</span>
            <span>Adicionar Próxima Ação</span>
          </button>
        </div>
      </main>

      <!-- PAINEL LATERAL DIREITO (CONFIGURAÇÃO) -->
      <WorkflowNodeConfigPanel
        :node="selectedNode"
        :available-templates="availableTemplates"
        @update-config="handleUpdateNodeConfig"
        @delete-node="handleDeleteNode"
        @close="selectedNode = null"
      />
    </div>

    <!-- MODAL SELETOR DE BLOCOS -->
    <WorkflowNodeSelectorModal
      :show="showAddModal"
      @close="showAddModal = false"
      @select="handleInsertNode"
    />
  </div>
</template>

<style scoped>
.bg-dot-pattern {
  background-image: radial-gradient(rgba(148, 163, 184, 0.25) 1px, transparent 1px);
  background-size: 20px 20px;
}
</style>
