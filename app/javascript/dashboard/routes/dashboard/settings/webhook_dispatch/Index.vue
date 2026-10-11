<script>
import WebhookDispatchApi from 'dashboard/api/webhookDispatchTriggers';
import WorkflowsAPI from 'dashboard/api/workflows';
import { flattenPayload } from 'dashboard/routes/dashboard/workflows/variables';
import WebhookAttributeMapping from 'dashboard/routes/dashboard/workflows/components/WebhookAttributeMapping.vue';

export default {
  name: 'WebhookDispatchTriggersIndex',
  components: { WebhookAttributeMapping },
  data() {
    return {
      triggers: [],
      workflows: [],
      loading: true,
      saving: false,
      formError: '',
      mappingError: '',
      mappingSaveId: 0,
      showModal: false,
      showTestModal: false,
      editingId: null,
      copiedToken: null,
      selectedTrigger: null,
      testPayloadText: JSON.stringify(
        {
          customer: {
            name: 'Mestre Samuel',
            phone: '17991173157',
            first_name: 'Samuel',
          },
          order: {
            order_id: 'ORD-9842',
            total: 'R$ 150,00',
            source: 'instagram',
          },
        },
        null,
        2
      ),
      testResult: null,
      activeTestTrigger: null,
      form: {
        name: '',
        inbox_id: '',
        active: true,
        workflowMode: 'new',
        workflow_id: '',
      },
    };
  },
  computed: {
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'] || [];
    },
    workflowsWithoutWebhook() {
      const linked = new Set(
        this.triggers.map(trigger => trigger.workflow?.id).filter(Boolean)
      );
      return this.workflows.filter(workflow => !linked.has(workflow.id));
    },
    contactAttributeOptions() {
      return this.$store.getters['attributes/getAttributesByModel'](
        'contact_attribute'
      );
    },
    payloadFields() {
      const sample = this.selectedTrigger?.sample_payload;
      if (!sample || typeof sample !== 'object') return [];
      return flattenPayload(sample)
        .map(field => ({
          path: String(field.path || '').replace(/^webhook\./, ''),
        }))
        .filter(field => field.path);
    },
    attributeRows() {
      return this.selectedTrigger?.field_mapping?.custom_attributes || [];
    },
  },
  mounted() {
    this.fetchTriggers();
    this.$store.dispatch('attributes/get');
  },
  methods: {
    async fetchTriggers() {
      this.loading = true;
      try {
        const response = await WebhookDispatchApi.getTriggers();
        this.triggers = response.data;
        const wanted = Number(this.$route.query.id);
        const matched = this.triggers.find(trigger => trigger.id === wanted);
        if (matched) {
          this.selectedTrigger = matched;
        } else if (this.triggers.length && !this.selectedTrigger) {
          this.selectedTrigger = this.triggers[0];
        } else if (this.selectedTrigger) {
          this.selectedTrigger =
            this.triggers.find(
              trigger => trigger.id === this.selectedTrigger.id
            ) ||
            this.triggers[0] ||
            null;
        }
      } catch {
        this.triggers = [];
      } finally {
        this.loading = false;
      }
    },
    formatStamp(value) {
      if (!value) return '—';
      return new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      }).format(new Date(value));
    },
    getWebhookUrl(token) {
      const origin = window.location.origin;
      return `${origin}/webhooks/trigger/${token}`;
    },
    copyUrl(url) {
      navigator.clipboard.writeText(url);
      this.copiedToken = url.split('/').pop();
      setTimeout(() => {
        this.copiedToken = null;
      }, 2000);
    },
    async openModal(trigger = null) {
      this.formError = '';
      try {
        const response = await WorkflowsAPI.getWorkflows();
        this.workflows = response.data.workflows || [];
      } catch (err) {
        this.workflows = [];
      }
      const defaultInbox = this.inboxes[0]?.id || '';
      if (trigger) {
        this.editingId = trigger.id;
        this.form = {
          name: trigger.name,
          inbox_id: trigger.inbox_id || defaultInbox,
          active: trigger.active !== false,
          workflowMode: 'existing',
          workflow_id: trigger.workflow?.id || '',
        };
      } else {
        this.editingId = null;
        this.form = {
          name: '',
          inbox_id: defaultInbox,
          active: true,
          workflowMode: 'new',
          workflow_id: '',
        };
      }
      this.showModal = true;
    },
    openWorkflow(workflow) {
      if (!workflow?.id) return;
      this.$router.push({
        name: 'workflow_builder',
        params: { workflowId: workflow.id },
        query: { select: 'trigger' },
      });
    },
    closeModal() {
      this.showModal = false;
    },
    async saveAttributeRows(rows) {
      const current = this.selectedTrigger;
      if (!current) return;
      this.mappingSaveId += 1;
      const requestId = this.mappingSaveId;
      this.mappingError = '';
      try {
        const response = await WebhookDispatchApi.updateTrigger(current.id, {
          field_mapping: { custom_attributes: rows },
        });
        if (requestId !== this.mappingSaveId) return;
        this.selectedTrigger = response.data;
        this.triggers = this.triggers.map(trigger =>
          trigger.id === response.data.id
            ? { ...trigger, field_mapping: response.data.field_mapping }
            : trigger
        );
      } catch (error) {
        if (requestId !== this.mappingSaveId) return;
        this.mappingError = 'Não foi possível salvar o mapeamento.';
      }
    },
    async saveTrigger() {
      this.formError = '';
      if (!this.form.name.trim()) {
        this.formError = 'Informe o nome do webhook.';
        return;
      }
      if (!this.form.inbox_id) {
        this.formError = 'Selecione a caixa de entrada.';
        return;
      }
      if (
        !this.editingId &&
        this.form.workflowMode === 'existing' &&
        !this.form.workflow_id
      ) {
        this.formError = 'Selecione o fluxo que vai usar este webhook.';
        return;
      }
      this.saving = true;
      try {
        const payload = {
          name: this.form.name.trim(),
          inbox_id: this.form.inbox_id,
          active: this.form.active,
        };
        let saved;
        if (this.editingId) {
          saved = await WebhookDispatchApi.updateTrigger(
            this.editingId,
            payload
          );
        } else {
          if (this.form.workflowMode === 'existing') {
            payload.workflow_id = this.form.workflow_id;
          }
          saved = await WebhookDispatchApi.createTrigger(payload);
        }
        this.closeModal();
        await this.fetchTriggers();
        const savedId = saved.data?.id;
        if (savedId) {
          this.selectedTrigger =
            this.triggers.find(trigger => trigger.id === savedId) ||
            this.selectedTrigger;
        }
      } catch (err) {
        const message = err.response?.data?.error;
        this.formError = Array.isArray(message)
          ? message.join(' ')
          : 'Não foi possível salvar o webhook.';
      } finally {
        this.saving = false;
      }
    },
    async deleteTrigger(id) {
      if (
        !window.confirm('Deseja realmente excluir este gatilho de webhook?')
      ) {
        return;
      }
      try {
        await WebhookDispatchApi.deleteTrigger(id);
        await this.fetchTriggers();
      } catch {
        this.formError = 'Não foi possível excluir o webhook.';
      }
    },
    openTestModal(trigger) {
      this.activeTestTrigger = trigger;
      this.testResult = null;
      this.showTestModal = true;
    },
    closeTestModal() {
      this.showTestModal = false;
      this.activeTestTrigger = null;
      this.testResult = null;
    },
    async runTest() {
      try {
        let payload = {};
        try {
          payload = JSON.parse(this.testPayloadText);
        } catch (e) {
          alert('JSON inválido no corpo do teste.');
          return;
        }
        const res = await WebhookDispatchApi.testTrigger(
          this.activeTestTrigger.id,
          payload
        );
        this.testResult = res.data;
      } catch (err) {
        this.testResult = {
          error: err.response?.data?.error || err.message,
        };
      }
    },
  },
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    class="flex flex-1 w-full h-full min-h-0 min-w-0 bg-[#0D1017] text-slate-100 overflow-x-auto overflow-y-hidden select-none"
  >
    <!-- COLUNA ESQUERDA: LISTA DE WEBHOOK TRIGGERS -->
    <div class="flex flex-1 flex-col min-w-[52rem] border-r border-slate-800">
      <!-- HEADER -->
      <header
        class="p-6 border-b border-slate-800 bg-[#14171F] flex items-center justify-between"
      >
        <div>
          <h1 class="text-xl font-bold text-white tracking-tight">
            Webhooks (Gatilhos de Entrada)
          </h1>
          <p class="text-xs text-slate-400 mt-1">
            Endpoints HTTP externos para receber eventos (Shopify, Hotmart, n8n)
            e iniciar Workflows.
          </p>
        </div>

        <button
          type="button"
          class="px-4 py-2 rounded-xl bg-n-blue-9 hover:bg-n-blue-9 text-white text-xs font-bold shadow-lg shadow-n-blue-9/20 transition-all flex items-center gap-1.5"
          @click="openModal()"
        >
          <span>+</span>
          <span>Novo Webhook</span>
        </button>
      </header>

      <!-- TABELA DE WEBHOOKS (ESTILO REFERENCE PACK) -->
      <div class="flex flex-1 flex-col min-h-0 overflow-auto p-6">
        <div
          class="flex flex-col flex-1 min-h-0 min-w-[48rem] border border-slate-800/80 rounded-2xl bg-[#14171F]"
        >
          <table class="w-full text-left border-collapse text-xs">
            <thead>
              <tr
                class="border-b border-slate-800/80 text-[11px] font-semibold text-slate-400 uppercase tracking-wider"
              >
                <th class="py-3 px-4">Nome do Gatilho</th>
                <th class="py-3 px-4">Endpoint URL</th>
                <th class="py-3 px-4">Workflow Associado</th>
                <th class="py-3 px-4">Status</th>
                <th class="py-3 px-4 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr
                v-for="trigger in triggers"
                :key="trigger.id"
                class="hover:bg-slate-800/30 transition-colors cursor-pointer"
                :class="
                  selectedTrigger?.id === trigger.id ? 'bg-n-blue-9/10' : ''
                "
                @click="selectedTrigger = trigger"
              >
                <!-- NOME -->
                <td
                  class="py-3.5 px-4 font-bold text-slate-100 flex items-center gap-3"
                >
                  <div
                    class="w-8 h-8 rounded-xl bg-n-amber-9/20 text-n-amber-11 flex items-center justify-center font-bold text-sm shrink-0"
                  >
                    <span class="i-lucide-webhook size-4" />
                  </div>
                  <div>
                    <p class="truncate">{{ trigger.name }}</p>
                    <p class="text-[10px] text-slate-400">
                      {{
                        trigger.workflow
                          ? 'Ligado ao fluxo'
                          : 'Sem fluxo vinculado'
                      }}
                    </p>
                  </div>
                </td>

                <!-- URL -->
                <td class="py-3.5 px-4">
                  <div class="flex items-center gap-2 max-w-[280px]">
                    <span class="font-mono text-[11px] text-slate-400 truncate">
                      {{ getWebhookUrl(trigger.token) }}
                    </span>
                    <button
                      type="button"
                      class="text-xs text-slate-400 hover:text-white shrink-0"
                      title="Copiar URL"
                      @click.stop="copyUrl(getWebhookUrl(trigger.token))"
                    >
                      <span
                        class="size-3.5"
                        :class="
                          copiedToken === trigger.token
                            ? 'i-lucide-check'
                            : 'i-lucide-copy'
                        "
                      />
                    </button>
                  </div>
                </td>

                <!-- WORKFLOW -->
                <td class="py-3.5 px-4 font-medium text-n-blue-11">
                  <button
                    v-if="trigger.workflow"
                    type="button"
                    class="flex items-center gap-1.5 text-start hover:underline"
                    @click.stop="openWorkflow(trigger.workflow)"
                  >
                    <span class="i-lucide-workflow size-3.5 shrink-0" />
                    <span class="truncate">{{ trigger.workflow.name }}</span>
                  </button>
                  <span v-else class="text-slate-400">
                    Nenhum fluxo vinculado
                  </span>
                </td>

                <!-- STATUS -->
                <td class="py-3.5 px-4">
                  <span
                    class="px-2.5 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1.5 w-max"
                    :class="
                      trigger.active !== false
                        ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                        : 'bg-slate-800 text-slate-400'
                    "
                  >
                    <span
                      class="w-1.5 h-1.5 rounded-full"
                      :class="
                        trigger.active !== false
                          ? 'bg-green-400'
                          : 'bg-slate-400'
                      "
                    />
                    {{ trigger.active !== false ? 'Ativo' : 'Inativo' }}
                  </span>
                </td>

                <!-- AÇÕES -->
                <td class="py-3.5 px-4 text-right space-x-2">
                  <button
                    type="button"
                    class="px-2.5 py-1 rounded-lg border border-slate-700 text-slate-300 hover:bg-slate-800 text-[11px] font-semibold"
                    @click.stop="openTestModal(trigger)"
                  >
                    Testar
                  </button>
                  <button
                    type="button"
                    class="px-2.5 py-1 rounded-lg border border-slate-700 text-slate-300 hover:bg-slate-800 text-[11px] font-semibold"
                    @click.stop="openModal(trigger)"
                  >
                    Editar
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- COLUNA DIREITA: DETALHES TÉCNICOS & LOGS DO WEBHOOK SELECIONADO -->
    <div
      v-if="selectedTrigger"
      class="w-96 bg-[#14171F] flex flex-col justify-between overflow-y-auto p-6 space-y-6 select-none shrink-0"
    >
      <div class="space-y-6">
        <!-- HEADER DO GATILHO -->
        <div
          class="flex items-center justify-between pb-4 border-b border-slate-800"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="w-9 h-9 rounded-xl bg-n-amber-9/20 text-n-amber-11 flex items-center justify-center font-bold text-lg"
            >
              <span class="i-lucide-webhook size-4" />
            </div>
            <div class="min-w-0">
              <h3 class="text-sm font-bold text-white truncate">
                {{ selectedTrigger.name }}
              </h3>
              <p class="text-xs text-slate-400 font-mono">
                Token: {{ selectedTrigger.token }}
              </p>
            </div>
          </div>
        </div>

        <!-- ENDPOINT CURL COMPLETO -->
        <div class="space-y-2">
          <label class="block text-xs font-bold text-slate-300"
            >Endpoint Externo (cURL)</label
          >
          <div
            class="p-3 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 font-mono text-[10px] text-slate-300"
          >
            <p class="text-green-400 font-bold">curl -X POST \</p>
            <p class="break-all">
              {{ getWebhookUrl(selectedTrigger.token) }} \
            </p>
            <p class="text-slate-400">-H "Content-Type: application/json" \</p>
            <p class="text-slate-400">
              -d '{"customer": {"phone": "17991173157"}}'
            </p>
          </div>
        </div>

        <!-- MAPEAMENTO DE CAMPOS -->
        <div
          class="p-3.5 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 text-xs"
        >
          <h4 class="font-bold text-slate-300">Mapeamento de Payload</h4>
          <div class="space-y-1 text-[11px] text-slate-400">
            <div class="flex justify-between">
              <span>Telefone do Contato:</span>
              <span class="font-mono text-slate-200">{{
                selectedTrigger.field_mapping?.phone_path || 'customer.phone'
              }}</span>
            </div>
            <div class="flex justify-between">
              <span>Nome do Contato:</span>
              <span class="font-mono text-slate-200">{{
                selectedTrigger.field_mapping?.name_path || 'customer.name'
              }}</span>
            </div>
          </div>
          <WebhookAttributeMapping
            :rows="attributeRows"
            :attributes="contactAttributeOptions"
            :fields="payloadFields"
            @change="saveAttributeRows"
          />
          <p v-if="mappingError" class="text-[0.6875rem] text-n-ruby-11">
            {{ mappingError }}
          </p>
        </div>

        <!-- ÚLTIMAS REQUESTS RECEBIDAS -->
        <div class="space-y-2">
          <h4 class="text-xs font-bold text-slate-300">
            Últimas Requisições (Logs)
          </h4>
          <p
            v-if="!selectedTrigger.recent_dispatches?.length"
            class="p-3 rounded-xl bg-[#0D1017] border border-slate-800 text-[11px] text-slate-400"
          >
            Nenhum disparo registrado.
          </p>
          <div
            v-for="dispatch in selectedTrigger.recent_dispatches"
            :key="dispatch.id"
            class="p-3 rounded-xl bg-[#0D1017] border border-slate-800 space-y-1"
          >
            <div class="flex items-center justify-between text-[11px]">
              <span
                class="font-bold"
                :class="
                  dispatch.status === 'failed'
                    ? 'text-n-ruby-11'
                    : 'text-green-400'
                "
              >
                {{ dispatch.status }}
              </span>
              <span class="text-slate-500 font-mono text-[10px]">{{
                formatStamp(dispatch.created_at)
              }}</span>
            </div>
            <p
              v-if="dispatch.error_message"
              class="text-[10px] text-n-ruby-11 truncate"
            >
              {{ dispatch.error_message }}
            </p>
          </div>
        </div>
      </div>

      <!-- BOTÃO TESTAR OU EXCLUIR -->
      <div class="pt-4 border-t border-slate-800 flex items-center gap-2">
        <button
          v-if="selectedTrigger.workflow"
          type="button"
          class="flex-1 py-2 px-3 rounded-xl border border-slate-700 text-slate-100 hover:bg-slate-800 text-xs font-bold"
          @click="openWorkflow(selectedTrigger.workflow)"
        >
          Abrir fluxo
        </button>
        <button
          type="button"
          class="flex-1 py-2 px-3 rounded-xl bg-n-brand text-white text-xs font-bold transition-colors"
          @click="openTestModal(selectedTrigger)"
        >
          Testar Disparo
        </button>
        <button
          type="button"
          class="py-2 px-3 rounded-xl border border-n-ruby-9/30 text-n-ruby-11 hover:bg-n-ruby-9/10 text-xs font-semibold"
          @click="deleteTrigger(selectedTrigger.id)"
        >
          Excluir
        </button>
      </div>
    </div>

    <div
      v-if="showModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-6"
      @click.self="closeModal"
    >
      <form
        class="w-full max-w-md rounded-2xl bg-[#14171F] border border-slate-800 p-6 space-y-4"
        @submit.prevent="saveTrigger"
      >
        <div>
          <h2 class="text-base font-bold text-white">
            {{ editingId ? 'Editar webhook' : 'Novo webhook' }}
          </h2>
          <p class="mt-1 text-xs text-slate-400">
            O endereço criado aqui é o mesmo gatilho usado dentro do fluxo.
          </p>
        </div>

        <div>
          <label class="block mb-1.5 text-xs font-medium text-slate-300"
            >Nome</label
          >
          <input
            v-model="form.name"
            type="text"
            class="reset-base w-full h-9 m-0 px-3 text-sm rounded-lg bg-[#0D1017] border border-slate-700 text-white"
            placeholder="Pedido pago"
          />
        </div>

        <div>
          <label class="block mb-1.5 text-xs font-medium text-slate-300"
            >Caixa de entrada</label
          >
          <select
            v-model="form.inbox_id"
            class="reset-base w-full h-9 m-0 py-0 ps-3 pe-8 text-sm rounded-lg bg-[#0D1017] border border-slate-700 text-white"
          >
            <option value="" disabled>Selecione</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </div>

        <div v-if="!editingId" class="space-y-2">
          <label class="block text-xs font-medium text-slate-300">Fluxo</label>
          <label class="flex items-center gap-2 text-sm text-slate-200">
            <input v-model="form.workflowMode" type="radio" value="new" />
            Criar um fluxo novo com este webhook
          </label>
          <label class="flex items-center gap-2 text-sm text-slate-200">
            <input v-model="form.workflowMode" type="radio" value="existing" />
            Vincular a um fluxo que ainda não tem webhook
          </label>
          <select
            v-if="form.workflowMode === 'existing'"
            v-model="form.workflow_id"
            class="reset-base w-full h-9 m-0 py-0 ps-3 pe-8 text-sm rounded-lg bg-[#0D1017] border border-slate-700 text-white"
          >
            <option value="" disabled>Selecione o fluxo</option>
            <option
              v-for="workflow in workflowsWithoutWebhook"
              :key="workflow.id"
              :value="workflow.id"
            >
              {{ workflow.name }}
            </option>
          </select>
        </div>

        <p v-if="formError" class="text-xs text-n-ruby-11">{{ formError }}</p>

        <div class="flex justify-end gap-2 pt-2">
          <button
            type="button"
            class="h-9 px-3 rounded-lg text-sm text-slate-300 hover:bg-slate-800"
            @click="closeModal"
          >
            Cancelar
          </button>
          <button
            type="submit"
            class="h-9 px-4 rounded-lg bg-n-brand text-sm font-semibold text-white disabled:opacity-50"
            :disabled="saving"
          >
            {{ saving ? 'Salvando…' : 'Salvar' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
