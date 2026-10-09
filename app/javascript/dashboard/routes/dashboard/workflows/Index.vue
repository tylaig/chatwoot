<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import WorkflowsAPI from 'dashboard/api/workflows';

const router = useRouter();

const workflows = ref([]);
const stats = ref({ total: 0, active: 0, drafts: 0, paused: 0 });
const currentTab = ref('all');
const searchQuery = ref('');
const isLoading = ref(true);

const showCreateModal = ref(false);
const newWorkflowName = ref('');
const newWorkflowDesc = ref('');

const fetchWorkflows = async () => {
  try {
    isLoading.value = true;
    const res = await WorkflowsAPI.getWorkflows({ status: currentTab.value });
    workflows.value = res.data.workflows || [];
    stats.value = res.data.stats || { total: 0, active: 0, drafts: 0, paused: 0 };
  } catch (err) {
    console.error('Erro ao buscar workflows:', err);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchWorkflows();
});

const handleTabChange = (tab) => {
  currentTab.value = tab;
  fetchWorkflows();
};

const handleCreateWorkflow = async () => {
  if (!newWorkflowName.value.trim()) return;

  try {
    const res = await WorkflowsAPI.createWorkflow({
      name: newWorkflowName.value,
      description: newWorkflowDesc.value,
      trigger_type: 'webhook',
      status: 'draft',
    });
    showCreateModal.value = false;
    newWorkflowName.value = '';
    newWorkflowDesc.value = '';
    router.push({ name: 'workflow_builder', params: { workflowId: res.data.id } });
  } catch (err) {
    console.error('Erro ao criar workflow:', err);
  }
};

const handleDuplicate = async (wf) => {
  try {
    await WorkflowsAPI.duplicateWorkflow(wf.id);
    await fetchWorkflows();
  } catch (err) {
    console.error('Erro ao duplicar:', err);
  }
};

const handleToggleActive = async (wf) => {
  try {
    if (wf.status === 'active') {
      await WorkflowsAPI.pauseWorkflow(wf.id);
    } else {
      await WorkflowsAPI.activateWorkflow(wf.id);
    }
    await fetchWorkflows();
  } catch (err) {
    console.error('Erro ao alterar status:', err);
  }
};

const handleDelete = async (wf) => {
  if (!confirm(`Deseja arquivar o workflow "${wf.name}"?`)) return;
  try {
    await WorkflowsAPI.deleteWorkflow(wf.id);
    await fetchWorkflows();
  } catch (err) {
    console.error('Erro ao arquivar:', err);
  }
};

const filteredWorkflows = computed(() => {
  if (!searchQuery.value) return workflows.value;
  return workflows.value.filter((w) =>
    w.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
    w.description?.toLowerCase().includes(searchQuery.value.toLowerCase())
  );
});
</script>

<template>
  <div class="flex flex-col h-full bg-slate-50 dark:bg-slate-950 overflow-y-auto">
    <!-- WORKFLOWS HEADER -->
    <header class="p-6 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <h1 class="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
          <span>⚡</span>
          <span>Automações & Workflows</span>
        </h1>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
          Crie fluxos conversacionais inteligentes com verificação da janela de 24h e integração de WhatsApp.
        </p>
      </div>

      <div class="flex items-center gap-3">
        <button
          type="button"
          class="px-4 py-2 rounded-xl bg-primary-500 hover:bg-primary-600 text-white text-xs font-bold shadow-md shadow-primary-500/20 transition-all flex items-center gap-2"
          @click="showCreateModal = true"
        >
          <span>+</span>
          <span>Criar Workflow</span>
        </button>
      </div>
    </header>

    <!-- METRICS CARDS -->
    <div class="p-6 grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 shadow-sm">
        <p class="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Total de Fluxos</p>
        <p class="text-2xl font-bold text-slate-900 dark:text-white mt-1">{{ stats.total }}</p>
      </div>
      <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 shadow-sm">
        <p class="text-[11px] font-semibold text-emerald-600 uppercase tracking-wider">Ativos em Produção</p>
        <p class="text-2xl font-bold text-emerald-600 mt-1">{{ stats.active }}</p>
      </div>
      <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 shadow-sm">
        <p class="text-[11px] font-semibold text-amber-600 uppercase tracking-wider">Rascunhos (Drafts)</p>
        <p class="text-2xl font-bold text-amber-600 mt-1">{{ stats.drafts }}</p>
      </div>
      <div class="p-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 shadow-sm">
        <p class="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Pausados</p>
        <p class="text-2xl font-bold text-slate-700 dark:text-slate-300 mt-1">{{ stats.paused }}</p>
      </div>
    </div>

    <!-- TABS & SEARCH -->
    <div class="px-6 flex flex-col md:flex-row items-center justify-between gap-4">
      <div class="flex items-center gap-1 bg-slate-200/60 dark:bg-slate-800/60 p-1 rounded-xl">
        <button
          v-for="tab in [
            { id: 'all', label: 'Todos' },
            { id: 'active', label: 'Ativos' },
            { id: 'draft', label: 'Rascunhos' },
            { id: 'paused', label: 'Pausados' }
          ]"
          :key="tab.id"
          type="button"
          class="px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors"
          :class="currentTab === tab.id ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm' : 'text-slate-500 hover:text-slate-900'"
          @click="handleTabChange(tab.id)"
        >
          {{ tab.label }}
        </button>
      </div>

      <div class="w-full md:w-72">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Buscar automação por nome..."
          class="w-full px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900"
        />
      </div>
    </div>

    <!-- WORKFLOWS TABLE / GRID -->
    <div class="p-6">
      <div class="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-sm">
        <table class="w-full text-left text-xs">
          <thead class="bg-slate-50 dark:bg-slate-800/50 text-slate-400 font-semibold border-b border-slate-100 dark:border-slate-800">
            <tr>
              <th class="p-4">Nome & Gatilho</th>
              <th class="p-4">Status</th>
              <th class="p-4">Versão</th>
              <th class="p-4">Última Atualização</th>
              <th class="p-4 text-right">Ações</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
            <tr v-for="wf in filteredWorkflows" :key="wf.id" class="hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition-colors">
              <td class="p-4">
                <div class="flex items-center gap-3">
                  <div class="w-9 h-9 rounded-xl bg-primary-50 dark:bg-primary-950/40 text-primary-600 flex items-center justify-center font-bold text-sm">
                    ⚡
                  </div>
                  <div>
                    <h4
                      class="font-bold text-slate-900 dark:text-white hover:text-primary-600 cursor-pointer"
                      @click="router.push({ name: 'workflow_builder', params: { workflowId: wf.id } })"
                    >
                      {{ wf.name }}
                    </h4>
                    <p class="text-[11px] text-slate-400 truncate max-w-sm">{{ wf.description || 'Gatilho: Webhook Trigger' }}</p>
                  </div>
                </div>
              </td>

              <td class="p-4">
                <span
                  class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase"
                  :class="wf.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'"
                >
                  {{ wf.status }}
                </span>
              </td>

              <td class="p-4 font-mono text-[11px] text-slate-500">
                v{{ wf.active_version?.version_number || 1 }}
              </td>

              <td class="p-4 text-slate-500 text-[11px]">
                {{ new Date(wf.updated_at).toLocaleDateString('pt-BR') }}
              </td>

              <td class="p-4 text-right space-x-2">
                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-100"
                  @click="router.push({ name: 'workflow_builder', params: { workflowId: wf.id } })"
                >
                  Editar
                </button>

                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-100"
                  @click="handleToggleActive(wf)"
                >
                  {{ wf.status === 'active' ? 'Pausar' : 'Ativar' }}
                </button>

                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-100"
                  @click="handleDuplicate(wf)"
                >
                  Duplicar
                </button>

                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg text-rose-600 font-semibold hover:bg-rose-50"
                  @click="handleDelete(wf)"
                >
                  Excluir
                </button>
              </td>
            </tr>

            <tr v-if="filteredWorkflows.length === 0 && !isLoading">
              <td colspan="5" class="p-8 text-center text-slate-400">
                Nenhum workflow encontrado nesta lista.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- MODAL CRIAR WORKFLOW -->
    <div v-if="showCreateModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm" @click.self="showCreateModal = false">
      <div class="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 p-6 space-y-4">
        <h3 class="text-base font-bold text-slate-900 dark:text-white">Criar Nova Automação</h3>

        <div class="space-y-3">
          <div>
            <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Nome do Fluxo *</label>
            <input
              v-model="newWorkflowName"
              type="text"
              placeholder="ex: Lead Follow-up WhatsApp"
              class="w-full px-3 py-2 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
              autofocus
            />
          </div>

          <div>
            <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">Descrição</label>
            <textarea
              v-model="newWorkflowDesc"
              rows="3"
              placeholder="Descreva o objetivo deste fluxo conversacional..."
              class="w-full p-2.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800"
            />
          </div>
        </div>

        <div class="flex items-center justify-end gap-2 pt-2">
          <button
            type="button"
            class="px-3 py-1.5 text-xs text-slate-500 font-semibold"
            @click="showCreateModal = false"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="px-4 py-1.5 rounded-xl bg-primary-500 hover:bg-primary-600 text-white text-xs font-bold shadow-md shadow-primary-500/20"
            @click="handleCreateWorkflow"
          >
            Criar e Abrir Canvas
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
