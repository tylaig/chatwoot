<template>
  <div class="flex-1 overflow-auto p-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
    <!-- Header -->
    <div class="flex items-center justify-between pb-6 border-b border-slate-200 dark:border-slate-800">
      <div>
        <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
          <span>🚀 Gatilhos de Webhook (Disparador WhatsApp)</span>
        </h1>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          Receba payloads JSON via POST e dispare templates HSM oficiais da Meta com mapeamento dinâmico.
        </p>
      </div>
      <button
        @click="openModal()"
        class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 text-white font-medium text-sm transition shadow-sm"
      >
        <span class="text-lg leading-none">+</span> Novo Gatilho
      </button>
    </div>

    <!-- Lista de Triggers -->
    <div class="mt-6">
      <div v-if="loading" class="text-center py-12 text-slate-500">
        Carregando gatilhos...
      </div>
      <div v-else-if="triggers.length === 0" class="text-center py-16 bg-white dark:bg-slate-800 rounded-xl border border-dashed border-slate-300 dark:border-slate-700 p-8">
        <div class="text-4xl mb-3">⚡</div>
        <h3 class="text-lg font-medium text-slate-900 dark:text-white">Nenhum gatilho de webhook configurado</h3>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1 max-w-md mx-auto">
          Crie seu primeiro endpoint para conectar Hotmart, Shopify, Kiwify, Bling ou qualquer checkout externo e disparar mensagens automáticas.
        </p>
        <button
          @click="openModal()"
          class="mt-4 px-4 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 text-white font-medium text-sm transition"
        >
          Criar Primeiro Gatilho
        </button>
      </div>

      <div v-else class="grid gap-4 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="trigger in triggers"
          :key="trigger.id"
          class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5 shadow-sm hover:shadow transition flex flex-col justify-between"
        >
          <div>
            <div class="flex items-start justify-between">
              <h2 class="font-semibold text-slate-900 dark:text-white text-base">
                {{ trigger.name }}
              </h2>
              <span
                class="px-2 py-0.5 text-xs font-semibold rounded-full"
                :class="trigger.active ? 'bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300' : 'bg-slate-100 text-slate-500'"
              >
                {{ trigger.active ? 'Ativo' : 'Pausado' }}
              </span>
            </div>

            <div class="mt-3 space-y-1.5 text-xs text-slate-600 dark:text-slate-400">
              <div>
                <strong class="text-slate-700 dark:text-slate-300">Template Meta:</strong>
                <span class="ml-1 font-mono text-orange-600 dark:text-orange-400">{{ trigger.template_name }}</span>
              </div>
              <div>
                <strong class="text-slate-700 dark:text-slate-300">Idioma:</strong>
                <span class="ml-1">{{ trigger.template_language }}</span>
              </div>
              <div>
                <strong class="text-slate-700 dark:text-slate-300">Caminho Telefone:</strong>
                <span class="ml-1 font-mono bg-slate-100 dark:bg-slate-700 px-1 py-0.5 rounded">{{ trigger.field_mapping?.phone_path || 'N/A' }}</span>
              </div>
            </div>

            <!-- URL do Webhook -->
            <div class="mt-4 bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-lg border border-slate-200 dark:border-slate-700/60">
              <div class="text-[11px] font-medium text-slate-500 uppercase tracking-wider mb-1">URL de Disparo (POST)</div>
              <div class="flex items-center justify-between gap-2">
                <input
                  type="text"
                  readonly
                  :value="getWebhookUrl(trigger.token)"
                  class="bg-transparent text-xs font-mono text-slate-800 dark:text-slate-200 w-full focus:outline-none select-all truncate"
                />
                <button
                  @click="copyUrl(getWebhookUrl(trigger.token))"
                  class="text-xs px-2 py-1 bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 rounded text-slate-700 dark:text-slate-200 transition shrink-0"
                >
                  {{ copiedToken === trigger.token ? 'Copiado!' : 'Copiar' }}
                </button>
              </div>
            </div>
          </div>

          <div class="mt-5 pt-3 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between text-xs">
            <button
              @click="testTriggerModal(trigger)"
              class="text-orange-600 dark:text-orange-400 hover:underline font-medium"
            >
              Testar Payload
            </button>
            <div class="flex gap-2">
              <button
                @click="openModal(trigger)"
                class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              >
                Editar
              </button>
              <button
                @click="deleteTrigger(trigger.id)"
                class="text-red-600 hover:text-red-700"
              >
                Excluir
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Criação / Edição -->
    <div
      v-if="showModal"
      class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
    >
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-xl max-w-xl w-full p-6 border border-slate-200 dark:border-slate-700 max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-bold text-slate-900 dark:text-white">
          {{ editingId ? 'Editar Gatilho' : 'Novo Gatilho de Webhook' }}
        </h3>
        
        <form @submit.prevent="saveTrigger" class="mt-4 space-y-4 text-sm">
          <div>
            <label class="block font-medium text-slate-700 dark:text-slate-300 mb-1">Nome Identificador</label>
            <input
              v-model="form.name"
              type="text"
              required
              placeholder="Ex: Disparo Kiwify - Compra Aprovada"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-orange-500 focus:outline-none"
            />
          </div>

          <div>
            <label class="block font-medium text-slate-700 dark:text-slate-300 mb-1">Nome do Template Meta (HSM)</label>
            <input
              v-model="form.template_name"
              type="text"
              required
              placeholder="Ex: atualizacao_pedido_gs_7420"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white font-mono focus:ring-2 focus:ring-orange-500 focus:outline-none"
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block font-medium text-slate-700 dark:text-slate-300 mb-1">Idioma Template</label>
              <input
                v-model="form.template_language"
                type="text"
                required
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white font-mono focus:ring-2 focus:ring-orange-500 focus:outline-none"
              />
            </div>
            <div>
              <label class="block font-medium text-slate-700 dark:text-slate-300 mb-1">Caixa de Entrada ID</label>
              <input
                v-model.number="form.inbox_id"
                type="number"
                required
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-orange-500 focus:outline-none"
              />
            </div>
          </div>

          <div class="border-t border-slate-200 dark:border-slate-700 pt-3">
            <h4 class="font-semibold text-slate-900 dark:text-white mb-2">Mapeamento De ➔ Para (Dot Notation)</h4>
            
            <div class="space-y-3">
              <div>
                <label class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1">Caminho do Telefone (JSON)</label>
                <input
                  v-model="form.field_mapping.phone_path"
                  type="text"
                  required
                  placeholder="Ex: customer.phone ou data.buyer.mobile"
                  class="w-full px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white font-mono text-xs focus:ring-2 focus:ring-orange-500 focus:outline-none"
                />
              </div>

              <div>
                <label class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1">Caminho do Nome do Cliente</label>
                <input
                  v-model="form.field_mapping.name_path"
                  type="text"
                  placeholder="Ex: customer.name ou data.buyer.name"
                  class="w-full px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white font-mono text-xs focus:ring-2 focus:ring-orange-500 focus:outline-none"
                />
              </div>

              <!-- Parâmetros do Template ({{1}}, {{2}}...) -->
              <div>
                <div class="flex items-center justify-between mb-1">
                  <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Variáveis do Template Body ({1}, {2}...)</label>
                  <button
                    type="button"
                    @click="addParameter()"
                    class="text-xs text-orange-600 hover:underline font-medium"
                  >
                    + Adicionar Variável
                  </button>
                </div>

                <div v-for="(param, idx) in form.field_mapping.parameters" :key="idx" class="flex gap-2 items-center mb-2">
                  <span class="text-xs font-mono text-slate-500">#{1 + idx}</span>
                  <select
                    v-model="param.type"
                    class="px-2 py-1 rounded border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-xs text-slate-800 dark:text-slate-200"
                  >
                    <option value="path">Caminho JSON</option>
                    <option value="static">Texto Fixo</option>
                  </select>
                  <input
                    v-model="param.value"
                    type="text"
                    :placeholder="param.type === 'path' ? 'Ex: order.amount' : 'Ex: Meu Super App'"
                    class="flex-1 px-2 py-1 rounded border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-xs font-mono text-slate-800 dark:text-slate-200"
                  />
                  <button
                    type="button"
                    @click="removeParameter(idx)"
                    class="text-red-500 hover:text-red-700 text-xs px-1"
                  >
                    ✕
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
            <button
              type="button"
              @click="showModal = false"
              class="px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              Cancelar
            </button>
            <button
              type="submit"
              class="px-4 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 text-white font-medium transition"
            >
              Salvar Gatilho
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Modal de Teste de Payload -->
    <div
      v-if="showTestModal"
      class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
    >
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-xl max-w-xl w-full p-6 border border-slate-200 dark:border-slate-700">
        <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
          Testar Simulação de Payload
        </h3>
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-4">
          Cole um exemplo de JSON que o seu checkout envia para validar se as variáveis e o telefone são extraídos com perfeição.
        </p>

        <textarea
          v-model="testPayloadText"
          rows="7"
          class="w-full p-3 font-mono text-xs rounded-lg border border-slate-300 dark:border-slate-600 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none"
        ></textarea>

        <div v-if="testResult" class="mt-4 p-3 rounded-lg border text-xs font-mono" :class="testResult.valid ? 'bg-green-50 border-green-200 text-green-900 dark:bg-green-950/40 dark:border-green-800 dark:text-green-300' : 'bg-red-50 border-red-200 text-red-900'">
          <div><strong>Telefone Detectado:</strong> {{ testResult.phone || 'NÃO ENCONTRADO!' }}</div>
          <div><strong>Nome do Contato:</strong> {{ testResult.name || 'Padrão (Cliente)' }}</div>
          <div><strong>Variáveis Resolvidas:</strong> {{ JSON.stringify(testResult.resolved_parameters) }}</div>
        </div>

        <div class="flex justify-end gap-3 mt-4">
          <button
            type="button"
            @click="showTestModal = false"
            class="px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-300"
          >
            Fechar
          </button>
          <button
            type="button"
            @click="runTestPayload()"
            class="px-4 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 text-white font-medium"
          >
            Executar Simulação
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import WebhookDispatchApi from '../../../api/webhookDispatchTriggers';

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
      testPayloadText: JSON.stringify({
        customer: {
          name: 'Mestre Samuel',
          phone: '17991173157',
          first_name: 'Samuel'
        },
        order: {
          total: 'R$ 150,00'
        }
      }, null, 2),
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
      } catch (err) {
        console.error('Erro ao buscar gatilhos:', err);
      } finally {
        this.loading = false;
      }
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
    openModal(trigger = null) {
      if (trigger) {
        this.editingId = trigger.id;
        this.form = {
          name: trigger.name,
          template_name: trigger.template_name,
          template_language: trigger.template_language,
          inbox_id: trigger.inbox_id,
          active: trigger.active,
          field_mapping: JSON.parse(JSON.stringify(trigger.field_mapping || { phone_path: '', name_path: '', parameters: [] })),
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
            parameters: [{ type: 'path', value: 'customer.first_name' }],
          },
        };
      }
      this.showModal = true;
    },
    addParameter() {
      this.form.field_mapping.parameters.push({ type: 'path', value: '' });
    },
    removeParameter(idx) {
      this.form.field_mapping.parameters.splice(idx, 1);
    },
    async saveTrigger() {
      try {
        if (this.editingId) {
          await WebhookDispatchApi.updateTrigger(this.editingId, this.form);
        } else {
          await WebhookDispatchApi.createTrigger(this.form);
        }
        this.showModal = false;
        await this.fetchTriggers();
      } catch (err) {
        alert('Erro ao salvar gatilho: ' + (err.response?.data?.error || err.message));
      }
    },
    async deleteTrigger(id) {
      if (!confirm('Deseja realmente excluir este gatilho de webhook?')) return;
      try {
        await WebhookDispatchApi.deleteTrigger(id);
        await this.fetchTriggers();
      } catch (err) {
        alert('Erro ao excluir gatilho');
      }
    },
    testTriggerModal(trigger) {
      this.activeTestTrigger = trigger;
      this.testResult = null;
      this.showTestModal = true;
    },
    async runTestPayload() {
      try {
        const payload = JSON.parse(this.testPayloadText);
        const res = await WebhookDispatchApi.testPayload(this.activeTestTrigger.id, payload);
        this.testResult = res.data;
      } catch (err) {
        alert('JSON inválido ou erro no teste: ' + err.message);
      }
    },
  },
};
</script>
