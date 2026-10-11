<script>
import WebhookDispatchApi from 'dashboard/api/webhookDispatchTriggers';
import WorkflowsAPI from 'dashboard/api/workflows';
import { flattenPayload } from 'dashboard/routes/dashboard/workflows/variables';
import WebhookAttributeMapping from 'dashboard/routes/dashboard/workflows/components/WebhookAttributeMapping.vue';
import WebhookPathPicker from 'dashboard/routes/dashboard/workflows/components/WebhookPathPicker.vue';
import WebhookTestDialog from './WebhookTestDialog.vue';

export default {
  name: 'WebhookDispatchTriggersIndex',
  components: { WebhookAttributeMapping, WebhookPathPicker, WebhookTestDialog },
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
    activePayload() {
      const trigger = this.selectedTrigger;
      if (!trigger) return null;
      const pinned = trigger.pinned_payload;
      if (
        trigger.payload_pinned &&
        pinned &&
        typeof pinned === 'object' &&
        Object.keys(pinned).length
      ) {
        return pinned;
      }
      return trigger.sample_payload;
    },
    payloadFields() {
      const sample = this.activePayload;
      if (!sample || typeof sample !== 'object' || Array.isArray(sample)) {
        return [];
      }
      return flattenPayload(sample)
        .map(field => ({
          path: String(field.path || '').replace(/^webhook\./, ''),
          sample: field.sample,
        }))
        .filter(field => field.path && !['{…}', '[…]'].includes(field.sample));
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
    applyTrigger(data) {
      if (!data?.id) return;
      this.selectedTrigger = data;
      this.triggers = this.triggers.map(trigger =>
        trigger.id === data.id ? { ...trigger, ...data } : trigger
      );
      if (this.activeTestTrigger?.id === data.id) {
        this.activeTestTrigger = data;
      }
    },
    async saveMapping(patch) {
      const current = this.selectedTrigger;
      if (!current) return;
      this.mappingSaveId += 1;
      const requestId = this.mappingSaveId;
      this.mappingError = '';
      try {
        const response = await WebhookDispatchApi.updateTrigger(current.id, {
          field_mapping: patch,
        });
        if (requestId !== this.mappingSaveId) return;
        this.applyTrigger(response.data);
      } catch (error) {
        if (requestId !== this.mappingSaveId) return;
        this.mappingError = 'Não foi possível salvar o mapeamento.';
      }
    },
    saveAttributeRows(rows) {
      this.saveMapping({ custom_attributes: rows });
    },
    async togglePinned() {
      const current = this.selectedTrigger;
      if (!current) return;
      this.mappingError = '';
      try {
        const response = await WebhookDispatchApi.updateTrigger(current.id, {
          payload_pinned: !current.payload_pinned,
        });
        this.applyTrigger(response.data);
      } catch (error) {
        this.mappingError = 'Não foi possível atualizar o exemplo pinado.';
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
    },
  },
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    class="flex flex-1 w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-x-auto overflow-y-hidden"
  >
    <div class="flex flex-1 flex-col min-w-[52rem] border-e border-n-weak">
      <header
        class="px-6 py-5 border-b border-n-weak bg-n-solid-1 flex items-center justify-between gap-4"
      >
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">Webhooks</h1>
          <p class="text-sm text-n-slate-11 mt-0.5">
            Endpoints HTTP para receber eventos e iniciar workflows.
          </p>
        </div>

        <button
          type="button"
          class="h-10 ps-3 pe-4 rounded-xl bg-n-brand text-white text-sm font-semibold shadow-sm hover:opacity-90 flex items-center gap-2"
          @click="openModal()"
        >
          <span class="i-lucide-plus size-4" />
          Novo webhook
        </button>
      </header>

      <div class="flex flex-1 flex-col min-h-0 overflow-auto px-6 pb-4">
        <div class="rounded-2xl border border-n-weak bg-n-solid-1">
          <table class="w-full text-start text-sm">
            <thead>
              <tr
                class="border-b border-n-weak text-[0.6875rem] font-semibold text-n-slate-11 uppercase tracking-wide"
              >
                <th class="py-3 px-4">Nome do Gatilho</th>
                <th class="py-3 px-4">Endpoint URL</th>
                <th class="py-3 px-4">Workflow Associado</th>
                <th class="py-3 px-4">Status</th>
                <th class="py-3 px-4 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="trigger in triggers"
                :key="trigger.id"
                class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
                :class="
                  selectedTrigger?.id === trigger.id ? 'bg-n-brand/5' : ''
                "
                @click="selectedTrigger = trigger"
              >
                <!-- NOME -->
                <td class="py-3 px-4">
                  <div class="flex items-center gap-3 min-w-0">
                    <div
                      class="size-9 rounded-xl flex items-center justify-center shrink-0 bg-n-amber-9/15 text-n-amber-11"
                    >
                      <span class="i-lucide-webhook size-4" />
                    </div>
                    <div class="min-w-0">
                      <p class="font-medium text-n-slate-12 truncate">
                        {{ trigger.name }}
                      </p>
                      <p class="text-xs text-n-slate-11 truncate">
                        {{
                          trigger.workflow
                            ? 'Ligado ao fluxo'
                            : 'Sem fluxo vinculado'
                        }}
                      </p>
                    </div>
                  </div>
                </td>

                <!-- URL -->
                <td class="py-3.5 px-4">
                  <div class="flex items-center gap-2 max-w-[280px]">
                    <span
                      class="font-mono text-[11px] text-n-slate-11 truncate"
                    >
                      {{ getWebhookUrl(trigger.token) }}
                    </span>
                    <button
                      type="button"
                      class="text-xs text-n-slate-11 hover:text-n-slate-12 shrink-0"
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
                <td class="py-3.5 px-4 font-medium text-n-brand">
                  <button
                    v-if="trigger.workflow"
                    type="button"
                    class="flex items-center gap-1.5 text-start hover:underline"
                    @click.stop="openWorkflow(trigger.workflow)"
                  >
                    <span class="i-lucide-workflow size-3.5 shrink-0" />
                    <span class="truncate">{{ trigger.workflow.name }}</span>
                  </button>
                  <span v-else class="text-n-slate-11">
                    Nenhum fluxo vinculado
                  </span>
                </td>

                <!-- STATUS -->
                <td class="py-3.5 px-4">
                  <span
                    class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-xs font-medium"
                    :class="
                      trigger.active !== false
                        ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="
                        trigger.active !== false
                          ? 'bg-green-500'
                          : 'bg-n-slate-8'
                      "
                    />
                    {{ trigger.active !== false ? 'Ativo' : 'Inativo' }}
                  </span>
                </td>

                <!-- AÇÕES -->
                <td class="py-3.5 px-4 text-right space-x-2">
                  <button
                    type="button"
                    class="px-2.5 py-1 rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2 text-xs font-medium"
                    @click.stop="openTestModal(trigger)"
                  >
                    Testar
                  </button>
                  <button
                    type="button"
                    class="px-2.5 py-1 rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2 text-xs font-medium"
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
      class="w-[24rem] shrink-0 bg-n-solid-1 flex flex-col min-h-0 overflow-y-auto"
    >
      <div class="px-5 py-5 space-y-5">
        <div
          class="flex items-center gap-3 min-w-0 pb-4 border-b border-n-weak"
        >
          <div
            class="size-10 rounded-xl flex items-center justify-center shrink-0 bg-n-amber-9/15 text-n-amber-11"
          >
            <span class="i-lucide-webhook size-5" />
          </div>
          <div class="min-w-0">
            <h3 class="text-base font-semibold text-n-slate-12 truncate">
              {{ selectedTrigger.name }}
            </h3>
            <p class="text-xs text-n-slate-11 font-mono truncate">
              Token: {{ selectedTrigger.token }}
            </p>
          </div>
        </div>

        <!-- ENDPOINT CURL COMPLETO -->
        <div class="space-y-2">
          <label class="block text-xs font-semibold text-n-slate-12"
            >Endpoint externo</label
          >
          <div
            class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 font-mono text-[10px] text-n-slate-11"
          >
            <p class="font-semibold text-green-700 dark:text-green-300">
              curl -X POST \
            </p>
            <p class="break-all">
              {{ getWebhookUrl(selectedTrigger.token) }} \
            </p>
            <p class="text-n-slate-11">-H "Content-Type: application/json" \</p>
            <p class="text-n-slate-11">
              -d '{"customer": {"phone": "17991173157"}}'
            </p>
          </div>
        </div>

        <!-- MAPEAMENTO DE CAMPOS -->
        <div
          class="p-3.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 text-xs"
        >
          <div class="flex items-center justify-between gap-2">
            <h4 class="font-semibold text-n-slate-12">Mapeamento do payload</h4>
            <button
              v-if="selectedTrigger.payload_pinned"
              type="button"
              class="inline-flex items-center gap-1 text-[0.6875rem] font-medium text-n-amber-11"
              @click="togglePinned"
            >
              <span class="i-lucide-pin size-3" />
              Desafixar
            </button>
          </div>
          <p
            v-if="!payloadFields.length"
            class="text-[0.6875rem] text-n-slate-11"
          >
            Abra Testar e salve um JSON de exemplo para escolher os campos.
          </p>
          <div>
            <label class="mb-1 block text-[0.6875rem] text-n-slate-11">
              Telefone do contato
            </label>
            <WebhookPathPicker
              :model-value="selectedTrigger.field_mapping?.phone_path || ''"
              :fields="payloadFields"
              placeholder="customer.phone"
              @update:model-value="saveMapping({ phone_path: $event })"
            />
          </div>
          <div>
            <label class="mb-1 block text-[0.6875rem] text-n-slate-11">
              Nome do contato
            </label>
            <WebhookPathPicker
              :model-value="selectedTrigger.field_mapping?.name_path || ''"
              :fields="payloadFields"
              placeholder="customer.name"
              @update:model-value="saveMapping({ name_path: $event })"
            />
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
          <h4 class="text-xs font-semibold text-n-slate-12">
            Últimas requisições
          </h4>
          <p
            v-if="!selectedTrigger.recent_dispatches?.length"
            class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak text-[11px] text-n-slate-11"
          >
            Nenhum disparo registrado.
          </p>
          <div
            v-for="dispatch in selectedTrigger.recent_dispatches"
            :key="dispatch.id"
            class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-1"
          >
            <div class="flex items-center justify-between text-[11px]">
              <span
                class="font-bold"
                :class="
                  dispatch.status === 'failed'
                    ? 'text-n-ruby-11'
                    : 'text-green-700 dark:text-green-300'
                "
              >
                {{ dispatch.status }}
              </span>
              <span class="text-n-slate-10 font-mono text-[10px]">{{
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
      <div class="px-5 py-4 border-t border-n-weak flex items-center gap-2">
        <button
          v-if="selectedTrigger.workflow"
          type="button"
          class="flex-1 h-9 px-3 rounded-xl border border-n-weak text-n-slate-12 hover:bg-n-alpha-2 text-sm font-medium"
          @click="openWorkflow(selectedTrigger.workflow)"
        >
          Abrir fluxo
        </button>
        <button
          type="button"
          class="flex-1 h-9 px-3 rounded-xl bg-n-brand text-white text-sm font-semibold hover:opacity-90"
          @click="openTestModal(selectedTrigger)"
        >
          Testar disparo
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

    <WebhookTestDialog
      v-if="showTestModal && activeTestTrigger"
      :trigger="activeTestTrigger"
      @close="closeTestModal"
      @updated="applyTrigger"
    />

    <div
      v-if="showModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-6"
      @click.self="closeModal"
    >
      <form
        class="w-full max-w-md rounded-2xl bg-n-solid-1 border border-n-weak p-6 space-y-4"
        @submit.prevent="saveTrigger"
      >
        <div>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ editingId ? 'Editar webhook' : 'Novo webhook' }}
          </h2>
          <p class="mt-1 text-xs text-n-slate-11">
            O endereço criado aqui é o mesmo gatilho usado dentro do fluxo.
          </p>
        </div>

        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-11"
            >Nome</label
          >
          <input
            v-model="form.name"
            type="text"
            class="reset-base w-full h-9 m-0 px-3 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            placeholder="Pedido pago"
          />
        </div>

        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-11"
            >Caixa de entrada</label
          >
          <select
            v-model="form.inbox_id"
            class="reset-base w-full h-9 m-0 py-0 ps-3 pe-8 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
          >
            <option value="" disabled>Selecione</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </div>

        <div v-if="!editingId" class="space-y-2">
          <label class="block text-xs font-medium text-n-slate-11">Fluxo</label>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input v-model="form.workflowMode" type="radio" value="new" />
            Criar um fluxo novo com este webhook
          </label>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input v-model="form.workflowMode" type="radio" value="existing" />
            Vincular a um fluxo que ainda não tem webhook
          </label>
          <select
            v-if="form.workflowMode === 'existing'"
            v-model="form.workflow_id"
            class="reset-base w-full h-9 m-0 py-0 ps-3 pe-8 text-sm rounded-lg bg-n-solid-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
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
            class="h-9 px-3 rounded-lg text-sm text-n-slate-11 hover:bg-n-alpha-2"
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
