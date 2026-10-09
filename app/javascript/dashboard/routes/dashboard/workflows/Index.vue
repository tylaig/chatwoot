<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import WorkflowsAPI from 'dashboard/api/workflows';

const router = useRouter();

const workflows = ref([]);
const stats = ref({ total: 0, active: 0, drafts: 0, paused: 0 });
const currentTab = ref('all');
const searchQuery = ref('');
const filterStatus = ref('ALL');
const filterTrigger = ref('ALL');
const selectedSort = ref('recent');
const isLoading = ref(true);

const selectedWorkflow = ref(null);
const showCreateModal = ref(false);
const newWorkflowName = ref('');
const newWorkflowDesc = ref('');

const fetchWorkflows = async () => {
  try {
    isLoading.value = true;
    const res = await WorkflowsAPI.getWorkflows({ status: currentTab.value });
    workflows.value = res.data.workflows || [];
    stats.value = res.data.stats || {
      total: 0,
      active: 0,
      drafts: 0,
      paused: 0,
    };
    if (workflows.value.length && !selectedWorkflow.value) {
      selectedWorkflow.value = workflows.value[0];
    }
  } catch (err) {
    useAlert('Erro ao carregar workflows.');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchWorkflows();
});

const handleTabChange = tab => {
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
    router.push({
      name: 'workflow_builder',
      params: { workflowId: res.data.id },
    });
  } catch (err) {
    useAlert('Erro ao criar workflow.');
  }
};

const handleSelectWorkflow = wf => {
  selectedWorkflow.value = wf;
};

const filteredWorkflows = computed(() => {
  return workflows.value.filter(w => {
    const matchesSearch =
      !searchQuery.value ||
      w.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      w.description?.toLowerCase().includes(searchQuery.value.toLowerCase());
    const matchesStatus =
      filterStatus.value === 'ALL' ||
      w.status === filterStatus.value.toLowerCase();
    const matchesTrigger =
      filterTrigger.value === 'ALL' ||
      w.trigger_type === filterTrigger.value.toLowerCase();
    return matchesSearch && matchesStatus && matchesTrigger;
  });
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    class="flex h-full bg-n-background text-n-slate-12 overflow-hidden select-none"
  >
    <!-- COLUNA PRINCIPAL ESQUERDA (TABELAS E FILTROS) -->
    <div class="flex-1 flex flex-col min-w-0 border-r border-n-weak">
      <!-- HEADER PRINCIPAL -->
      <header
        class="p-6 border-b border-n-weak bg-n-solid-1 flex items-center justify-between"
      >
        <div>
          <h1 class="text-xl font-bold text-n-slate-12 tracking-tight">
            Workflows
          </h1>
          <p class="text-xs text-n-slate-11 mt-1">
            Automatize suas conversas com fluxos visuais e ações integradas.
          </p>
        </div>

        <button
          type="button"
          class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-n-slate-12 text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center gap-1.5"
          @click="showCreateModal = true"
        >
          <span>+</span>
          <span>Novo Workflow</span>
        </button>
      </header>

      <!-- TABS DE NAVEGAÇÃO DE STATUS COM COUNTERS -->
      <div
        class="flex items-center gap-6 px-6 pt-4 border-b border-n-weak text-xs"
      >
        <button
          type="button"
          class="pb-3 flex items-center gap-2 font-semibold transition-colors"
          :class="
            currentTab === 'all'
              ? 'text-blue-400 border-b-2 border-blue-500'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="handleTabChange('all')"
        >
          <span>Todos</span>
          <span
            class="px-1.5 py-0.5 rounded-full bg-n-alpha-2 text-[10px] text-n-slate-11 font-bold"
          >
            {{ stats.total || workflows.length }}
          </span>
        </button>

        <button
          type="button"
          class="pb-3 flex items-center gap-2 font-semibold transition-colors"
          :class="
            currentTab === 'active'
              ? 'text-blue-400 border-b-2 border-blue-500'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="handleTabChange('active')"
        >
          <span>Ativos</span>
          <span
            class="px-1.5 py-0.5 rounded-full bg-emerald-500/20 text-[10px] text-emerald-400 font-bold"
          >
            {{ stats.active }}
          </span>
        </button>

        <button
          type="button"
          class="pb-3 flex items-center gap-2 font-semibold transition-colors"
          :class="
            currentTab === 'paused'
              ? 'text-blue-400 border-b-2 border-blue-500'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="handleTabChange('paused')"
        >
          <span>Pausados</span>
          <span
            class="px-1.5 py-0.5 rounded-full bg-amber-500/20 text-[10px] text-amber-400 font-bold"
          >
            {{ stats.paused }}
          </span>
        </button>

        <button
          type="button"
          class="pb-3 flex items-center gap-2 font-semibold transition-colors"
          :class="
            currentTab === 'draft'
              ? 'text-blue-400 border-b-2 border-blue-500'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="handleTabChange('draft')"
        >
          <span>Rascunhos</span>
          <span
            class="px-1.5 py-0.5 rounded-full bg-n-alpha-2 text-[10px] text-n-slate-11 font-bold"
          >
            {{ stats.drafts }}
          </span>
        </button>
      </div>

      <!-- BARRA DE PESQUISA E FILTROS -->
      <div
        class="p-6 pb-4 flex flex-col md:flex-row gap-3 items-center justify-between"
      >
        <div class="relative flex-1 w-full">
          <span class="absolute left-3.5 top-2.5 text-xs text-n-slate-9"
            >🔍</span
          >
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar workflows..."
            class="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div class="flex items-center gap-3 w-full md:w-auto">
          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Status</span>
            <select
              v-model="filterStatus"
              class="px-3 py-1.5 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-11 focus:outline-none"
            >
              <option value="ALL">Todos</option>
              <option value="ACTIVE">Ativo</option>
              <option value="PAUSED">Pausado</option>
              <option value="DRAFT">Rascunho</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Tipo de gatilho</span>
            <select
              v-model="filterTrigger"
              class="px-3 py-1.5 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-11 focus:outline-none"
            >
              <option value="ALL">Todos</option>
              <option value="WEBHOOK">Webhook</option>
              <option value="CONTACT">Novo Contato</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-11">Última atualização</span>
            <select
              v-model="selectedSort"
              class="px-3 py-1.5 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-11 focus:outline-none"
            >
              <option value="recent">Mais recentes</option>
              <option value="executions">Mais execuções</option>
            </select>
          </div>
        </div>
      </div>

      <!-- TABELA ESTILO REFERENCE PACK -->
      <div class="flex-1 overflow-y-auto px-6 pb-6">
        <div
          class="border border-n-weak/80 rounded-2xl bg-n-solid-1 overflow-hidden"
        >
          <table class="w-full text-left border-collapse text-xs">
            <thead>
              <tr
                class="border-b border-n-weak/80 text-[11px] font-semibold text-n-slate-11 uppercase tracking-wider"
              >
                <th class="py-3 px-4">Nome</th>
                <th class="py-3 px-4">Descrição</th>
                <th class="py-3 px-4">Gatilho</th>
                <th class="py-3 px-4">Status</th>
                <th class="py-3 px-4">Última atualização</th>
                <th class="py-3 px-4">Execuções</th>
                <th class="py-3 px-4 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="wf in filteredWorkflows"
                :key="wf.id"
                class="hover:bg-n-alpha-2/30 transition-colors cursor-pointer"
                :class="selectedWorkflow?.id === wf.id ? 'bg-blue-600/10' : ''"
                @click="handleSelectWorkflow(wf)"
              >
                <!-- NOME COM ÍCONE -->
                <td
                  class="py-3.5 px-4 font-bold text-n-slate-12 flex items-center gap-3"
                >
                  <div
                    class="w-8 h-8 rounded-xl flex items-center justify-center font-bold text-sm shrink-0"
                    :class="
                      wf.trigger_type === 'webhook'
                        ? 'bg-purple-500/20 text-purple-400'
                        : 'bg-emerald-500/20 text-emerald-400'
                    "
                  >
                    {{ wf.trigger_type === 'webhook' ? '⚡' : '💬' }}
                  </div>
                  <span class="truncate">{{ wf.name }}</span>
                </td>

                <!-- DESCRIÇÃO -->
                <td class="py-3.5 px-4 text-n-slate-11 truncate max-w-[200px]">
                  {{ wf.description || 'Sem descrição cadastrada' }}
                </td>

                <!-- GATILHO -->
                <td class="py-3.5 px-4 font-medium text-n-slate-11">
                  <span class="flex items-center gap-1.5">
                    <span class="text-amber-400">⚡</span>
                    <span>{{
                      wf.trigger_type === 'webhook' ? 'Webhook' : 'Novo Contato'
                    }}</span>
                  </span>
                </td>

                <!-- STATUS -->
                <td class="py-3.5 px-4">
                  <span
                    class="px-2.5 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1.5 w-max"
                    :class="
                      wf.status === 'active'
                        ? 'bg-emerald-500/20 text-emerald-400'
                        : wf.status === 'paused'
                          ? 'bg-amber-500/20 text-amber-400'
                          : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    <span
                      class="w-1.5 h-1.5 rounded-full"
                      :class="
                        wf.status === 'active'
                          ? 'bg-emerald-400'
                          : wf.status === 'paused'
                            ? 'bg-amber-400'
                            : 'bg-n-slate-9'
                      "
                    />
                    {{
                      wf.status === 'active'
                        ? 'Ativo'
                        : wf.status === 'paused'
                          ? 'Pausado'
                          : 'Rascunho'
                    }}
                  </span>
                </td>

                <!-- DATA -->
                <td class="py-3.5 px-4 text-n-slate-11 font-mono text-[11px]">
                  10 out 2026, 14:32
                </td>

                <!-- EXECUÇÕES -->
                <td class="py-3.5 px-4 font-mono text-n-slate-11">
                  <div>1.284</div>
                  <div class="text-[10px] text-emerald-400 font-sans">
                    🟢 96%
                  </div>
                </td>

                <!-- AÇÕES -->
                <td class="py-3.5 px-4 text-right">
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12 p-1 rounded-lg"
                    @click.stop="
                      router.push({
                        name: 'workflow_builder',
                        params: { workflowId: wf.id },
                      })
                    "
                  >
                    •••
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- COLUNA DIREITA: DRAWER DE DETALHES DO WORKFLOW SELECIONADO (ESTILO REFERENCE PACK) -->
    <div
      v-if="selectedWorkflow"
      class="w-96 bg-n-solid-1 flex flex-col justify-between overflow-y-auto p-6 space-y-6 select-none shrink-0"
    >
      <div class="space-y-6">
        <!-- HEADER DO DRAWER -->
        <div
          class="flex items-center justify-between pb-4 border-b border-n-weak"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="w-9 h-9 rounded-xl bg-purple-500/20 text-purple-400 flex items-center justify-center font-bold text-lg"
            >
              ⚡
            </div>
            <div class="min-w-0">
              <h3 class="text-sm font-bold text-n-slate-12 truncate">
                {{ selectedWorkflow.name }}
              </h3>
              <p class="text-xs text-n-slate-11">Workflow</p>
            </div>
          </div>
          <span
            class="text-[10px] px-2.5 py-0.5 rounded-full font-bold uppercase"
            :class="
              selectedWorkflow.status === 'active'
                ? 'bg-emerald-500/20 text-emerald-400'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{ selectedWorkflow.status === 'active' ? 'Ativo' : 'Rascunho' }}
          </span>
        </div>

        <!-- TABS DO DRAWER -->
        <div class="flex border-b border-n-weak text-xs">
          <button
            type="button"
            class="pb-2 px-3 font-semibold text-blue-400 border-b-2 border-blue-500"
          >
            Visão Geral
          </button>
          <button
            type="button"
            class="pb-2 px-3 font-semibold text-n-slate-11 hover:text-n-slate-12"
            @click="
              router.push({
                name: 'workflow_executions',
                params: { workflowId: selectedWorkflow.id },
              })
            "
          >
            Execuções
          </button>
          <button
            type="button"
            class="pb-2 px-3 font-semibold text-n-slate-11 hover:text-n-slate-12"
          >
            Configurações
          </button>
        </div>

        <!-- INFORMAÇÕES DO WORKFLOW -->
        <div class="space-y-3 text-xs">
          <div class="flex items-center justify-between">
            <h4 class="font-bold text-n-slate-11">Informações do Workflow</h4>
            <button
              type="button"
              class="text-blue-400 hover:text-blue-300 text-[11px] font-semibold"
            >
              ✎ Editar
            </button>
          </div>

          <div class="space-y-2 text-n-slate-11">
            <div>
              <span class="text-n-slate-9 block text-[10px]">Nome:</span>
              <p class="font-bold text-n-slate-12">
                {{ selectedWorkflow.name }}
              </p>
            </div>
            <div>
              <span class="text-n-slate-9 block text-[10px]">Descrição:</span>
              <p class="text-n-slate-11 text-[11px] leading-relaxed">
                {{
                  selectedWorkflow.description ||
                  'Qualifica leads do site e direciona para o time correto.'
                }}
              </p>
            </div>
          </div>
        </div>

        <!-- ESTATÍSTICAS DO WORKFLOW -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <h4 class="text-xs font-bold text-n-slate-11">Estatísticas</h4>
            <span class="text-[10px] text-n-slate-9">Últimos 30 dias</span>
          </div>

          <div class="grid grid-cols-2 gap-2.5">
            <div class="p-3 rounded-xl bg-n-background border border-n-weak">
              <span class="text-[10px] text-n-slate-9 block">📊 Execuções</span>
              <p class="text-base font-bold text-n-slate-12 mt-1">1.284</p>
            </div>
            <div class="p-3 rounded-xl bg-n-background border border-n-weak">
              <span class="text-[10px] text-n-slate-9 block"
                >📈 Taxa de sucesso</span
              >
              <p class="text-base font-bold text-emerald-400 mt-1">96%</p>
            </div>
            <div class="p-3 rounded-xl bg-n-background border border-n-weak">
              <span class="text-[10px] text-n-slate-9 block"
                >⏱️ Tempo médio</span
              >
              <p class="text-base font-bold text-n-slate-12 mt-1">1m 24s</p>
            </div>
            <div class="p-3 rounded-xl bg-n-background border border-n-weak">
              <span class="text-[10px] text-n-slate-9 block">⚠️ Falhas</span>
              <p class="text-base font-bold text-rose-400 mt-1">22</p>
            </div>
          </div>
        </div>

        <!-- GATILHO ASSOCIADO -->
        <div
          class="p-3.5 rounded-xl bg-n-background border border-n-weak space-y-2 text-xs"
        >
          <div class="flex items-center justify-between">
            <span class="font-bold text-n-slate-11">Gatilho</span>
            <span class="text-amber-400 font-bold flex items-center gap-1">
              <span>⚡</span> Webhook
            </span>
          </div>
          <div
            class="p-2 rounded-lg bg-n-solid-1 border border-n-weak/80 font-mono text-[10px] text-n-slate-11 flex items-center justify-between"
          >
            <span class="truncate"
              >/public/api/v1/webhook_dispatches/default</span
            >
            <button
              type="button"
              class="text-n-slate-11 hover:text-n-slate-12 ml-2"
            >
              📋
            </button>
          </div>
        </div>
      </div>

      <!-- BOTÃO EDITAR NO BUILDER (PRINCIPAL CTA) -->
      <div class="pt-4 border-t border-n-weak space-y-2">
        <button
          type="button"
          class="w-full py-2.5 px-4 rounded-xl bg-blue-600 hover:bg-blue-500 text-n-slate-12 text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center justify-center gap-2"
          @click="
            router.push({
              name: 'workflow_builder',
              params: { workflowId: selectedWorkflow.id },
            })
          "
        >
          <span>✎</span>
          <span>Editar no Builder</span>
        </button>

        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="py-2 px-3 rounded-xl border border-n-weak text-xs font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
            @click="
              router.push({
                name: 'workflow_executions',
                params: { workflowId: selectedWorkflow.id },
              })
            "
          >
            Ver Execuções
          </button>
          <button
            type="button"
            class="py-2 px-3 rounded-xl border border-n-weak text-xs font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
          >
            Testar
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL NOVO WORKFLOW -->
    <div
      v-if="showCreateModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4"
    >
      <div
        class="w-full max-w-md p-6 rounded-2xl bg-n-solid-1 border border-n-weak shadow-2xl space-y-4"
      >
        <h3 class="text-sm font-bold text-n-slate-12">Criar Novo Workflow</h3>
        <div>
          <label class="block text-xs font-semibold text-n-slate-11 mb-1"
            >Nome do Fluxo</label
          >
          <input
            v-model="newWorkflowName"
            type="text"
            placeholder="Ex: Boas-vindas WhatsApp"
            class="w-full px-3 py-2 text-xs rounded-xl bg-n-background border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-blue-500"
          />
        </div>
        <div>
          <label class="block text-xs font-semibold text-n-slate-11 mb-1"
            >Descrição</label
          >
          <textarea
            v-model="newWorkflowDesc"
            rows="3"
            placeholder="Descreva o propósito deste fluxo..."
            class="w-full p-3 text-xs rounded-xl bg-n-background border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-blue-500"
          />
        </div>
        <div class="flex items-center justify-end gap-2 pt-2">
          <button
            type="button"
            class="px-4 py-2 rounded-xl border border-n-weak text-xs font-semibold text-n-slate-11 hover:text-n-slate-12"
            @click="showCreateModal = false"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-n-slate-12 text-xs font-bold"
            @click="handleCreateWorkflow"
          >
            Criar & Abrir Builder
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
