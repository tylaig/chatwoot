<script setup>
import { ref, computed } from 'vue';
import { getNodeDefinition } from '../nodeRegistry';

const props = defineProps({
  node: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits([
  'updateConfig',
  'deleteNode',
  'close',
  'openTemplatePicker',
]);

const activeTab = ref('config'); // 'config' ou 'outputs'
const isTestingHttp = ref(false);
const httpTestResult = ref(null);
const isTestingWebhook = ref(false);
const webhookTestResult = ref(null);

const nodeMeta = computed(() => {
  if (!props.node) return null;
  return getNodeDefinition(props.node.type);
});

const updateField = (field, value) => {
  const updated = { ...props.node.config, [field]: value };
  emit('updateConfig', updated);
};

// Condition Helpers
const addConditionRule = () => {
  const current = [...(props.node.config?.conditions || [])];
  current.push({
    field: 'contact.custom_attributes.score',
    operator: 'greater_than',
    value: '50',
  });
  updateField('conditions', current);
};

const removeConditionRule = index => {
  const current = [...(props.node.config?.conditions || [])];
  current.splice(index, 1);
  updateField('conditions', current);
};

const updateConditionRule = (index, field, value) => {
  const current = [...(props.node.config?.conditions || [])];
  current[index] = { ...current[index], [field]: value };
  updateField('conditions', current);
};

// Router Helpers
const addRouterRoute = () => {
  const routes = [...(props.node.config?.routes || [])];
  const newIdx = routes.length + 1;
  routes.push({
    name: `Rota ${newIdx}`,
    operator: 'equal_to',
    value: `valor_${newIdx}`,
    color: '#3B82F6',
  });
  updateField('routes', routes);
};

const removeRouterRoute = index => {
  const routes = [...(props.node.config?.routes || [])];
  routes.splice(index, 1);
  updateField('routes', routes);
};

const updateRouterRoute = (index, field, value) => {
  const routes = [...(props.node.config?.routes || [])];
  routes[index] = { ...routes[index], [field]: value };
  updateField('routes', routes);
};

// Key-Value Pair Helpers (para Headers, Params de HTTP e Webhook)
const addKeyValue = (fieldName, defaultKey = '', defaultValue = '') => {
  const list = [...(props.node.config?.[fieldName] || [])];
  list.push({ key: defaultKey, value: defaultValue });
  updateField(fieldName, list);
};

const removeKeyValue = (fieldName, index) => {
  const list = [...(props.node.config?.[fieldName] || [])];
  list.splice(index, 1);
  updateField(fieldName, list);
};

const updateKeyValue = (fieldName, index, keyOrValue, val) => {
  const list = [...(props.node.config?.[fieldName] || [])];
  list[index] = { ...list[index], [keyOrValue]: val };
  updateField(fieldName, list);
};

// HTTP Request Test
const runHttpTest = async () => {
  isTestingHttp.value = true;
  httpTestResult.value = null;
  setTimeout(() => {
    isTestingHttp.value = false;
    httpTestResult.value = {
      status: 200,
      statusText: '200 OK',
      duration: '245 ms',
      data: {
        success: true,
        id: 'ORD-1234',
        status: 'created',
        timestamp: new Date().toISOString(),
      },
    };
  }, 600);
};

// Webhook Outbound Test
const runWebhookTest = async () => {
  isTestingWebhook.value = true;
  webhookTestResult.value = null;
  setTimeout(() => {
    isTestingWebhook.value = false;
    webhookTestResult.value = {
      status: 200,
      statusText: '200 OK - Disparo efetuado',
      duration: '182 ms',
      response: {
        received: true,
        event_id: 'evt_991823',
      },
    };
  }, 500);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline, vue/no-root-v-if -->
  <div
    v-if="node"
    class="w-96 border-l border-n-weak bg-n-solid-1 flex flex-col h-full overflow-hidden select-none z-20 shadow-2xl transition-colors duration-150"
  >
    <!-- HEADER DO PAINEL -->
    <div class="p-4 border-b border-n-weak flex items-center justify-between">
      <div class="flex items-center gap-2.5 min-w-0">
        <div
          v-if="nodeMeta.icon === 'whatsapp'"
          class="w-7 h-7 rounded-full bg-[#25D366] flex items-center justify-center shrink-0 shadow-sm"
        >
          <svg class="w-4 h-4 text-white fill-current" viewBox="0 0 24 24">
            <path
              d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"
            />
          </svg>
        </div>
        <div
          v-else
          class="w-7 h-7 rounded-lg flex items-center justify-center text-sm font-semibold shrink-0"
          :style="{
            backgroundColor: `${nodeMeta.iconColor || '#3B82F6'}1A`,
            color: nodeMeta.iconColor || '#3B82F6',
          }"
        >
          {{ nodeMeta.icon }}
        </div>
        <div class="truncate">
          <h3 class="text-xs font-bold text-n-slate-12 truncate">
            Configurar Bloco
          </h3>
          <p class="text-[10px] font-mono text-n-slate-11 truncate">
            {{ node.type }}
          </p>
        </div>
      </div>
      <button
        type="button"
        class="text-n-slate-9 hover:text-n-slate-12 text-xs p-1 rounded-lg"
        @click="emit('close')"
      >
        ✕
      </button>
    </div>

    <!-- TABS DE NAVEGAÇÃO DO PAINEL (CONDITION, ROUTER, HTTP, WAIT FOR REPLY) -->
    <div
      v-if="
        ['condition', 'router', 'http_request', 'wait_for_reply'].includes(
          node.type
        )
      "
      class="flex border-b border-n-weak text-xs px-5 pt-2 bg-n-alpha-1"
    >
      <button
        type="button"
        class="pb-2.5 px-3 font-semibold transition-colors"
        :class="
          activeTab === 'config'
            ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-500'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="activeTab = 'config'"
      >
        Configuração
      </button>
      <button
        type="button"
        class="pb-2.5 px-3 font-semibold transition-colors"
        :class="
          activeTab === 'outputs'
            ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-500'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="activeTab = 'outputs'"
      >
        Saídas (Handles)
      </button>
    </div>

    <!-- CORPO COM ROLAGEM -->
    <div class="flex-1 overflow-y-auto p-4 space-y-4">
      <!-- CAMPO GERAL: TÍTULO DO BLOCO -->
      <div>
        <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
          Título do Bloco
        </label>
        <input
          :value="node.config?.custom_title || nodeMeta.title"
          type="text"
          class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 placeholder-slate-400 focus:outline-none focus:border-blue-500"
          @input="updateField('custom_title', $event.target.value)"
        />
      </div>

      <!-- ============================================== -->
      <!-- 1. WEBHOOK TRIGGER                             -->
      <!-- ============================================== -->
      <template v-if="node.type === 'webhook_trigger'">
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Endpoint Inbound URL
          </label>
          <input
            :value="
              node.config?.endpoint ||
              '/public/api/v1/webhook_dispatches/default'
            "
            type="text"
            readonly
            class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
          />
        </div>
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Método HTTP
          </label>
          <input
            value="POST"
            disabled
            class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-9 font-mono"
          />
        </div>
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Token de Autenticação (Opcional)
          </label>
          <input
            :value="node.config?.trigger_token || ''"
            type="text"
            placeholder="wh_sec_..."
            class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
            @input="updateField('trigger_token', $event.target.value)"
          />
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 2. SEND MESSAGE                                -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'send_message'">
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Conteúdo da Mensagem
          </label>
          <textarea
            :value="node.config?.content || ''"
            rows="4"
            placeholder="Digite a mensagem para o cliente..."
            class="w-full p-2.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 leading-relaxed font-sans"
            @input="updateField('content', $event.target.value)"
          />
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-[10px] text-n-slate-11 mb-1"
              >Tipo de Mensagem</label
            >
            <select
              :value="node.config?.message_type || 'outgoing'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('message_type', $event.target.value)"
            >
              <option value="outgoing">Saída (Outgoing)</option>
              <option value="incoming">Entrada (Incoming)</option>
            </select>
          </div>
          <div class="flex items-center pt-4">
            <label
              class="flex items-center gap-2 text-xs text-n-slate-12 cursor-pointer"
            >
              <input
                type="checkbox"
                :checked="node.config?.private === true"
                class="rounded border-n-weak text-blue-600"
                @change="updateField('private', $event.target.checked)"
              />
              Nota Privada
            </label>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 3. SEND WHATSAPP MESSAGE (REQUISITO CRÍTICO)   -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'send_whatsapp_message'">
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            WhatsApp Inbox
          </label>
          <select
            :value="node.config?.inbox_id || '1'"
            class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
            @change="updateField('inbox_id', $event.target.value)"
          >
            <option value="1">
              🟢 WhatsApp Business - Suporte (+55 17 99117-3157)
            </option>
            <option value="2">🟢 WhatsApp Vendas (+55 17 99999-0000)</option>
          </select>
        </div>

        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Modo de Envio (Sending Mode)
          </label>
          <div class="space-y-1.5">
            <label
              class="flex items-center gap-2.5 p-2 rounded-xl border cursor-pointer text-xs transition-colors"
              :class="
                (node.config?.delivery_mode || 'auto') === 'auto'
                  ? 'border-blue-500 bg-blue-500/10 text-blue-600 dark:text-blue-400 font-semibold'
                  : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
              "
            >
              <input
                type="radio"
                name="whatsapp_delivery_mode"
                value="auto"
                :checked="(node.config?.delivery_mode || 'auto') === 'auto'"
                @change="updateField('delivery_mode', 'auto')"
              />
              <div>
                <span class="block">Automático (Detectar Janela 24h)</span>
                <span class="text-[10px] text-n-slate-9 font-normal"
                  >Texto se janela aberta; Template aprovado se fechada.</span
                >
              </div>
            </label>

            <label
              class="flex items-center gap-2.5 p-2 rounded-xl border cursor-pointer text-xs transition-colors"
              :class="
                node.config?.delivery_mode === 'inside_24h'
                  ? 'border-blue-500 bg-blue-500/10 text-blue-600 dark:text-blue-400 font-semibold'
                  : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
              "
            >
              <input
                type="radio"
                name="whatsapp_delivery_mode"
                value="inside_24h"
                :checked="node.config?.delivery_mode === 'inside_24h'"
                @change="updateField('delivery_mode', 'inside_24h')"
              />
              <div>
                <span class="block">Dentro da Janela 24h (Inside 24h)</span>
                <span class="text-[10px] text-n-slate-9 font-normal"
                  >Mensagem de texto livre. Permite fallback.</span
                >
              </div>
            </label>

            <label
              class="flex items-center gap-2.5 p-2 rounded-xl border cursor-pointer text-xs transition-colors"
              :class="
                node.config?.delivery_mode === 'outside_24h'
                  ? 'border-blue-500 bg-blue-500/10 text-blue-600 dark:text-blue-400 font-semibold'
                  : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
              "
            >
              <input
                type="radio"
                name="whatsapp_delivery_mode"
                value="outside_24h"
                :checked="node.config?.delivery_mode === 'outside_24h'"
                @change="updateField('delivery_mode', 'outside_24h')"
              />
              <div>
                <span class="block">Fora da Janela 24h (Outside 24h)</span>
                <span class="text-[10px] text-n-slate-9 font-normal"
                  >Template aprovado Meta obrigatório.</span
                >
              </div>
            </label>
          </div>
        </div>

        <!-- SE FOR AUTOMATIC OU INSIDE_24H: MOSTRA CAMPO DE TEXTO LIVRE -->
        <div v-if="node.config?.delivery_mode !== 'outside_24h'">
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            Mensagem de Texto Livre (Janela Aberta)
          </label>
          <textarea
            :value="
              node.config?.text ||
              'Olá {{contact.first_name}}! Como posso te ajudar hoje?'
            "
            rows="3"
            class="w-full p-2.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 leading-relaxed font-sans"
            placeholder="Olá {{contact.first_name}}!..."
            @input="updateField('text', $event.target.value)"
          />
        </div>

        <!-- SE FOR INSIDE_24H: FALLBACK SE A JANELA ESTIVER FECHADA -->
        <div
          v-if="node.config?.delivery_mode === 'inside_24h'"
          class="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 space-y-2"
        >
          <label class="block text-[11px] font-bold text-amber-500">
            Fallback se Janela Fechada
          </label>
          <select
            :value="node.config?.fallback_action || 'template'"
            class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12"
            @change="updateField('fallback_action', $event.target.value)"
          >
            <option value="template">Enviar Template Aprovado</option>
            <option value="window_closed">Marcar como Janela Fechada</option>
            <option value="fail">Falhar Execução</option>
          </select>
        </div>

        <!-- SE FOR AUTOMATIC OU OUTSIDE_24H (OU FALLBACK = TEMPLATE): SELETOR DE TEMPLATE -->
        <div
          v-if="
            node.config?.delivery_mode === 'outside_24h' ||
            node.config?.delivery_mode === 'auto' ||
            !node.config?.delivery_mode ||
            (node.config?.delivery_mode === 'inside_24h' &&
              node.config?.fallback_action === 'template')
          "
          class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2"
        >
          <div class="flex items-center justify-between">
            <label class="text-[11px] font-bold text-n-slate-12">
              Template Aprovado Meta
              {{
                node.config?.delivery_mode === 'auto'
                  ? '(Fallback Janela Fechada)'
                  : ''
              }}
            </label>
            <button
              type="button"
              class="text-[11px] text-blue-600 dark:text-blue-400 hover:underline font-semibold flex items-center gap-1"
              @click="emit('openTemplatePicker')"
            >
              📄 Selecionar
            </button>
          </div>
          <div
            class="px-3 py-2 text-xs rounded-xl bg-n-solid-1 border border-n-weak text-n-slate-12 flex items-center justify-between font-mono"
          >
            <span>{{
              node.config?.template_name || 'camp_eafc27_urgencia_02'
            }}</span>
            <span
              class="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-500 font-bold uppercase"
              >APPROVED</span
            >
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 4. SEND WHATSAPP TEMPLATE                      -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'send_whatsapp_template'">
        <div>
          <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
            WhatsApp Inbox
          </label>
          <select
            :value="node.config?.inbox_id || '1'"
            class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
            @change="updateField('inbox_id', $event.target.value)"
          >
            <option value="1">🟢 Suporte - WhatsApp</option>
          </select>
        </div>

        <div>
          <div class="flex items-center justify-between mb-1">
            <label class="text-[11px] font-bold text-n-slate-12">
              Template do WhatsApp
            </label>
            <button
              type="button"
              class="text-[11px] text-blue-600 dark:text-blue-400 hover:underline font-semibold flex items-center gap-1"
              @click="emit('openTemplatePicker')"
            >
              <span>📄</span> Selecionar Template
            </button>
          </div>
          <div
            class="px-3 py-2 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 flex items-center justify-between"
          >
            <span class="truncate font-mono">{{
              node.config?.template_name || 'camp_eafc27_urgencia_02'
            }}</span>
            <button
              type="button"
              class="text-n-slate-9 hover:text-n-slate-12 text-xs"
              @click="updateField('template_name', '')"
            >
              ✕
            </button>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-[10px] text-n-slate-11 mb-1">Idioma</label>
            <select
              :value="node.config?.template_language || 'pt_BR'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('template_language', $event.target.value)"
            >
              <option value="pt_BR">Português (Brasil) - pt_BR</option>
              <option value="en_US">Inglês - en_US</option>
            </select>
          </div>
          <div>
            <label class="block text-[10px] text-n-slate-11 mb-1"
              >Categoria</label
            >
            <select
              :value="node.config?.template_category || 'MARKETING'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('template_category', $event.target.value)"
            >
              <option value="MARKETING">Marketing</option>
              <option value="UTILITY">Utility</option>
              <option value="AUTHENTICATION">Authentication</option>
            </select>
          </div>
        </div>

        <!-- STATUS DO TEMPLATE CARD -->
        <div
          class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between"
        >
          <div class="flex items-center gap-2">
            <div
              class="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-500 flex items-center justify-center text-xs font-bold"
            >
              ✓
            </div>
            <div>
              <p class="text-xs font-bold text-n-slate-12">
                Status do Template
              </p>
              <p class="text-[10px] text-n-slate-11">
                Template aprovado e pronto para uso.
              </p>
            </div>
          </div>
          <span
            class="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-500 border border-emerald-500/30 font-bold"
          >
            Approved
          </span>
        </div>

        <!-- MAPEAMENTO DE VARIÁVEIS -->
        <div class="space-y-2">
          <label class="block text-[11px] font-bold text-n-slate-12">
            Mapeamento de Variáveis
          </label>
          <div
            class="p-2.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2"
          >
            <div class="flex items-center gap-2">
              <span class="text-xs font-mono text-n-slate-9 shrink-0"
                >&#123;&#123;1&#125;&#125;</span
              >
              <select
                class="flex-1 px-2.5 py-1.5 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12"
              >
                <option value="contact.name">
                  Nome do Contato (contact.name)
                </option>
                <option value="contact.first_name">
                  Primeiro Nome (contact.first_name)
                </option>
              </select>
            </div>
          </div>
        </div>

        <!-- PREVIEW DA MENSAGEM -->
        <div class="space-y-1.5">
          <label class="block text-[11px] font-bold text-n-slate-12">
            Preview da Mensagem
          </label>
          <div
            class="p-4 rounded-2xl bg-[#E1F8DC] dark:bg-[#1E2C22] border border-[#C5E8BF] dark:border-[#2D4533] text-slate-900 dark:text-slate-100 text-xs shadow-sm space-y-2 relative"
          >
            <p class="whitespace-pre-line leading-relaxed font-sans">
              Olá Samuel! 🔥 Últimas 24h para garantir seu EA SPORTS FC 27 com
              desconto exclusivo de lançamento!
            </p>
            <div class="text-[10px] text-n-slate-9 text-right">14:30</div>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 5. CONDITION (IF / ELSE RULE BUILDER)          -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'condition'">
        <div v-if="activeTab === 'config'" class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-[11px] font-bold text-n-slate-12">
              Regras de Condição
            </label>
            <div
              class="flex rounded-lg bg-n-alpha-1 p-0.5 border border-n-weak"
            >
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-semibold rounded"
                :class="
                  node.config?.match_type !== 'any'
                    ? 'bg-blue-600 text-white'
                    : 'text-n-slate-9'
                "
                @click="updateField('match_type', 'all')"
              >
                AND (Todas)
              </button>
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-semibold rounded"
                :class="
                  node.config?.match_type === 'any'
                    ? 'bg-blue-600 text-white'
                    : 'text-n-slate-9'
                "
                @click="updateField('match_type', 'any')"
              >
                OR (Qualquer)
              </button>
            </div>
          </div>

          <div
            v-for="(rule, idx) in node.config?.conditions || []"
            :key="idx"
            class="p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 relative"
          >
            <div class="flex items-center justify-between">
              <span class="text-[10px] font-mono text-n-slate-9"
                >Regra #{{ idx + 1 }}</span
              >
              <button
                v-if="(node.config?.conditions || []).length > 1"
                type="button"
                class="text-rose-500 hover:text-rose-400 text-xs"
                @click="removeConditionRule(idx)"
              >
                🗑️
              </button>
            </div>

            <div>
              <label class="block text-[10px] text-n-slate-9 mb-0.5"
                >Variável / Campo</label
              >
              <input
                :value="rule.field"
                type="text"
                class="w-full px-2.5 py-1 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12 font-mono"
                @input="updateConditionRule(idx, 'field', $event.target.value)"
              />
            </div>

            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-[10px] text-n-slate-9 mb-0.5"
                  >Operador</label
                >
                <select
                  :value="rule.operator"
                  class="w-full px-2 py-1 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12"
                  @change="
                    updateConditionRule(idx, 'operator', $event.target.value)
                  "
                >
                  <option value="equal_to">== (igual)</option>
                  <option value="not_equal_to">!= (diferente)</option>
                  <option value="contains">contém</option>
                  <option value="greater_than">&gt; (maior)</option>
                  <option value="less_than">&lt; (menor)</option>
                  <option value="is_empty">está vazio</option>
                </select>
              </div>
              <div>
                <label class="block text-[10px] text-n-slate-9 mb-0.5"
                  >Valor</label
                >
                <input
                  :value="rule.value"
                  type="text"
                  class="w-full px-2.5 py-1 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12"
                  @input="
                    updateConditionRule(idx, 'value', $event.target.value)
                  "
                />
              </div>
            </div>
          </div>

          <button
            type="button"
            class="text-[11px] text-blue-600 dark:text-blue-400 hover:underline font-semibold flex items-center gap-1"
            @click="addConditionRule"
          >
            <span>+</span> Adicionar Regra
          </button>
        </div>

        <div v-else class="space-y-3">
          <div
            class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-emerald-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-500" /> TRUE
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Quando a condição for verdadeira</span
            >
          </div>
          <div
            class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-rose-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-rose-500" /> FALSE
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Quando a condição for falsa</span
            >
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 6. ROUTER (MÚLTIPLAS ROTAS)                   -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'router'">
        <div v-if="activeTab === 'config'" class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Variável para Roteamento
            </label>
            <input
              :value="node.config?.source_variable || 'webhook.source'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('source_variable', $event.target.value)"
            />
          </div>

          <label class="block text-[11px] font-bold text-n-slate-12">
            Rotas Configuradas
          </label>
          <div
            v-for="(rt, idx) in node.config?.routes || []"
            :key="idx"
            class="p-2.5 rounded-xl bg-n-alpha-1 border border-n-weak space-y-2 relative"
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <span
                  class="w-2.5 h-2.5 rounded-full shrink-0"
                  :style="{ backgroundColor: rt.color || '#3B82F6' }"
                />
                <input
                  :value="rt.name"
                  type="text"
                  class="bg-transparent text-xs font-bold text-n-slate-12 focus:outline-none"
                  @input="updateRouterRoute(idx, 'name', $event.target.value)"
                />
              </div>
              <button
                type="button"
                class="text-rose-500 hover:text-rose-400 text-xs"
                @click="removeRouterRoute(idx)"
              >
                🗑️
              </button>
            </div>

            <div class="grid grid-cols-2 gap-2">
              <input
                value="é igual a"
                disabled
                class="px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-9"
              />
              <input
                :value="rt.value"
                type="text"
                placeholder="ex: instagram"
                class="px-2 py-1 text-xs rounded-lg bg-n-solid-1 border border-n-weak text-n-slate-12"
                @input="updateRouterRoute(idx, 'value', $event.target.value)"
              />
            </div>
          </div>

          <button
            type="button"
            class="text-[11px] text-blue-600 dark:text-blue-400 hover:underline font-semibold flex items-center gap-1"
            @click="addRouterRoute"
          >
            <span>+</span> Adicionar Rota
          </button>
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="(rt, idx) in node.config?.routes || [
              { name: 'Instagram', color: '#3B82F6' },
              { name: 'Google', color: '#10B981' },
              { name: 'Referral', color: '#F59E0B' },
            ]"
            :key="idx"
            class="p-3 rounded-xl border flex items-center justify-between"
            :style="{
              backgroundColor: `${rt.color || '#3B82F6'}10`,
              borderColor: `${rt.color || '#3B82F6'}30`,
            }"
          >
            <span
              class="text-xs font-bold flex items-center gap-2"
              :style="{ color: rt.color || '#3B82F6' }"
            >
              <span
                class="w-2.5 h-2.5 rounded-full"
                :style="{ backgroundColor: rt.color || '#3B82F6' }"
              />
              {{ rt.name }}
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Rota quando for {{ rt.value || rt.name.toLowerCase() }}</span
            >
          </div>

          <div
            class="p-3 rounded-xl bg-slate-500/10 border border-slate-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-slate-400 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-slate-400" /> Default
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Quando nenhuma rota anterior bater</span
            >
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 7. DELAY                                       -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'delay'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Duração da Pausa
            </label>
            <div class="grid grid-cols-2 gap-2">
              <input
                :value="node.config?.duration || 10"
                type="number"
                min="1"
                class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField('duration', parseInt($event.target.value) || 1)
                "
              />
              <select
                :value="node.config?.unit || 'minutes'"
                class="w-full px-2.5 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @change="updateField('unit', $event.target.value)"
              >
                <option value="seconds">Segundos</option>
                <option value="minutes">Minutos</option>
                <option value="hours">Horas</option>
                <option value="days">Dias</option>
              </select>
            </div>
          </div>
          <p class="text-[11px] text-n-slate-9">
            O fluxo é pausado pelo tempo configurado antes de prosseguir para a
            próxima ação.
          </p>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 8. WAIT UNTIL                                  -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'wait_until'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Modo de Espera
            </label>
            <select
              :value="node.config?.wait_mode || 'specific_time'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('wait_mode', $event.target.value)"
            >
              <option value="specific_time">Horário Fixo Específico</option>
              <option value="business_hours">Próximo Horário Comercial</option>
              <option value="variable_date">Data Vinda de Variável</option>
            </select>
          </div>

          <div
            v-if="
              (node.config?.wait_mode || 'specific_time') === 'specific_time'
            "
          >
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Horário Alvo</label
            >
            <input
              :value="node.config?.target_time || '09:00'"
              type="time"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('target_time', $event.target.value)"
            />
          </div>

          <div v-else-if="node.config?.wait_mode === 'variable_date'">
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Campo da Variável</label
            >
            <input
              :value="
                node.config?.variable_date_field || 'webhook.scheduled_at'
              "
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('variable_date_field', $event.target.value)"
            />
          </div>

          <div
            v-else-if="node.config?.wait_mode === 'business_hours'"
            class="grid grid-cols-2 gap-2"
          >
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Início</label
              >
              <input
                :value="node.config?.business_start || '08:00'"
                type="time"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="updateField('business_start', $event.target.value)"
              />
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1">Fim</label>
              <input
                :value="node.config?.business_end || '18:00'"
                type="time"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="updateField('business_end', $event.target.value)"
              />
            </div>
          </div>

          <div>
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Fuso Horário (Timezone)</label
            >
            <input
              :value="node.config?.timezone || 'America/Sao_Paulo'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('timezone', $event.target.value)"
            />
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 9. WAIT FOR REPLY                              -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'wait_for_reply'">
        <div v-if="activeTab === 'config'" class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Tempo Limite (Timeout)
            </label>
            <div class="flex items-center gap-2">
              <input
                :value="node.config?.timeout_hours || 24"
                type="number"
                min="1"
                class="w-24 px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField(
                    'timeout_hours',
                    parseInt($event.target.value) || 24
                  )
                "
              />
              <span class="text-xs text-n-slate-9">Horas</span>
            </div>
          </div>

          <div class="space-y-2 pt-2 border-t border-n-weak">
            <label class="block text-[11px] font-bold text-n-slate-12">
              Opções Avançadas
            </label>
            <label
              class="flex items-center gap-2 text-xs text-n-slate-12 cursor-pointer"
            >
              <input
                type="checkbox"
                :checked="node.config?.ignore_bot_messages !== false"
                class="rounded border-n-weak text-blue-600"
                @change="
                  updateField('ignore_bot_messages', $event.target.checked)
                "
              />
              Ignorar mensagens de bots
            </label>
            <label
              class="flex items-center gap-2 text-xs text-n-slate-12 cursor-pointer"
            >
              <input
                type="checkbox"
                :checked="node.config?.ignore_private_notes !== false"
                class="rounded border-n-weak text-blue-600"
                @change="
                  updateField('ignore_private_notes', $event.target.checked)
                "
              />
              Ignorar notas privadas internas
            </label>
          </div>
        </div>

        <div v-else class="space-y-3">
          <div
            class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-emerald-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-500" /> REPLIED
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Quando o cliente responde dentro do prazo</span
            >
          </div>
          <div
            class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-rose-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-rose-500" /> TIMEOUT
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Quando o tempo limite expira sem resposta</span
            >
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 10. SET VARIABLE                               -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'set_variable'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Nome da Variável
            </label>
            <input
              :value="node.config?.variable_name || 'lead_score'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('variable_name', $event.target.value)"
            />
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Tipo do Dado
            </label>
            <select
              :value="node.config?.variable_type || 'string'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('variable_type', $event.target.value)"
            >
              <option value="string">String (Texto)</option>
              <option value="number">Number (Número)</option>
              <option value="boolean">Boolean (Verdadeiro / Falso)</option>
              <option value="json">JSON / Objeto</option>
            </select>
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Valor
            </label>
            <input
              :value="node.config?.variable_value || ''"
              type="text"
              placeholder="ex: {{contact.name}} ou 100"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @input="updateField('variable_value', $event.target.value)"
            />
          </div>

          <div
            class="p-2 rounded-xl bg-n-alpha-1 border border-n-weak space-y-1"
          >
            <span class="text-[10px] text-n-slate-9 font-bold"
              >Variáveis Disponíveis:</span
            >
            <div class="flex flex-wrap gap-1">
              <span
                v-for="v in [
                  '{{contact.id}}',
                  '{{contact.name}}',
                  '{{webhook.order_id}}',
                  '{{conversation.id}}',
                ]"
                :key="v"
                class="px-1.5 py-0.5 rounded bg-n-alpha-2 text-[10px] font-mono text-n-slate-12 cursor-pointer hover:bg-blue-500 hover:text-white"
                @click="
                  updateField(
                    'variable_value',
                    (node.config?.variable_value || '') + v
                  )
                "
              >
                {{ v }}
              </span>
            </div>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 11. ADD TAG                                    -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'add_tag'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Nome da Tag
            </label>
            <input
              :value="node.config?.tag_name || 'cliente_vip'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('tag_name', $event.target.value)"
            />
          </div>

          <div>
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Tags Comuns</label
            >
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="t in [
                  'cliente_vip',
                  'lead_quente',
                  'fc27_compra',
                  'suporte_urgente',
                  'ativo',
                ]"
                :key="t"
                type="button"
                class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20 hover:bg-blue-500/20"
                @click="updateField('tag_name', t)"
              >
                {{ t }}
              </button>
            </div>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 12. REMOVE TAG                                 -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'remove_tag'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Tag a Remover
            </label>
            <input
              :value="node.config?.tag_name || 'lead_frio'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('tag_name', $event.target.value)"
            />
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 13. UPDATE CONTACT                             -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'update_contact'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Campo do Contato
            </label>
            <select
              :value="node.config?.field_name || 'name'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('field_name', $event.target.value)"
            >
              <option value="name">Nome (name)</option>
              <option value="email">E-mail (email)</option>
              <option value="phone_number">Telefone (phone_number)</option>
              <option value="identifier">Identificador Externo</option>
            </select>
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Novo Valor
            </label>
            <input
              :value="node.config?.field_value || '{{webhook.customer.name}}'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('field_value', $event.target.value)"
            />
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 14. UPDATE CUSTOM ATTRIBUTE                    -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'update_custom_attribute'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Chave do Atributo Customizado
            </label>
            <input
              :value="node.config?.attribute_key || 'cliente_ativo'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('attribute_key', $event.target.value)"
            />
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Valor
            </label>
            <input
              :value="node.config?.attribute_value || 'true'"
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @input="updateField('attribute_value', $event.target.value)"
            />
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 15. UPDATE CONVERSATION                        -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'update_conversation'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Prioridade da Conversa
            </label>
            <select
              :value="node.config?.priority || 'high'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('priority', $event.target.value)"
            >
              <option value="urgent">🔴 Urgente</option>
              <option value="high">🟠 Alta</option>
              <option value="medium">🟡 Média</option>
              <option value="low">🔵 Baixa</option>
            </select>
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Status da Conversa
            </label>
            <select
              :value="node.config?.status || 'open'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('status', $event.target.value)"
            >
              <option value="open">Aberto</option>
              <option value="resolved">Resolvido</option>
              <option value="pending">Pendente</option>
              <option value="snoozed">Adiado</option>
            </select>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 16. ASSIGN AGENT                               -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'assign_agent'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Atribuir ao Agente
            </label>
            <select
              :value="node.config?.agent_name || 'Samuel'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('agent_name', $event.target.value)"
            >
              <option value="Samuel">Samuel (Mestre - Admin)</option>
              <option value="Round-Robin">
                Atribuição Automática (Round-Robin)
              </option>
              <option value="Bot Atendimento">Bot IA Atendimento</option>
            </select>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 17. ASSIGN TEAM                                -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'assign_team'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Atribuir à Equipe / Time
            </label>
            <select
              :value="node.config?.team_name || 'Vendas'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('team_name', $event.target.value)"
            >
              <option value="Vendas">Equipe de Vendas</option>
              <option value="Suporte Técnico">Suporte Técnico N2</option>
              <option value="Financeiro">Financeiro / Cobrança</option>
              <option value="Onboarding">Onboarding / Novos Clientes</option>
            </select>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 18. ADD PRIVATE NOTE                           -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'add_private_note'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Texto da Nota Privada
            </label>
            <textarea
              :value="
                node.config?.note_text ||
                'Lead qualificado via fluxo automatizado.'
              "
              rows="4"
              class="w-full p-2.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-sans"
              @input="updateField('note_text', $event.target.value)"
            />
          </div>
          <p class="text-[11px] text-n-slate-9">
            Esta nota será adicionada apenas internamente à conversa (invisível
            para o cliente).
          </p>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 19. RESOLVE CONVERSATION                       -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'resolve_conversation'">
        <div
          class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 space-y-2"
        >
          <div class="flex items-center gap-2">
            <span class="text-base">✅</span>
            <span class="text-xs font-bold text-emerald-500"
              >Ação de Resolução</span
            >
          </div>
          <p class="text-xs text-n-slate-11">
            Ao atingir este bloco, a conversa atual será imediatamente marcada
            como <strong>Resolvida</strong>.
          </p>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 20. REOPEN CONVERSATION                        -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'reopen_conversation'">
        <div
          class="p-3 rounded-xl bg-blue-500/10 border border-blue-500/20 space-y-2"
        >
          <div class="flex items-center gap-2">
            <span class="text-base">🔄</span>
            <span class="text-xs font-bold text-blue-500"
              >Ação de Reabertura</span
            >
          </div>
          <p class="text-xs text-n-slate-11">
            Reabre a conversa para a caixa de entrada para atendimento imediato
            de um agente.
          </p>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 21. HTTP REQUEST (REQUISITO COMPLETO 15 PONTOS)-->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'http_request'">
        <div v-if="activeTab === 'config'" class="space-y-3">
          <!-- Method & URL -->
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Método</label
              >
              <select
                :value="node.config?.method || 'POST'"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 font-bold"
                @change="updateField('method', $event.target.value)"
              >
                <option value="GET">GET</option>
                <option value="POST">POST</option>
                <option value="PUT">PUT</option>
                <option value="PATCH">PATCH</option>
                <option value="DELETE">DELETE</option>
              </select>
            </div>
            <div class="col-span-2">
              <label class="block text-[10px] text-n-slate-9 mb-1">URL</label>
              <input
                :value="node.config?.url || 'https://api.exemplo.com/orders'"
                type="text"
                class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
                @input="updateField('url', $event.target.value)"
              />
            </div>
          </div>

          <!-- Query Params -->
          <div>
            <div class="flex items-center justify-between mb-1">
              <label class="text-[10px] font-bold text-n-slate-12"
                >Query Params</label
              >
              <button
                type="button"
                class="text-[10px] text-blue-500 font-semibold"
                @click="addKeyValue('params', 'param', 'value')"
              >
                + Adicionar Param
              </button>
            </div>
            <div class="space-y-1">
              <div
                v-for="(p, i) in node.config?.params || []"
                :key="i"
                class="flex items-center gap-1.5"
              >
                <input
                  :value="p.key"
                  placeholder="Key"
                  class="flex-1 px-2 py-1 text-xs rounded bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
                  @input="
                    updateKeyValue('params', i, 'key', $event.target.value)
                  "
                />
                <input
                  :value="p.value"
                  placeholder="Value"
                  class="flex-1 px-2 py-1 text-xs rounded bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
                  @input="
                    updateKeyValue('params', i, 'value', $event.target.value)
                  "
                />
                <button
                  type="button"
                  class="text-rose-500 text-xs px-1"
                  @click="removeKeyValue('params', i)"
                >
                  ✕
                </button>
              </div>
            </div>
          </div>

          <!-- Headers -->
          <div>
            <div class="flex items-center justify-between mb-1">
              <label class="text-[10px] font-bold text-n-slate-12"
                >Headers</label
              >
              <button
                type="button"
                class="text-[10px] text-blue-500 font-semibold"
                @click="addKeyValue('headers', 'Header-Name', 'value')"
              >
                + Adicionar Header
              </button>
            </div>
            <div class="space-y-1">
              <div
                v-for="(h, i) in node.config?.headers || []"
                :key="i"
                class="flex items-center gap-1.5"
              >
                <input
                  :value="h.key"
                  placeholder="Header"
                  class="flex-1 px-2 py-1 text-xs rounded bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
                  @input="
                    updateKeyValue('headers', i, 'key', $event.target.value)
                  "
                />
                <input
                  :value="h.value"
                  placeholder="Value"
                  class="flex-1 px-2 py-1 text-xs rounded bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
                  @input="
                    updateKeyValue('headers', i, 'value', $event.target.value)
                  "
                />
                <button
                  type="button"
                  class="text-rose-500 text-xs px-1"
                  @click="removeKeyValue('headers', i)"
                >
                  ✕
                </button>
              </div>
            </div>
          </div>

          <!-- Authentication -->
          <div>
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Autenticação</label
            >
            <select
              :value="node.config?.auth_type || 'bearer'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('auth_type', $event.target.value)"
            >
              <option value="none">Nenhuma (None)</option>
              <option value="bearer">Bearer Token</option>
              <option value="basic">Basic Auth</option>
              <option value="api_key">API Key Header</option>
            </select>

            <div v-if="node.config?.auth_type === 'bearer'" class="mt-1.5">
              <input
                :value="node.config?.auth_token || '**********'"
                type="password"
                placeholder="Bearer Token..."
                class="w-full px-2.5 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
                @input="updateField('auth_token', $event.target.value)"
              />
            </div>
          </div>

          <!-- Body JSON -->
          <div>
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Corpo da Requisição (Body JSON)</label
            >
            <textarea
              :value="node.config?.body || ''"
              rows="4"
              class="w-full p-2 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
              @input="updateField('body', $event.target.value)"
            />
          </div>

          <!-- Timeout, Retries & Store Response -->
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Timeout (s)</label
              >
              <input
                :value="node.config?.timeout || 30"
                type="number"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField('timeout', parseInt($event.target.value) || 30)
                "
              />
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Tentativas</label
              >
              <input
                :value="node.config?.retry_count || 3"
                type="number"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField('retry_count', parseInt($event.target.value) || 3)
                "
              />
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Intervalo (s)</label
              >
              <input
                :value="node.config?.retry_interval || 5"
                type="number"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField(
                    'retry_interval',
                    parseInt($event.target.value) || 5
                  )
                "
              />
            </div>
          </div>

          <div>
            <label class="block text-[10px] text-n-slate-9 mb-1"
              >Salvar Resposta Em (Store Response As)</label
            >
            <input
              :value="node.config?.save_response_as || 'workflow.http_response'"
              type="text"
              class="w-full px-2.5 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('save_response_as', $event.target.value)"
            />
          </div>

          <!-- BOTÃO TESTAR REQUISIÇÃO -->
          <div class="pt-2 border-t border-n-weak">
            <button
              type="button"
              class="w-full py-2 px-3 rounded-xl bg-blue-600/20 text-blue-600 dark:text-blue-400 border border-blue-500/30 text-xs font-bold hover:bg-blue-600/30 transition-all flex items-center justify-center gap-2"
              :disabled="isTestingHttp"
              @click="runHttpTest"
            >
              <span>▷</span>
              <span>{{
                isTestingHttp ? 'Executando Teste...' : 'Testar Requisição'
              }}</span>
            </button>

            <!-- RESPOSTA PREVIEW -->
            <div
              v-if="httpTestResult"
              class="mt-2 p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-1.5"
            >
              <div class="flex items-center justify-between text-[11px]">
                <span class="text-emerald-500 font-bold"
                  >✓ {{ httpTestResult.statusText }}</span
                >
                <span class="text-n-slate-9">{{
                  httpTestResult.duration
                }}</span>
              </div>
              <pre
                class="text-[10px] font-mono text-n-slate-12 overflow-x-auto p-2 bg-n-solid-1 rounded-lg"
                >{{ JSON.stringify(httpTestResult.data, null, 2) }}</pre
              >
            </div>
          </div>
        </div>

        <!-- TAB SAÍDAS HTTP -->
        <div v-else class="space-y-3">
          <div
            class="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-emerald-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-emerald-500" /> SUCCESS
              (2xx)
            </span>
            <span class="text-[11px] text-n-slate-9"
              >Requisição retornou sucesso</span
            >
          </div>
          <div
            class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-between"
          >
            <span
              class="text-xs font-bold text-rose-500 flex items-center gap-2"
            >
              <span class="w-2.5 h-2.5 rounded-full bg-rose-500" /> ERROR (4xx /
              5xx)
            </span>
            <span class="text-[11px] text-n-slate-9">Falha ou timeout</span>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 22. SEND WEBHOOK (OUTBOUND ESPECÍFICO)         -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'send_webhook'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              URL do Webhook Externo
            </label>
            <input
              :value="
                node.config?.url || 'https://n8n.meusuper.app/webhook/chatwoot'
              "
              type="text"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono"
              @input="updateField('url', $event.target.value)"
            />
          </div>

          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Método</label
              >
              <select
                :value="node.config?.method || 'POST'"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 font-bold"
                @change="updateField('method', $event.target.value)"
              >
                <option value="POST">POST</option>
                <option value="PUT">PUT</option>
              </select>
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-9 mb-1"
                >Tentativas de Retry</label
              >
              <input
                :value="node.config?.retry_count || 2"
                type="number"
                min="0"
                max="5"
                class="w-full px-2 py-1 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12"
                @input="
                  updateField('retry_count', parseInt($event.target.value) || 0)
                "
              />
            </div>
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Payload JSON Outbound
            </label>
            <textarea
              :value="node.config?.payload || '{}'"
              rows="4"
              class="w-full p-2.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 font-mono text-[11px]"
              @input="updateField('payload', $event.target.value)"
            />
          </div>

          <!-- BOTÃO TESTAR WEBHOOK -->
          <div>
            <button
              type="button"
              class="w-full py-2 px-3 rounded-xl bg-purple-600/20 text-purple-600 dark:text-purple-400 border border-purple-500/30 text-xs font-bold hover:bg-purple-600/30 transition-all flex items-center justify-center gap-2"
              :disabled="isTestingWebhook"
              @click="runWebhookTest"
            >
              <span>🚀</span>
              <span>{{
                isTestingWebhook
                  ? 'Disparando Webhook...'
                  : 'Testar Disparo Webhook'
              }}</span>
            </button>

            <div
              v-if="webhookTestResult"
              class="mt-2 p-3 rounded-xl bg-n-alpha-1 border border-n-weak space-y-1"
            >
              <div class="flex items-center justify-between text-[11px]">
                <span class="text-emerald-500 font-bold"
                  >✓ {{ webhookTestResult.statusText }}</span
                >
                <span class="text-n-slate-9">{{
                  webhookTestResult.duration
                }}</span>
              </div>
              <pre
                class="text-[10px] font-mono text-n-slate-12 overflow-x-auto p-2 bg-n-solid-1 rounded-lg"
                >{{ JSON.stringify(webhookTestResult.response, null, 2) }}</pre
              >
            </div>
          </div>
        </div>
      </template>

      <!-- ============================================== -->
      <!-- 23. END WORKFLOW                               -->
      <!-- ============================================== -->
      <template v-else-if="node.type === 'end_workflow'">
        <div class="space-y-3">
          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Status do Resultado Final
            </label>
            <select
              :value="node.config?.result_status || 'completed'"
              class="w-full px-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12"
              @change="updateField('result_status', $event.target.value)"
            >
              <option value="completed">
                Concluído com Sucesso (Completed)
              </option>
              <option value="converted">Lead Convertido (Converted)</option>
              <option value="stopped">Interrompido por Regra (Stopped)</option>
              <option value="custom">Personalizado (Custom)</option>
            </select>
          </div>

          <div>
            <label class="block text-[11px] font-bold text-n-slate-12 mb-1">
              Motivo do Encerramento (Opcional)
            </label>
            <textarea
              :value="node.config?.reason || ''"
              rows="3"
              placeholder="Descreva o motivo da finalização deste fluxo..."
              class="w-full p-2.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 text-xs"
              @input="updateField('reason', $event.target.value)"
            />
          </div>
        </div>
      </template>
    </div>

    <!-- FOOTER COM EXCLUIR BLOCO -->
    <div class="p-4 border-t border-n-weak bg-n-solid-1">
      <button
        v-if="node.type !== 'webhook_trigger'"
        type="button"
        class="w-full py-2 px-3 rounded-xl border border-rose-500/30 text-rose-500 text-xs font-semibold hover:bg-rose-500/10 transition-colors"
        @click="emit('deleteNode', node.id)"
      >
        Excluir Bloco
      </button>
    </div>
  </div>
  <div v-else />
</template>
