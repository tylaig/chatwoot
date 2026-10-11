<script setup>
import { ref, computed, nextTick, onMounted, provide, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { useEventListener } from '@vueuse/core';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

import WorkflowsAPI from 'dashboard/api/workflows';
import whatsappTemplatesAPI from 'dashboard/api/whatsappTemplates';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WorkflowNodeCard from './components/WorkflowNodeCard.vue';
import WorkflowEdge from './components/WorkflowEdge.vue';
import WorkflowNodeConfigPanel from './components/WorkflowNodeConfigPanel.vue';
import WorkflowTestChat from './components/WorkflowTestChat.vue';
import WorkflowNodeSelectorModal from './components/WorkflowNodeSelectorModal.vue';
import WorkflowTemplatePickerModal from './components/WorkflowTemplatePickerModal.vue';
import {
  getNodeDefinition,
  getNodeOutputs,
  getOutputColor,
  getCategoryStyle,
  OUTPUT_COLORS,
} from './nodeRegistry';
import { buildVariableCatalog } from './variables';
import { validateWorkflow } from './workflowValidation';

const HISTORY_LIMIT = 100;
const AUTOSAVE_DELAY_MS = 700;
const COALESCE_WINDOW_MS = 1000;
const EDGE_HOVER_RELEASE_MS = 250;
const NODE_FOOTPRINT = { width: 320, height: 180 };
const STATUS_LABELS = {
  active: {
    label: 'Ativo',
    classes: 'bg-green-500/15 text-green-700 dark:text-green-300',
  },
  paused: {
    label: 'Pausado',
    classes: 'bg-n-amber-9/15 text-n-amber-11',
  },
  draft: { label: 'Rascunho', classes: 'bg-n-alpha-2 text-n-slate-11' },
};

const route = useRoute();
const router = useRouter();
const store = useStore();

const workflowId = computed(() => route.params.workflowId);
const workflow = ref(null);
const webhookTrigger = ref(null);
const availableTemplates = ref([]);
const hasUnpublishedChanges = ref(false);

const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const hoveredEdgeId = ref(null);
const dropTargetId = ref(null);

const saveState = ref('saved');
const isPublishing = ref(false);
const showAddModal = ref(false);
const showTemplatePicker = ref(false);
const showHeaderMenu = ref(false);
const showIssues = ref(false);
const testOpen = ref(false);
const testNodeId = ref(null);
const serverIssues = ref([]);
const editingName = ref(false);
const nameDraft = ref('');
const nameInput = ref(null);
const connectingContext = ref(null);
const selectorAnchor = ref(null);
const dragConnection = ref(null);
let connectionCompleted = false;
let ignorePaneClickUntil = 0;
const pendingDeleteNodeId = ref(null);

const deleteNodeDialog = ref(null);
const archiveDialog = ref(null);
const versionsDialog = ref(null);
const canvasRef = ref(null);

const undoStack = ref([]);
const redoStack = ref([]);

const contactAttributes = useMapGetter('attributes/getContactAttributes');
const conversationAttributes = useMapGetter(
  'attributes/getConversationAttributes'
);

const {
  viewport,
  onConnect,
  onConnectStart,
  onConnectEnd,
  onNodeClick,
  onPaneClick,
  onNodeDragStart,
  onNodeDragStop,
  onEdgeMouseEnter,
  onEdgeMouseLeave,
  onNodesInitialized,
  getViewport,
  zoomIn,
  zoomOut,
  fitView,
  screenToFlowCoordinate,
} = useVueFlow();

const zoomPercent = computed(
  () => `${Math.round((viewport.value?.zoom || 1) * 100)}%`
);

const selectedNode = computed(
  () => nodes.value.find(node => node.id === selectedNodeId.value) || null
);

const statusMeta = computed(
  () => STATUS_LABELS[workflow.value?.status] || STATUS_LABELS.draft
);

const variableCatalog = computed(() =>
  buildVariableCatalog({
    samplePayload:
      webhookTrigger.value?.payload_pinned &&
      Object.keys(webhookTrigger.value?.pinned_payload || {}).length
        ? webhookTrigger.value.pinned_payload
        : webhookTrigger.value?.sample_payload || {},
    nodes: nodes.value,
    contactAttributes: contactAttributes.value,
    conversationAttributes: conversationAttributes.value,
  })
);

const clientIssues = computed(() =>
  validateWorkflow({
    nodes: nodes.value,
    edges: edges.value,
    isValid: variableCatalog.value.isValid,
    templates: availableTemplates.value,
  })
);

const issues = computed(() => [...clientIssues.value, ...serverIssues.value]);

const issuesByNode = computed(() => {
  const map = new Map();
  issues.value.forEach(issue => {
    if (!issue.nodeId) return;
    map.set(issue.nodeId, [...(map.get(issue.nodeId) || []), issue.message]);
  });
  return map;
});

const minimapNodes = computed(() => {
  if (!nodes.value.length) return [];
  const xs = nodes.value.map(node => node.position.x);
  const ys = nodes.value.map(node => node.position.y);
  const minX = Math.min(...xs);
  const minY = Math.min(...ys);
  const spanX = Math.max(Math.max(...xs) - minX, 1);
  const spanY = Math.max(Math.max(...ys) - minY, 1);

  return nodes.value.map(node => ({
    id: node.id,
    left: `${((node.position.x - minX) / spanX) * 72 + 8}%`,
    top: `${((node.position.y - minY) / spanY) * 64 + 12}%`,
    color: getCategoryStyle(node.data?.type).hex,
    active: node.id === selectedNodeId.value,
  }));
});

// ---------- Serialização ----------
const edgeColor = (sourceId, handleId) => {
  const source = nodes.value.find(node => node.id === sourceId);
  if (!source) return OUTPUT_COLORS.default;
  const output = getNodeOutputs(source.data?.type, source.data?.config).find(
    item => item.id === handleId
  );
  return output ? getOutputColor(output) : OUTPUT_COLORS.default;
};

const toFlowNode = raw => ({
  id: raw.id,
  type: 'custom',
  position: { x: raw.position?.x || 0, y: raw.position?.y || 0 },
  data: {
    type: raw.data?.type || raw.type,
    config: raw.data?.config || raw.config || {},
  },
});

const toFlowEdge = raw => ({
  id: raw.id,
  source: raw.source,
  target: raw.target,
  sourceHandle: raw.sourceHandle || 'output',
  targetHandle: raw.targetHandle || null,
  type: 'workflow',
});

const paintEdges = () => {
  edges.value = edges.value.map(edge => ({
    ...edge,
    style: { stroke: edgeColor(edge.source, edge.sourceHandle) },
  }));
};

const serializeGraph = () =>
  JSON.stringify({
    nodes: nodes.value.map(node => ({
      id: node.id,
      type: node.data.type,
      position: { x: node.position.x, y: node.position.y },
      data: { type: node.data.type, config: node.data.config },
      config: node.data.config,
    })),
    edges: edges.value.map(edge => ({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      sourceHandle: edge.sourceHandle,
      targetHandle: edge.targetHandle,
      type: 'workflow',
    })),
  });

const applyGraph = ({ nodes: rawNodes, edges: rawEdges }) => {
  nodes.value = rawNodes.map(toFlowNode);
  edges.value = rawEdges.map(toFlowEdge);
  paintEdges();
  if (!nodes.value.some(node => node.id === selectedNodeId.value)) {
    selectedNodeId.value = null;
  }
};

// ---------- Autosave ----------
let saveTimeout = null;
let savePromise = Promise.resolve();

const persist = async () => {
  saveState.value = 'saving';
  const graph = JSON.parse(serializeGraph());
  try {
    const { data } = await WorkflowsAPI.updateWorkflow(workflowId.value, null, {
      ...graph,
      viewport: getViewport(),
    });
    hasUnpublishedChanges.value = data.has_unpublished_changes;
    saveState.value = 'saved';
  } catch (error) {
    saveState.value = 'error';
    useAlert(
      error.response?.data?.error?.join(' ') || 'Erro ao salvar o fluxo.'
    );
  }
};

const scheduleSave = () => {
  saveState.value = 'pending';
  serverIssues.value = [];
  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(() => {
    savePromise = persist();
  }, AUTOSAVE_DELAY_MS);
};

const flushSave = async () => {
  if (saveState.value === 'pending') {
    clearTimeout(saveTimeout);
    savePromise = persist();
  }
  await savePromise;
};

// ---------- Histórico (Ctrl+Z / Ctrl+Y) ----------
let lastCommitKey = null;
let lastCommitAt = 0;

const commit = (coalesceKey = null) => {
  const now = Date.now();
  if (
    coalesceKey &&
    coalesceKey === lastCommitKey &&
    now - lastCommitAt < COALESCE_WINDOW_MS
  ) {
    lastCommitAt = now;
    return;
  }
  lastCommitKey = coalesceKey;
  lastCommitAt = now;
  const snapshot = serializeGraph();
  if (undoStack.value[undoStack.value.length - 1] === snapshot) return;
  undoStack.value = [...undoStack.value, snapshot].slice(-HISTORY_LIMIT);
  redoStack.value = [];
};

const travel = (from, to) => {
  if (!from.value.length) return;
  to.value = [...to.value, serializeGraph()];
  const snapshot = from.value[from.value.length - 1];
  from.value = from.value.slice(0, -1);
  lastCommitKey = null;
  applyGraph(JSON.parse(snapshot));
  scheduleSave();
};

const undo = () => travel(undoStack, redoStack);
const redo = () => travel(redoStack, undoStack);

// ---------- Carregamento ----------
const fetchWorkflow = async () => {
  try {
    const { data } = await WorkflowsAPI.getWorkflow(workflowId.value);
    workflow.value = data;
    webhookTrigger.value = data.webhook_trigger;
    hasUnpublishedChanges.value = data.has_unpublished_changes;
    applyGraph({
      nodes: data.draft_version?.nodes || [],
      edges: data.draft_version?.edges || [],
    });
    undoStack.value = [];
    redoStack.value = [];
    if (route.query.select === 'trigger') {
      selectedNodeId.value =
        nodes.value.find(node => getNodeDefinition(node.data.type).isTrigger)
          ?.id || null;
    }
  } catch (error) {
    useAlert('Erro ao carregar o workflow.');
  }
};

const fetchTemplates = async () => {
  try {
    const res = await whatsappTemplatesAPI.getTemplates();
    availableTemplates.value = res.data.templates || [];
  } catch (error) {
    useAlert('Erro ao carregar templates.');
  }
};

onMounted(() => {
  fetchWorkflow();
  fetchTemplates();
  ['agents/get', 'teams/get', 'labels/get', 'attributes/get'].forEach(action =>
    store.dispatch(action)
  );
});

watch(workflowId, fetchWorkflow);

// ---------- Conexões ----------
const connect = ({ source, sourceHandle, target, targetHandle }) => {
  const handle = sourceHandle || 'output';
  if (source === target) return;
  edges.value = [
    ...edges.value.filter(
      edge =>
        !(edge.source === source && (edge.sourceHandle || 'output') === handle)
    ),
    {
      id: `edge_${source}_${handle}_${target}_${Date.now()}`,
      source,
      sourceHandle: handle,
      target,
      targetHandle: targetHandle || null,
      type: 'workflow',
      style: { stroke: edgeColor(source, handle) },
    },
  ];
};

onConnect(params => {
  connectionCompleted = true;
  commit();
  connect(params);
  scheduleSave();
});

const pointerFromEvent = event => {
  const touch = event.changedTouches?.[0] || event.touches?.[0];
  return {
    x: touch?.clientX ?? event.clientX,
    y: touch?.clientY ?? event.clientY,
  };
};

const nodeIdAtPointer = event => {
  const pointer = pointerFromEvent(event);
  if (pointer.x == null || pointer.y == null) return null;
  const stack = document.elementsFromPoint(pointer.x, pointer.y);
  const nodeElement = stack
    .map(item => item.closest?.('.vue-flow__node'))
    .find(Boolean);
  return nodeElement?.getAttribute('data-id') || null;
};

const acceptsConnection = nodeId => {
  const node = nodes.value.find(item => item.id === nodeId);
  return getNodeDefinition(node?.data?.type)?.hasInput !== false;
};

const onDragPointerMove = event => {
  const pending = dragConnection.value;
  if (!pending || pending.handleType !== 'source') {
    dropTargetId.value = null;
    return;
  }
  const targetId = nodeIdAtPointer(event);
  dropTargetId.value =
    targetId && targetId !== pending.nodeId && acceptsConnection(targetId)
      ? targetId
      : null;
};

onConnectStart(({ nodeId, handleId, handleType }) => {
  connectionCompleted = false;
  dragConnection.value = { nodeId, handleId, handleType };
  document.addEventListener('mousemove', onDragPointerMove);
  document.addEventListener('touchmove', onDragPointerMove);
});

onConnectEnd(event => {
  document.removeEventListener('mousemove', onDragPointerMove);
  document.removeEventListener('touchmove', onDragPointerMove);
  const pending = dragConnection.value;
  const targetId = dropTargetId.value || nodeIdAtPointer(event);
  dragConnection.value = null;
  dropTargetId.value = null;
  if (connectionCompleted || !pending || pending.handleType !== 'source')
    return;

  if (targetId && targetId !== pending.nodeId && acceptsConnection(targetId)) {
    commit();
    connect({
      source: pending.nodeId,
      sourceHandle: pending.handleId || 'output',
      target: targetId,
    });
    scheduleSave();
    return;
  }
  if (targetId) return;

  const pointer = pointerFromEvent(event);
  const rect = canvasRef.value?.getBoundingClientRect();
  if (!rect) return;

  const panelWidth = 416;
  const panelHeight = 576;
  selectorAnchor.value = {
    x: Math.min(
      Math.max(pointer.x - rect.left, 8),
      rect.width - panelWidth - 8
    ),
    y: Math.min(
      Math.max(pointer.y - rect.top, 8),
      rect.height - Math.min(panelHeight, rect.height - 16) - 8
    ),
  };

  const flowPoint = screenToFlowCoordinate(pointer);
  connectingContext.value = {
    nodeId: pending.nodeId,
    handleId: pending.handleId || 'output',
    position: { x: flowPoint.x + 12, y: flowPoint.y - 48 },
  };
  ignorePaneClickUntil = Date.now() + 300;
  showAddModal.value = true;
});

const removeEdge = edgeId => {
  commit();
  edges.value = edges.value.filter(edge => edge.id !== edgeId);
  hoveredEdgeId.value = null;
  scheduleSave();
};

let edgeHoverTimer = null;
const setHoveredEdge = edgeId => {
  clearTimeout(edgeHoverTimer);
  if (edgeId) {
    hoveredEdgeId.value = edgeId;
    return;
  }
  edgeHoverTimer = setTimeout(() => {
    hoveredEdgeId.value = null;
  }, EDGE_HOVER_RELEASE_MS);
};

onEdgeMouseEnter(({ edge }) => setHoveredEdge(edge.id));
onEdgeMouseLeave(() => setHoveredEdge(null));

provide('workflowVariables', variableCatalog);
provide('workflowTestNodeId', testNodeId);
provide('workflowBuilder', {
  readOnly: false,
  issuesByNode,
  hoveredEdgeId,
  setHoveredEdge,
  removeEdge,
});

// ---------- Nós ----------
onNodeClick(({ node }) => {
  selectedNodeId.value = node.id;
});

onPaneClick(() => {
  selectedNodeId.value = null;
  if (Date.now() < ignorePaneClickUntil) return;
  showAddModal.value = false;
});

let hasFittedView = false;
onNodesInitialized(() => {
  if (hasFittedView) return;
  hasFittedView = true;
  fitView({ padding: 0.25, maxZoom: 1 });
});

onNodeDragStart(() => commit());
onNodeDragStop(() => scheduleSave());

const updateNodeConfig = (nodeId, newConfig) => {
  const target = nodes.value.find(node => node.id === nodeId);
  if (!target) return;
  commit(`config:${nodeId}`);

  const previousOutputs = getNodeOutputs(target.data.type, target.data.config);
  const nextOutputs = getNodeOutputs(target.data.type, newConfig);
  target.data = { ...target.data, config: newConfig };

  if (previousOutputs.length === nextOutputs.length) {
    const renamed = new Map(
      previousOutputs.map((output, index) => [output.id, nextOutputs[index].id])
    );
    edges.value = edges.value.map(edge =>
      edge.source === nodeId && renamed.has(edge.sourceHandle)
        ? { ...edge, sourceHandle: renamed.get(edge.sourceHandle) }
        : edge
    );
  }
  paintEdges();
  scheduleSave();
};

const handleUpdateNodeConfig = newConfig =>
  updateNodeConfig(selectedNodeId.value, newConfig);

const deleteNode = nodeId => {
  commit();
  nodes.value = nodes.value.filter(node => node.id !== nodeId);
  edges.value = edges.value.filter(
    edge => edge.source !== nodeId && edge.target !== nodeId
  );
  if (selectedNodeId.value === nodeId) selectedNodeId.value = null;
  scheduleSave();
};

const requestDeleteNode = nodeId => {
  const node = nodes.value.find(item => item.id === nodeId);
  if (!node || getNodeDefinition(node.data.type).isTrigger) return;
  pendingDeleteNodeId.value = nodeId;
  deleteNodeDialog.value?.open();
};

const confirmDeleteNode = () => {
  deleteNode(pendingDeleteNodeId.value);
  pendingDeleteNodeId.value = null;
  deleteNodeDialog.value?.close();
};

const duplicateNode = nodeId => {
  const source = nodes.value.find(node => node.id === nodeId);
  if (!source) return;
  commit();
  const copyId = `node_${Date.now()}`;
  nodes.value = [
    ...nodes.value,
    {
      ...toFlowNode(JSON.parse(JSON.stringify(source))),
      id: copyId,
      position: { x: source.position.x + 40, y: source.position.y + 160 },
    },
  ];
  selectedNodeId.value = copyId;
  scheduleSave();
};

const openAddBlock = () => {
  connectingContext.value = null;
  selectorAnchor.value = null;
  showAddModal.value = !showAddModal.value;
};

const viewportCenter = () => {
  const rect = canvasRef.value?.getBoundingClientRect();
  if (!rect) return { x: 0, y: 0 };
  const point = screenToFlowCoordinate({
    x: rect.left + rect.width / 2,
    y: rect.top + rect.height / 2,
  });
  return { x: point.x - 144, y: point.y - 80 };
};

const findFreePosition = start => {
  const overlaps = position =>
    nodes.value.some(
      node =>
        Math.abs(node.position.x - position.x) < NODE_FOOTPRINT.width &&
        Math.abs(node.position.y - position.y) < NODE_FOOTPRINT.height
    );
  let position = start;
  while (overlaps(position)) {
    position = { x: position.x, y: position.y + NODE_FOOTPRINT.height };
  }
  return position;
};

const handleInsertNode = nodeMeta => {
  showAddModal.value = false;
  commit();

  if (nodeMeta.isTrigger) {
    const current = nodes.value.find(
      node => getNodeDefinition(node.data.type).isTrigger
    );
    if (current) {
      nodes.value = nodes.value.map(node =>
        node.id === current.id
          ? {
              ...node,
              data: {
                type: nodeMeta.type,
                config: JSON.parse(
                  JSON.stringify(nodeMeta.defaultConfig || {})
                ),
              },
            }
          : node
      );
      selectedNodeId.value = current.id;
      connectingContext.value = null;
      selectorAnchor.value = null;
      scheduleSave();
      return;
    }
  }

  const parent = connectingContext.value
    ? nodes.value.find(node => node.id === connectingContext.value.nodeId)
    : null;
  const handleId = connectingContext.value?.handleId || 'output';
  const position = connectingContext.value?.position || viewportCenter();

  const newNodeId = `node_${Date.now()}`;
  nodes.value = [
    ...nodes.value,
    {
      id: newNodeId,
      type: 'custom',
      position: findFreePosition(position),
      data: {
        type: nodeMeta.type,
        config: JSON.parse(JSON.stringify(nodeMeta.defaultConfig || {})),
      },
    },
  ];

  if (parent) {
    connect({ source: parent.id, sourceHandle: handleId, target: newNodeId });
  }

  selectedNodeId.value = newNodeId;
  connectingContext.value = null;
  selectorAnchor.value = null;
  scheduleSave();
};

// ---------- Templates ----------
const handleSelectTemplate = tpl => {
  showTemplatePicker.value = false;
  if (!selectedNode.value) return;
  handleUpdateNodeConfig({
    ...selectedNode.value.data.config,
    template_name: tpl.name,
    template_language: tpl.language || 'pt_BR',
    template_category: tpl.category || 'MARKETING',
    template_params: {},
  });
};

// ---------- Publicação ----------
const focusNode = nodeId => {
  if (!nodeId) return;
  selectedNodeId.value = nodeId;
  fitView({ nodes: [nodeId], padding: 1.2, maxZoom: 1, duration: 400 });
};

const handlePublish = async () => {
  if (clientIssues.value.length) {
    showIssues.value = true;
    useAlert(
      `Corrija ${clientIssues.value.length} problema(s) antes de publicar.`
    );
    return;
  }

  isPublishing.value = true;
  try {
    await flushSave();
    const { data } = await WorkflowsAPI.publishWorkflow(
      workflowId.value,
      'Publicado pelo editor visual'
    );
    workflow.value = {
      ...workflow.value,
      status: data.status,
      active_version: { version_number: data.version_number },
    };
    hasUnpublishedChanges.value = false;
    serverIssues.value = [];
    useAlert(`Versão v${data.version_number} publicada e ativa.`);
  } catch (error) {
    const responseIssues = error.response?.data?.issues || [];
    serverIssues.value = responseIssues.map(issue => ({
      nodeId: issue.node_id,
      message: issue.message,
    }));
    showIssues.value = serverIssues.value.length > 0;
    useAlert('Não foi possível publicar. Revise os problemas apontados.');
  } finally {
    isPublishing.value = false;
  }
};

// ---------- Menu do cabeçalho ----------
const startRename = () => {
  showHeaderMenu.value = false;
  nameDraft.value = workflow.value?.name || '';
  editingName.value = true;
  nextTick(() => nameInput.value?.select());
};

const saveName = async () => {
  if (!editingName.value) return;
  editingName.value = false;
  const name = nameDraft.value.trim();
  if (!name || name === workflow.value?.name) return;
  try {
    await WorkflowsAPI.renameWorkflow(workflowId.value, name);
    workflow.value = { ...workflow.value, name };
  } catch (error) {
    useAlert('Erro ao renomear o workflow.');
  }
};

const duplicateWorkflow = async () => {
  showHeaderMenu.value = false;
  await flushSave();
  const { data } = await WorkflowsAPI.duplicateWorkflow(workflowId.value);
  useAlert('Workflow duplicado.');
  router.push({ name: 'workflow_builder', params: { workflowId: data.id } });
};

const toggleActive = async () => {
  showHeaderMenu.value = false;
  try {
    const { data } =
      workflow.value.status === 'active'
        ? await WorkflowsAPI.pauseWorkflow(workflowId.value)
        : await WorkflowsAPI.activateWorkflow(workflowId.value);
    workflow.value = { ...workflow.value, status: data.status };
    useAlert(
      data.status === 'active' ? 'Workflow ativado.' : 'Workflow pausado.'
    );
  } catch (error) {
    useAlert(
      error.response?.data?.error?.join(' ') || 'Erro ao alterar status.'
    );
  }
};

const exportJson = () => {
  showHeaderMenu.value = false;
  const graph = JSON.parse(serializeGraph());
  const blob = new Blob(
    [JSON.stringify({ name: workflow.value?.name, ...graph }, null, 2)],
    { type: 'application/json' }
  );
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = `${(workflow.value?.name || 'workflow').replace(/\s+/g, '_')}.json`;
  link.click();
  URL.revokeObjectURL(link.href);
};

const openVersions = async () => {
  showHeaderMenu.value = false;
  const { data } = await WorkflowsAPI.getWorkflow(workflowId.value);
  workflow.value = {
    ...workflow.value,
    versions: data.versions,
    active_version_id: data.active_version_id,
  };
  versionsDialog.value?.open();
};

const openArchive = () => {
  showHeaderMenu.value = false;
  archiveDialog.value?.open();
};

const confirmArchive = async () => {
  await WorkflowsAPI.deleteWorkflow(workflowId.value);
  archiveDialog.value?.close();
  useAlert('Workflow arquivado.');
  router.push({ name: 'workflows_index' });
};

const goToExecutions = () =>
  router.push({
    name: 'workflow_executions',
    params: { workflowId: workflowId.value },
  });

// ---------- Atalhos de teclado ----------
const isTypingTarget = target =>
  ['INPUT', 'TEXTAREA', 'SELECT'].includes(target?.tagName) ||
  target?.isContentEditable;

useEventListener(window, 'keydown', event => {
  if (isTypingTarget(event.target)) return;
  const mod = event.ctrlKey || event.metaKey;
  const key = event.key.toLowerCase();

  if (mod && key === 'z' && !event.shiftKey) {
    event.preventDefault();
    undo();
  } else if (mod && (key === 'y' || (key === 'z' && event.shiftKey))) {
    event.preventDefault();
    redo();
  } else if (key === 'delete' || key === 'backspace') {
    const selectedEdges = edges.value.filter(edge => edge.selected);
    if (selectedEdges.length) {
      event.preventDefault();
      commit();
      const ids = new Set(selectedEdges.map(edge => edge.id));
      edges.value = edges.value.filter(edge => !ids.has(edge.id));
      scheduleSave();
    } else if (selectedNodeId.value) {
      event.preventDefault();
      requestDeleteNode(selectedNodeId.value);
    }
  } else if (key === 'escape') {
    showAddModal.value = false;
    showIssues.value = false;
  }
});

const openTest = async () => {
  await flushSave();
  selectedNodeId.value = null;
  testOpen.value = true;
};

const closeTest = () => {
  testOpen.value = false;
  testNodeId.value = null;
};

const saveLabel = computed(
  () =>
    ({
      pending: 'Alterações pendentes…',
      saving: 'Salvando…',
      saved: 'Rascunho salvo',
      error: 'Erro ao salvar',
    })[saveState.value]
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-col flex-1 w-full h-full min-w-0 bg-n-background text-n-slate-12 overflow-hidden"
  >
    <header
      class="h-16 px-4 border-b border-n-weak bg-n-solid-1 flex items-center justify-between gap-4 z-20 shrink-0"
    >
      <div class="flex items-center gap-3 min-w-0">
        <button
          type="button"
          class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
          title="Voltar para workflows"
          @click="router.push({ name: 'workflows_index' })"
        >
          <span class="i-lucide-arrow-left size-4" />
        </button>

        <div class="min-w-0">
          <div class="flex items-center gap-2 min-w-0">
            <input
              v-if="editingName"
              ref="nameInput"
              v-model="nameDraft"
              type="text"
              class="reset-base h-7 m-0 px-2 text-sm font-semibold rounded-md bg-n-alpha-black2 border-0 outline outline-1 outline-n-brand text-n-slate-12"
              @keydown.enter="saveName"
              @keydown.esc="editingName = false"
              @blur="saveName"
            />
            <button
              v-else
              type="button"
              class="group flex items-center gap-1.5 min-w-0 text-sm font-semibold text-n-slate-12 truncate"
              title="Renomear"
              @click="startRename"
            >
              <span class="truncate">{{ workflow?.name || 'Workflow' }}</span>
              <span
                class="i-lucide-pencil size-3 text-n-slate-10 opacity-0 group-hover:opacity-100"
              />
            </button>
            <span
              class="shrink-0 px-2 py-0.5 rounded-md text-[0.6875rem] font-semibold"
              :class="statusMeta.classes"
            >
              {{ statusMeta.label }}
              <template v-if="workflow?.active_version?.version_number">
                · v{{ workflow.active_version.version_number }}
              </template>
            </span>
          </div>
          <div class="flex items-center gap-3 mt-0.5 text-[0.6875rem]">
            <span
              class="flex items-center gap-1"
              :class="
                saveState === 'error' ? 'text-n-ruby-11' : 'text-n-slate-10'
              "
            >
              <span
                class="size-3"
                :class="{
                  'i-lucide-loader-circle animate-spin': saveState === 'saving',
                  'i-lucide-circle-check': saveState === 'saved',
                  'i-lucide-circle-alert': saveState === 'error',
                  'i-lucide-pencil': saveState === 'pending',
                }"
              />
              {{ saveLabel }}
            </span>
            <span
              v-if="hasUnpublishedChanges"
              class="flex items-center gap-1 text-n-amber-11 font-medium"
            >
              <span class="size-1.5 rounded-full bg-n-amber-9" />
              Alterações não publicadas
            </span>
            <span
              v-else
              class="flex items-center gap-1 text-green-600 dark:text-green-400"
            >
              <span class="size-1.5 rounded-full bg-green-500" />
              Tudo publicado
            </span>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2 shrink-0">
        <div class="flex items-center p-0.5 rounded-lg border border-n-weak">
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40 disabled:hover:bg-transparent"
            :disabled="!undoStack.length"
            title="Desfazer (Ctrl+Z)"
            @click="undo"
          >
            <span class="i-lucide-undo-2 size-4" />
          </button>
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40 disabled:hover:bg-transparent"
            :disabled="!redoStack.length"
            title="Refazer (Ctrl+Y)"
            @click="redo"
          >
            <span class="i-lucide-redo-2 size-4" />
          </button>
        </div>

        <button
          v-if="issues.length"
          type="button"
          class="h-9 px-3 rounded-lg text-xs font-medium flex items-center gap-1.5 bg-n-ruby-9/10 text-n-ruby-11 hover:bg-n-ruby-9/20"
          @click="showIssues = !showIssues"
        >
          <span class="i-lucide-circle-alert size-4" />
          {{ issues.length }}
          {{ issues.length === 1 ? 'problema' : 'problemas' }}
        </button>

        <button
          type="button"
          class="h-9 px-3 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 flex items-center gap-1.5"
          :class="testOpen ? 'bg-n-alpha-2' : ''"
          @click="testOpen ? closeTest() : openTest()"
        >
          <span class="i-lucide-message-circle size-4 text-n-slate-11" />
          Testar
        </button>

        <button
          type="button"
          class="h-9 px-3 rounded-lg border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 flex items-center gap-1.5"
          @click="goToExecutions"
        >
          <span class="i-lucide-chart-column size-4 text-n-slate-11" />
          Execuções
        </button>

        <button
          type="button"
          class="h-9 px-4 rounded-lg bg-n-brand text-white text-xs font-semibold shadow-sm hover:opacity-90 disabled:opacity-50 flex items-center gap-1.5"
          :disabled="
            isPublishing ||
            (!hasUnpublishedChanges && workflow?.status !== 'draft')
          "
          @click="handlePublish"
        >
          <span
            class="size-4"
            :class="
              isPublishing
                ? 'i-lucide-loader-circle animate-spin'
                : 'i-lucide-rocket'
            "
          />
          {{
            isPublishing
              ? 'Publicando…'
              : hasUnpublishedChanges || workflow?.status === 'draft'
                ? 'Publicar'
                : 'Publicado'
          }}
        </button>

        <OnClickOutside class="relative" @trigger="showHeaderMenu = false">
          <button
            type="button"
            class="flex items-center justify-center size-9 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            title="Mais opções"
            @click="showHeaderMenu = !showHeaderMenu"
          >
            <span class="i-lucide-ellipsis-vertical size-4" />
          </button>
          <div
            v-if="showHeaderMenu"
            class="absolute end-0 top-11 z-40 w-60 p-1 rounded-xl bg-n-solid-2 border border-n-weak shadow-xl"
          >
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
              @click="startRename"
            >
              <span class="i-lucide-pencil size-4 text-n-slate-11" /> Renomear
            </button>
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
              @click="duplicateWorkflow"
            >
              <span class="i-lucide-copy size-4 text-n-slate-11" /> Duplicar
              workflow
            </button>
            <button
              v-if="workflow?.active_version"
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
              @click="toggleActive"
            >
              <span
                class="size-4 text-n-slate-11"
                :class="
                  workflow?.status === 'active'
                    ? 'i-lucide-pause'
                    : 'i-lucide-play'
                "
              />
              {{
                workflow?.status === 'active'
                  ? 'Pausar workflow'
                  : 'Ativar workflow'
              }}
            </button>
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
              @click="openVersions"
            >
              <span class="i-lucide-history size-4 text-n-slate-11" /> Histórico
              de versões
            </button>
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm hover:bg-n-alpha-2"
              @click="exportJson"
            >
              <span class="i-lucide-file-json size-4 text-n-slate-11" />
              Exportar JSON
            </button>
            <div class="my-1 h-px bg-n-weak" />
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-ruby-11 hover:bg-n-ruby-9/10"
              @click="openArchive"
            >
              <span class="i-lucide-archive size-4" /> Arquivar workflow
            </button>
          </div>
        </OnClickOutside>
      </div>
    </header>

    <div class="flex flex-1 min-h-0 overflow-hidden relative">
      <div ref="canvasRef" class="flex-1 h-full relative bg-n-background">
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :default-viewport="{ zoom: 1 }"
          :min-zoom="0.2"
          :max-zoom="2"
          :delete-key-code="null"
          :default-edge-options="{ type: 'workflow' }"
          fit-view-on-init
          class="h-full w-full"
        >
          <Background pattern-color="#94A3B8" :gap="20" :size="1.2" />

          <template #node-custom="{ id, data }">
            <WorkflowNodeCard
              :id="id"
              :data="data"
              :selected="id === selectedNodeId"
              :connect-target="id === dropTargetId"
              @configure="selectedNodeId = $event"
              @duplicate="duplicateNode"
              @delete="deleteNode"
            />
          </template>

          <template #edge-workflow="edgeProps">
            <WorkflowEdge v-bind="edgeProps" />
          </template>
        </VueFlow>

        <button
          type="button"
          class="absolute end-6 top-6 z-20 h-11 ps-3 pe-4 rounded-xl bg-n-brand text-white text-sm font-semibold shadow-lg shadow-n-brand/30 hover:opacity-90 flex items-center gap-2 transition-all"
          @click="openAddBlock"
        >
          <span
            class="flex items-center justify-center size-6 rounded-lg bg-white/20"
          >
            <span
              class="size-4"
              :class="showAddModal ? 'i-lucide-x' : 'i-lucide-plus'"
            />
          </span>
          Adicionar bloco
        </button>

        <WorkflowNodeSelectorModal
          :show="showAddModal"
          :allow-triggers="!connectingContext"
          :anchor="selectorAnchor"
          @close="showAddModal = false"
          @select="handleInsertNode"
        />

        <div
          v-if="showIssues && issues.length"
          class="absolute start-6 top-6 z-30 w-80 max-h-[60%] flex flex-col rounded-2xl bg-n-solid-1 border border-n-weak shadow-2xl overflow-hidden"
        >
          <div
            class="px-4 py-3 border-b border-n-weak flex items-center justify-between"
          >
            <p
              class="flex items-center gap-1.5 text-sm font-semibold text-n-slate-12"
            >
              <span class="i-lucide-circle-alert size-4 text-n-ruby-9" />
              Revisar antes de publicar
            </p>
            <button
              type="button"
              class="flex items-center justify-center size-7 rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
              title="Fechar"
              @click="showIssues = false"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>
          <div class="flex-1 overflow-y-auto p-2 space-y-1">
            <button
              v-for="(issue, index) in issues"
              :key="index"
              type="button"
              class="w-full flex items-start gap-2 p-2 rounded-lg text-start hover:bg-n-alpha-2"
              @click="focusNode(issue.nodeId)"
            >
              <span
                class="i-lucide-triangle-alert size-3.5 mt-0.5 shrink-0 text-n-ruby-9"
              />
              <span class="text-xs text-n-slate-12">{{ issue.message }}</span>
            </button>
          </div>
        </div>

        <div
          class="absolute start-6 bottom-6 z-10 flex items-center gap-0.5 p-1 bg-n-solid-1 border border-n-weak rounded-xl shadow-lg"
        >
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            title="Diminuir zoom"
            @click="zoomOut"
          >
            <span class="i-lucide-zoom-out size-4" />
          </button>
          <span class="w-12 text-center text-xs font-mono text-n-slate-12">{{
            zoomPercent
          }}</span>
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            title="Aumentar zoom"
            @click="zoomIn"
          >
            <span class="i-lucide-zoom-in size-4" />
          </button>
          <div class="w-px h-5 bg-n-weak mx-0.5" />
          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            title="Enquadrar fluxo"
            @click="fitView({ padding: 0.25, maxZoom: 1, duration: 300 })"
          >
            <span class="i-lucide-maximize size-4" />
          </button>
        </div>

        <div
          class="absolute end-6 bottom-6 z-10 w-40 h-24 rounded-xl bg-n-solid-1 border border-n-weak shadow-lg pointer-events-none overflow-hidden p-2"
        >
          <div class="relative w-full h-full">
            <span
              v-for="item in minimapNodes"
              :key="item.id"
              class="absolute w-4 h-2.5 rounded-sm"
              :class="item.active ? 'ring-2 ring-n-brand' : ''"
              :style="{
                left: item.left,
                top: item.top,
                backgroundColor: item.color,
              }"
            />
          </div>
        </div>
      </div>

      <WorkflowTestChat
        v-if="testOpen"
        :workflow-id="workflowId"
        @close="closeTest"
        @highlight="testNodeId = $event"
      />

      <WorkflowNodeConfigPanel
        v-else
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
        :issues="selectedNode ? issuesByNode.get(selectedNode.id) || [] : []"
        :workflow-id="workflowId"
        :webhook-trigger="webhookTrigger"
        @update-config="handleUpdateNodeConfig"
        @delete-node="requestDeleteNode"
        @close="selectedNodeId = null"
        @open-template-picker="showTemplatePicker = true"
        @update-webhook-trigger="webhookTrigger = $event"
      />
    </div>

    <WorkflowTemplatePickerModal
      :show="showTemplatePicker"
      :templates="availableTemplates"
      :selected-template-name="selectedNode?.data?.config?.template_name"
      @close="showTemplatePicker = false"
      @select="handleSelectTemplate"
    />

    <Dialog
      ref="deleteNodeDialog"
      type="alert"
      title="Excluir bloco?"
      description="O bloco e as conexões dele serão removidos. Você pode desfazer com Ctrl+Z."
      confirm-button-label="Excluir"
      cancel-button-label="Cancelar"
      @confirm="confirmDeleteNode"
    />

    <Dialog
      ref="archiveDialog"
      type="alert"
      title="Arquivar workflow?"
      description="O workflow deixa de receber execuções e sai da lista."
      confirm-button-label="Arquivar"
      cancel-button-label="Cancelar"
      @confirm="confirmArchive"
    />

    <Dialog
      ref="versionsDialog"
      title="Histórico de versões"
      :show-confirm-button="false"
      cancel-button-label="Fechar"
    >
      <div class="max-h-80 overflow-y-auto divide-y divide-n-weak">
        <div
          v-for="version in [...(workflow?.versions || [])].reverse()"
          :key="version.id"
          class="flex items-center gap-3 py-2.5"
        >
          <span class="w-10 font-mono text-sm font-semibold text-n-slate-12"
            >v{{ version.version_number }}</span
          >
          <div class="flex-1 min-w-0">
            <p class="text-sm text-n-slate-12 truncate">
              {{
                version.change_summary ||
                (version.status === 'draft'
                  ? 'Rascunho em edição'
                  : 'Versão publicada')
              }}
            </p>
            <p class="text-xs text-n-slate-10">
              {{ new Date(version.created_at).toLocaleString('pt-BR') }}
            </p>
          </div>
          <span
            class="px-2 py-0.5 rounded-md text-[0.6875rem] font-semibold"
            :class="
              version.id === workflow?.active_version_id
                ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                : version.status === 'draft'
                  ? 'bg-n-amber-9/15 text-n-amber-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{
              version.id === workflow?.active_version_id
                ? 'Em produção'
                : version.status === 'draft'
                  ? 'Rascunho'
                  : 'Anterior'
            }}
          </span>
        </div>
      </div>
    </Dialog>
  </div>
</template>
