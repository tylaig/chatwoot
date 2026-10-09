<script>
import WebhookDispatchApi from 'dashboard/api/webhookDispatchTriggers';

export default {
  name: 'WebhookDispatchTriggersIndex',
  data() {
    return {
      triggers: [],
      loading: true,
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
        template_name: '',
        template_language: 'pt_BR',
        inbox_id: 1,
        active: true,
        field_mapping: {
          phone_path: 'customer.phone',
          name_path: 'customer.name',
          parameters: [],
        },
      },
    };
  },
  mounted() {
    this.fetchTriggers();
  },
  methods: {
    async fetchTriggers() {
      this.loading = true;
      try {
        const response = await WebhookDispatchApi.getTriggers();
        this.triggers = response.data;
        if (this.triggers.length && !this.selectedTrigger) {
          this.selectedTrigger = this.triggers[0];
        }
      } catch (err) {
        console.error('Erro ao buscar gatilhos:', err);
      } finally {
        this.loading = false;
      }
    },
    getWebhookUrl(token) {
      const origin = window.location.origin;
      return `${origin}/public/api/v1/webhook_dispatches/${token}`;
    },
    copyUrl(url) {
      navigator.clipboard.writeText(url);
      this.copiedToken = url.split('/').pop();
      setTimeout(() => {
        this.copiedToken = null;
      }, 2000);
    },
    openModal(trigger = null) {
      if (trigger) {
        this.editingId = trigger.id;
        this.form = {
          name: trigger.name,
          template_name: trigger.template_name,
          template_language: trigger.template_language || 'pt_BR',
          inbox_id: trigger.inbox_id || 1,
          active: trigger.active !== false,
          field_mapping: trigger.field_mapping || {
            phone_path: 'customer.phone',
            name_path: 'customer.name',
            parameters: [],
          },
        };
      } else {
        this.editingId = null;
        this.form = {
          name: '',
          template_name: '',
          template_language: 'pt_BR',
          inbox_id: 1,
          active: true,
          field_mapping: {
            phone_path: 'customer.phone',
            name_path: 'customer.name',
            parameters: [],
          },
        };
      }
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
    },
    async saveTrigger() {
      if (!this.form.name || !this.form.template_name) return;
      try {
        if (this.editingId) {
          await WebhookDispatchApi.updateTrigger(this.editingId, this.form);
        } else {
          await WebhookDispatchApi.createTrigger(this.form);
        }
        this.closeModal();
        await this.fetchTriggers();
      } catch (err) {
        console.error('Erro ao salvar gatilho:', err);
      }
    },
    async deleteTrigger(id) {
      if (!confirm('Deseja realmente excluir este gatilho de webhook?')) return;
      try {
        await WebhookDispatchApi.deleteTrigger(id);
        await this.fetchTriggers();
      } catch (err) {
        console.error('Erro ao excluir:', err);
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
  <div class="flex h-full bg-[#0D1017] text-slate-100 overflow-hidden select-none">
    <!-- COLUNA ESQUERDA: LISTA DE WEBHOOK TRIGGERS -->
    <div class="flex-1 flex flex-col min-w-0 border-r border-slate-800">
      <!-- HEADER -->
      <header class="p-6 border-b border-slate-800 bg-[#14171F] flex items-center justify-between">
        <div>
          <h1 class="text-xl font-bold text-white tracking-tight">Webhooks (Gatilhos de Entrada)</h1>
          <p class="text-xs text-slate-400 mt-1">
            Endpoints HTTP externos para receber eventos (Shopify, Hotmart, n8n) e iniciar Workflows.
          </p>
        </div>

        <button
          type="button"
          class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center gap-1.5"
          @click="openModal()"
        >
          <span>+</span>
          <span>Novo Webhook</span>
        </button>
      </header>

      <!-- TABELA DE WEBHOOKS (ESTILO REFERENCE PACK) -->
      <div class="flex-1 overflow-y-auto p-6">
        <div class="border border-slate-800/80 rounded-2xl bg-[#14171F] overflow-hidden">
          <table class="w-full text-left border-collapse text-xs">
            <thead>
              <tr class="border-b border-slate-800/80 text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
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
                :class="selectedTrigger?.id === trigger.id ? 'bg-blue-600/10' : ''"
                @click="selectedTrigger = trigger"
              >
                <!-- NOME -->
                <td class="py-3.5 px-4 font-bold text-slate-100 flex items-center gap-3">
                  <div class="w-8 h-8 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center font-bold text-sm shrink-0">
                    ⚡
                  </div>
                  <div>
                    <p class="truncate">{{ trigger.name }}</p>
                    <p class="text-[10px] text-slate-400 font-mono">Template: {{ trigger.template_name }}</p>
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
                      {{ copiedToken === trigger.token ? '✓' : '📋' }}
                    </button>
                  </div>
                </td>

                <!-- WORKFLOW -->
                <td class="py-3.5 px-4 font-medium text-blue-400">
                  <span class="flex items-center gap-1.5">
                    <span>⚡</span>
                    <span>Webhook Inbound Flow</span>
                  </span>
                </td>

                <!-- STATUS -->
                <td class="py-3.5 px-4">
                  <span
                    class="px-2.5 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1.5 w-max"
                    :class="
                      trigger.active !== false
                        ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                        : 'bg-slate-800 text-slate-400'
                    "
                  >
                    <span
                      class="w-1.5 h-1.5 rounded-full"
                      :class="trigger.active !== false ? 'bg-emerald-400' : 'bg-slate-400'"
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
        <div class="flex items-center justify-between pb-4 border-b border-slate-800">
          <div class="flex items-center gap-3 min-w-0">
            <div class="w-9 h-9 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center font-bold text-lg">
              ⚡
            </div>
            <div class="min-w-0">
              <h3 class="text-sm font-bold text-white truncate">{{ selectedTrigger.name }}</h3>
              <p class="text-xs text-slate-400 font-mono">Token: {{ selectedTrigger.token }}</p>
            </div>
          </div>
        </div>

        <!-- ENDPOINT CURL COMPLETO -->
        <div class="space-y-2">
          <label class="block text-xs font-bold text-slate-300">Endpoint Externo (cURL)</label>
          <div class="p-3 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 font-mono text-[10px] text-slate-300">
            <p class="text-emerald-400 font-bold">curl -X POST \</p>
            <p class="break-all">{{ getWebhookUrl(selectedTrigger.token) }} \</p>
            <p class="text-slate-400">-H "Content-Type: application/json" \</p>
            <p class="text-slate-400">-d '{"customer": {"phone": "17991173157"}}'</p>
          </div>
        </div>

        <!-- MAPEAMENTO DE CAMPOS -->
        <div class="p-3.5 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 text-xs">
          <h4 class="font-bold text-slate-300">Mapeamento de Payload</h4>
          <div class="space-y-1 text-[11px] text-slate-400">
            <div class="flex justify-between">
              <span>Telefone do Contato:</span>
              <span class="font-mono text-slate-200">{{ selectedTrigger.field_mapping?.phone_path || 'customer.phone' }}</span>
            </div>
            <div class="flex justify-between">
              <span>Nome do Contato:</span>
              <span class="font-mono text-slate-200">{{ selectedTrigger.field_mapping?.name_path || 'customer.name' }}</span>
            </div>
          </div>
        </div>

        <!-- ÚLTIMAS REQUESTS RECEBIDAS -->
        <div class="space-y-2">
          <h4 class="text-xs font-bold text-slate-300">Últimas Requisições (Logs)</h4>
          <div class="p-3 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2">
            <div class="flex items-center justify-between text-[11px]">
              <span class="text-emerald-400 font-bold">✓ 200 OK</span>
              <span class="text-slate-500 font-mono text-[10px]">10 out 2026, 14:30:12</span>
            </div>
            <p class="text-[10px] font-mono text-slate-400 truncate">
              {"customer":{"phone":"17991173157","name":"Mestre"}}
            </p>
          </div>
        </div>
      </div>

      <!-- BOTÃO TESTAR OU EXCLUIR -->
      <div class="pt-4 border-t border-slate-800 flex items-center gap-2">
        <button
          type="button"
          class="flex-1 py-2 px-3 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold transition-colors"
          @click="openTestModal(selectedTrigger)"
        >
          Testar Disparo
        </button>
        <button
          type="button"
          class="py-2 px-3 rounded-xl border border-rose-500/30 text-rose-400 hover:bg-rose-500/10 text-xs font-semibold"
          @click="deleteTrigger(selectedTrigger.id)"
        >
          Excluir
        </button>
      </div>
    </div>
  </div>
</template>
