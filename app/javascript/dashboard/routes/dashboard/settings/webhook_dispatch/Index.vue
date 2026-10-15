<script>
import WebhookDispatchApi from 'dashboard/api/webhookDispatchTriggers';
import WorkflowsAPI from 'dashboard/api/workflows';
import { flattenPayload } from 'dashboard/routes/dashboard/workflows/variables';
import { curlExample } from 'dashboard/routes/dashboard/workflows/webhookMapping';
import WebhookFieldMapping from 'dashboard/routes/dashboard/workflows/components/WebhookFieldMapping.vue';
import WebhookTestDialog from './WebhookTestDialog.vue';

export default {
  name: 'WebhookDispatchTriggersIndex',
  components: { WebhookFieldMapping, WebhookTestDialog },
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
      showDetails: false,
      showTestModal: false,
      confirmingDelete: false,
      copiedCurl: false,
      detailName: '',
      detailInboxId: '',
      inboxMenuOpen: false,
      savingDetails: false,
      detailError: '',
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
    conversationAttributeOptions() {
      return this.$store.getters['attributes/getAttributesByModel'](
        'conversation_attribute'
      );
    },
    curlText() {
      const trigger = this.selectedTrigger;
      if (!trigger?.token) return '';
      return curlExample(
        this.getWebhookUrl(trigger.token),
        trigger.field_mapping || {}
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
          this.showDetails = true;
        } else if (this.selectedTrigger) {
          this.selectedTrigger =
            this.triggers.find(
              trigger => trigger.id === this.selectedTrigger.id
            ) || null;
          if (!this.selectedTrigger) this.showDetails = false;
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
    copyCurl() {
      if (!this.curlText) return;
      navigator.clipboard.writeText(this.curlText);
      this.copiedCurl = true;
      setTimeout(() => {
        this.copiedCurl = false;
      }, 2000);
    },
    inboxName(inboxId) {
      return (
        this.inboxes.find(inbox => inbox.id === inboxId)?.name ||
        'Caixa não encontrada'
      );
    },
    dispatchStatusLabel(status) {
      return (
        {
          running: 'Em execução',
          waiting: 'Aguardando',
          completed: 'Concluída',
          failed: 'Falhou',
          cancelled: 'Cancelada',
          paused: 'Pausada',
        }[status] || status
      );
    },
    openDetails(trigger) {
      this.selectedTrigger = trigger;
      this.detailName = trigger.name || '';
      this.detailInboxId = trigger.inbox_id || '';
      this.detailError = '';
      this.inboxMenuOpen = false;
      this.confirmingDelete = false;
      this.showDetails = true;
    },
    closeDetails() {
      this.showDetails = false;
      this.confirmingDelete = false;
      this.inboxMenuOpen = false;
    },
    async openModal() {
      this.formError = '';
      try {
        const response = await WorkflowsAPI.getWorkflows();
        this.workflows = response.data.workflows || [];
      } catch (err) {
        this.workflows = [];
      }
      this.editingId = null;
      this.form = {
        name: '',
        inbox_id: this.inboxes[0]?.id || '',
        active: true,
        workflowMode: 'new',
        workflow_id: '',
      };
      this.showModal = true;
    },
    async selectInbox(inboxId) {
      this.detailInboxId = inboxId;
      this.inboxMenuOpen = false;
      await this.saveDetails();
    },
    async saveDetails() {
      const current = this.selectedTrigger;
      if (!current || this.savingDetails) return;
      const name = this.detailName.trim();
      if (!name) {
        this.detailError = 'Informe o nome do webhook.';
        return;
      }
      if (!this.detailInboxId) {
        this.detailError = 'Selecione a caixa de entrada.';
        return;
      }
      if (
        name === current.name &&
        String(this.detailInboxId) === String(current.inbox_id)
      ) {
        this.detailError = '';
        return;
      }
      this.savingDetails = true;
      this.detailError = '';
      try {
        const response = await WebhookDispatchApi.updateTrigger(current.id, {
          name,
          inbox_id: this.detailInboxId,
        });
        this.applyTrigger(response.data);
        this.detailName = response.data.name || name;
        this.detailInboxId = response.data.inbox_id || this.detailInboxId;
      } catch (err) {
        const message = err.response?.data?.error;
        this.detailError = Array.isArray(message)
          ? message.join(' ')
          : 'Não foi possível salvar o webhook.';
      } finally {
        this.savingDetails = false;
      }
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
    saveConversationRows(rows) {
      this.saveMapping({ conversation_attributes: rows });
    },
    updateMappingField(key, value) {
      this.saveMapping({ [key]: value });
    },
    async useDispatchPayload(dispatch) {
      const current = this.selectedTrigger;
      if (!current || !dispatch?.payload) return;
      this.mappingError = '';
      try {
        const response = await WebhookDispatchApi.updateTrigger(current.id, {
          sample_payload: dispatch.payload,
          payload_pinned: false,
        });
        this.applyTrigger(response.data);
      } catch (error) {
        this.mappingError =
          'Não foi possível usar essa requisição no mapeamento.';
      }
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
      try {
        await WebhookDispatchApi.deleteTrigger(id);
        this.showDetails = false;
        this.confirmingDelete = false;
        this.selectedTrigger = null;
        await this.fetchTriggers();
      } catch {
        this.mappingError = 'Não foi possível excluir o webhook.';
        this.confirmingDelete = false;
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
    class="flex flex-1 w-full h-full min-h-0 min-w-0 bg-n-background text-n-slate-12"
  >
    <div
      class="flex h-full min-h-0 w-full min-w-0 flex-1 flex-col overflow-hidden"
    >
      <header
        class="px-6 py-5 border-b border-n-weak bg-n-solid-1 flex items-center justify-between gap-4"
      >
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">Webhooks</h1>
          <p class="text-sm text-n-slate-11 mt-0.5">
            Endpoints HTTP para receber eventos e iniciar workflows. Abra um
            webhook para ver o endereço, o mapeamento e as requisições.
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

      <div class="flex min-h-0 flex-1 flex-col overflow-auto px-6 pb-6">
        <div class="flex w-full min-h-full flex-col gap-3">
          <div
            class="hidden sm:grid grid-cols-[minmax(12rem,16rem)_minmax(0,1fr)_minmax(10rem,14rem)_6rem_5.5rem] gap-3 px-4 text-[0.6875rem] font-semibold uppercase tracking-wide text-n-slate-11"
          >
            <span>Nome do Gatilho</span>
            <span>Endpoint URL</span>
            <span>Workflow Associado</span>
            <span>Status</span>
            <span class="text-end">Ações</span>
          </div>

          <p v-if="loading && !triggers.length" class="text-sm text-n-slate-11">
            Carregando webhooks…
          </p>
          <div
            v-else-if="!triggers.length"
            class="flex flex-col items-start gap-3 p-6 border border-dashed rounded-2xl border-n-weak"
          >
            <p class="text-sm text-n-slate-11">Nenhum webhook nesta conta.</p>
            <button
              type="button"
              class="h-9 px-3 text-sm font-medium rounded-lg bg-n-brand text-white"
              @click="openModal()"
            >
              Novo webhook
            </button>
          </div>

          <article
            v-for="trigger in triggers"
            :key="trigger.id"
            class="grid grid-cols-1 sm:grid-cols-[minmax(12rem,16rem)_minmax(0,1fr)_minmax(10rem,14rem)_6rem_5.5rem] items-center gap-2 sm:gap-3 px-4 py-2.5 rounded-xl border border-n-weak bg-n-solid-1 cursor-pointer hover:bg-n-alpha-1"
            :class="
              showDetails && selectedTrigger?.id === trigger.id
                ? 'bg-n-brand/5'
                : ''
            "
            @click="openDetails(trigger)"
          >
            <div class="flex items-center gap-3 min-w-0">
              <div
                class="flex items-center justify-center rounded-lg size-8 shrink-0 bg-n-amber-9/15 text-n-amber-11"
              >
                <span class="i-lucide-webhook size-4" />
              </div>
              <p class="font-medium truncate text-n-slate-12">
                {{ trigger.name }}
              </p>
            </div>

            <div class="flex items-center gap-2 min-w-0">
              <span class="font-mono text-[11px] truncate text-n-slate-11">
                {{ getWebhookUrl(trigger.token) }}
              </span>
              <button
                type="button"
                class="text-xs shrink-0 text-n-slate-11 hover:text-n-slate-12"
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

            <div class="min-w-0 font-medium text-n-brand">
              <button
                v-if="trigger.workflow"
                type="button"
                class="flex items-center gap-1.5 max-w-full text-start hover:underline"
                @click.stop="openWorkflow(trigger.workflow)"
              >
                <span class="i-lucide-workflow size-3.5 shrink-0" />
                <span class="truncate">{{ trigger.workflow.name }}</span>
              </button>
              <span v-else class="font-normal text-n-slate-11">
                Nenhum fluxo vinculado
              </span>
            </div>

            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-xs font-medium w-fit"
              :class="
                trigger.active !== false
                  ? 'bg-green-500/15 text-green-700 dark:text-green-300'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              <span
                class="size-1.5 rounded-full"
                :class="
                  trigger.active !== false ? 'bg-green-500' : 'bg-n-slate-8'
                "
              />
              {{ trigger.active !== false ? 'Ativo' : 'Inativo' }}
            </span>

            <div class="flex justify-end">
              <button
                type="button"
                class="px-2.5 py-1 text-xs font-medium rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
                @click.stop="openTestModal(trigger)"
              >
                Testar
              </button>
            </div>
          </article>
        </div>
      </div>
    </div>

    <div
      v-if="showDetails && selectedTrigger"
      class="fixed inset-0 z-40 flex items-center justify-center bg-n-alpha-black1 p-4 backdrop-blur-[4px]"
      @click.self="closeDetails"
    >
      <div
        class="flex w-full max-w-5xl max-h-[90vh] flex-col overflow-hidden rounded-2xl border border-n-weak bg-n-solid-1 shadow-xl"
      >
        <div
          class="flex items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
        >
          <div class="flex items-start gap-3 min-w-0">
            <div
              class="flex items-center justify-center rounded-xl size-11 shrink-0 bg-n-amber-9/15 text-n-amber-11"
            >
              <span class="i-lucide-webhook size-5" />
            </div>
            <div class="flex flex-col flex-1 min-w-0 gap-2">
              <div class="flex flex-wrap items-center gap-2">
                <input
                  v-model="detailName"
                  type="text"
                  class="reset-base m-0 h-9 min-w-0 flex-1 px-3 text-sm font-medium rounded-lg bg-n-alpha-1 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
                  @blur="saveDetails"
                  @keydown.enter="$event.target.blur()"
                />
                <span
                  class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="
                    selectedTrigger.active !== false
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-slate-3 text-n-slate-11'
                  "
                >
                  {{ selectedTrigger.active !== false ? 'Ativo' : 'Inativo' }}
                </span>
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <div class="relative">
                  <button
                    type="button"
                    class="inline-flex items-center gap-2 h-8 px-3 text-sm rounded-lg text-n-slate-12 outline outline-1 outline-n-weak hover:bg-n-alpha-2"
                    @click.stop="inboxMenuOpen = !inboxMenuOpen"
                  >
                    {{ inboxName(detailInboxId) }}
                    <span class="i-lucide-chevron-down size-3.5" />
                  </button>
                  <div
                    v-if="inboxMenuOpen"
                    class="absolute z-40 flex flex-col w-64 p-1 mt-1 border rounded-xl shadow-lg start-0 bg-n-solid-2 border-n-weak"
                  >
                    <button
                      v-for="inbox in inboxes"
                      :key="inbox.id"
                      type="button"
                      class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                      @click="selectInbox(inbox.id)"
                    >
                      {{ inbox.name }}
                    </button>
                  </div>
                </div>
                <p class="text-sm text-n-slate-11">
                  <span v-if="selectedTrigger.workflow">
                    {{ selectedTrigger.workflow.name }}
                  </span>
                  <span v-else>Sem fluxo vinculado</span>
                  <span v-if="savingDetails"> · Salvando…</span>
                </p>
              </div>
              <p v-if="detailError" class="text-xs text-n-ruby-11">
                {{ detailError }}
              </p>
            </div>
          </div>
          <button
            type="button"
            class="flex items-center justify-center rounded-lg size-8 text-n-slate-11 hover:bg-n-alpha-2"
            @click="closeDetails"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <div class="flex-1 min-h-0 overflow-y-auto px-6 py-5">
          <div class="grid gap-5 lg:grid-cols-2">
            <div class="flex flex-col gap-4">
              <section class="p-4 border rounded-2xl border-n-weak">
                <p
                  class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
                >
                  Endpoint
                </p>
                <div
                  class="flex items-center gap-2 mt-2 h-10 px-3 rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
                >
                  <span class="text-[0.625rem] font-bold text-n-amber-11">
                    POST
                  </span>
                  <span
                    class="flex-1 min-w-0 font-mono text-xs truncate text-n-slate-12"
                  >
                    {{ getWebhookUrl(selectedTrigger.token) }}
                  </span>
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12"
                    @click="copyUrl(getWebhookUrl(selectedTrigger.token))"
                  >
                    <span
                      class="size-4"
                      :class="
                        copiedToken === selectedTrigger.token
                          ? 'i-lucide-check'
                          : 'i-lucide-copy'
                      "
                    />
                  </button>
                </div>
                <p class="mt-2 text-xs text-n-slate-11">
                  Envie um JSON para este endereço. O fluxo usa o mapeamento
                  abaixo para achar o contato.
                </p>
              </section>

              <section class="p-4 border rounded-2xl border-n-weak">
                <div class="flex items-center justify-between gap-2">
                  <p
                    class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
                  >
                    Exemplo cURL
                  </p>
                  <button
                    type="button"
                    class="inline-flex items-center gap-1 text-xs font-medium text-n-slate-11 hover:text-n-slate-12"
                    @click="copyCurl"
                  >
                    <span
                      class="size-3.5"
                      :class="copiedCurl ? 'i-lucide-check' : 'i-lucide-copy'"
                    />
                    {{ copiedCurl ? 'Copiado' : 'Copiar' }}
                  </button>
                </div>
                <pre
                  class="mt-2 p-3 overflow-auto font-mono text-xs whitespace-pre-wrap break-all rounded-xl bg-n-alpha-1 text-n-slate-11 max-h-40"
                  >{{ curlText }}</pre
                >
              </section>

              <section class="p-4 border rounded-2xl border-n-weak">
                <p
                  class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
                >
                  Últimas requisições
                </p>
                <p
                  v-if="!selectedTrigger.recent_dispatches?.length"
                  class="mt-3 text-sm text-n-slate-11"
                >
                  Nenhum disparo registrado neste fluxo.
                </p>
                <ul v-else class="flex flex-col gap-2 mt-3">
                  <li
                    v-for="dispatch in selectedTrigger.recent_dispatches"
                    :key="dispatch.id"
                    class="p-3 rounded-xl bg-n-alpha-1"
                  >
                    <div class="flex items-center justify-between gap-2">
                      <span
                        class="text-xs font-medium"
                        :class="
                          dispatch.status === 'failed'
                            ? 'text-n-ruby-11'
                            : dispatch.status === 'completed'
                              ? 'text-n-teal-11'
                              : 'text-n-slate-12'
                        "
                      >
                        {{ dispatchStatusLabel(dispatch.status) }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ formatStamp(dispatch.created_at) }}
                      </span>
                    </div>
                    <p
                      v-if="dispatch.error_message"
                      class="mt-1 text-xs break-words text-n-ruby-11"
                    >
                      {{ dispatch.error_message }}
                    </p>
                    <button
                      v-if="dispatch.payload"
                      type="button"
                      class="mt-2 text-xs font-medium text-n-brand hover:underline"
                      @click="useDispatchPayload(dispatch)"
                    >
                      Usar este JSON no mapeamento
                    </button>
                  </li>
                </ul>
              </section>
            </div>

            <section class="p-4 border rounded-2xl border-n-weak">
              <div class="flex items-center justify-between gap-2">
                <p
                  class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
                >
                  Mapeamento
                </p>
                <button
                  v-if="selectedTrigger.payload_pinned"
                  type="button"
                  class="inline-flex items-center gap-1 text-xs font-medium text-n-amber-11"
                  @click="togglePinned"
                >
                  <span class="i-lucide-pin size-3" />
                  Exemplo fixado
                </button>
              </div>
              <p
                v-if="payloadFields.length"
                class="mt-2 mb-3 text-xs text-n-slate-11"
              >
                {{ payloadFields.length }} campos no exemplo atual.
              </p>
              <WebhookFieldMapping
                :mapping="selectedTrigger.field_mapping || {}"
                :fields="payloadFields"
                :payload="activePayload"
                :contact-attributes="contactAttributeOptions"
                :conversation-attributes="conversationAttributeOptions"
                @update-field="updateMappingField"
                @update-contact-rows="saveAttributeRows"
                @update-conversation-rows="saveConversationRows"
              />
              <p v-if="mappingError" class="mt-2 text-xs text-n-ruby-11">
                {{ mappingError }}
              </p>
            </section>
          </div>
        </div>

        <div
          class="flex flex-wrap items-center justify-between gap-2 px-6 py-4 border-t border-n-weak"
        >
          <div
            v-if="confirmingDelete"
            class="flex flex-wrap items-center gap-2"
          >
            <p class="text-sm text-n-slate-12">
              Excluir {{ selectedTrigger.name }}?
            </p>
            <button
              type="button"
              class="h-9 px-3 text-sm rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
              @click="confirmingDelete = false"
            >
              Cancelar
            </button>
            <button
              type="button"
              class="h-9 px-3 text-sm font-medium rounded-lg bg-n-ruby-9 text-white"
              @click="deleteTrigger(selectedTrigger.id)"
            >
              Excluir
            </button>
          </div>
          <template v-else>
            <button
              type="button"
              class="h-9 px-3 text-sm font-medium rounded-lg text-n-ruby-11 outline outline-1 outline-n-ruby-7 hover:bg-n-ruby-3"
              @click="confirmingDelete = true"
            >
              Excluir
            </button>
            <div class="flex flex-wrap gap-2">
              <button
                v-if="selectedTrigger.workflow"
                type="button"
                class="h-9 px-3 text-sm font-medium rounded-lg text-n-slate-12 outline outline-1 outline-n-weak hover:bg-n-alpha-2"
                @click="openWorkflow(selectedTrigger.workflow)"
              >
                Abrir fluxo
              </button>
              <button
                type="button"
                class="h-9 px-3 text-sm font-semibold rounded-lg bg-n-brand text-white"
                @click="openTestModal(selectedTrigger)"
              >
                Testar disparo
              </button>
            </div>
          </template>
        </div>
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
          <h2 class="text-base font-semibold text-n-slate-12">Novo webhook</h2>
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
