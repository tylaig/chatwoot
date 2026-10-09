<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  isSelected: {
    type: Boolean,
    default: false,
  },
  executionState: {
    type: String, // 'success', 'running', 'failed', 'waiting', null
    default: null,
  },
});

const emit = defineEmits(['select', 'addNext', 'delete']);

const nodeMeta = computed(() => {
  const type = props.node.type;
  switch (type) {
    case 'webhook_trigger':
      return {
        title: 'Webhook Trigger',
        icon: '⚡',
        badge: 'Trigger',
        badgeColor: 'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300',
        borderColor: 'border-amber-400',
      };
    case 'send_whatsapp_message':
      return {
        title: 'WhatsApp Mensagem',
        icon: '💬',
        badge: 'WhatsApp',
        badgeColor: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300',
        borderColor: 'border-emerald-500',
      };
    case 'send_whatsapp_template':
      return {
        title: 'WhatsApp Template',
        icon: '📄',
        badge: 'Meta Oficial',
        badgeColor: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300',
        borderColor: 'border-emerald-500',
      };
    case 'condition':
      return {
        title: 'Condição (IF / ELSE)',
        icon: '🔀',
        badge: 'Lógica',
        badgeColor: 'bg-purple-100 text-purple-700 dark:bg-purple-950 dark:text-purple-300',
        borderColor: 'border-purple-400',
      };
    case 'delay':
      return {
        title: 'Esperar (Delay)',
        icon: '⏱️',
        badge: 'Tempo',
        badgeColor: 'bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-300',
        borderColor: 'border-blue-400',
      };
    case 'wait_for_reply':
      return {
        title: 'Aguardar Resposta',
        icon: '⏳',
        badge: 'Interativo',
        badgeColor: 'bg-indigo-100 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300',
        borderColor: 'border-indigo-400',
      };
    case 'add_tag':
      return {
        title: 'Adicionar Tag',
        icon: '🏷️',
        badge: 'CRM',
        badgeColor: 'bg-orange-100 text-orange-700 dark:bg-orange-950 dark:text-orange-300',
        borderColor: 'border-orange-400',
      };
    case 'resolve_conversation':
      return {
        title: 'Resolver Conversa',
        icon: '✅',
        badge: 'Ação',
        badgeColor: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300',
        borderColor: 'border-slate-400',
      };
    default:
      return {
        title: props.node.config?.title || 'Nó de Ação',
        icon: '⚙️',
        badge: 'Geral',
        badgeColor: 'bg-slate-100 text-slate-700',
        borderColor: 'border-slate-300',
      };
  }
});

const summaryText = computed(() => {
  const cfg = props.node.config || {};
  switch (props.node.type) {
    case 'send_whatsapp_message':
      if (cfg.delivery_mode === 'outside_24h') {
        return `Template: ${cfg.template_name || 'Não selecionado'}`;
      }
      return cfg.text ? `"${cfg.text.slice(0, 32)}..."` : 'Configurar mensagem...';
    case 'condition':
      return cfg.conditions?.length
        ? `${cfg.conditions.length} regra(s) avaliada(s)`
        : 'Configurar condição...';
    case 'delay':
      return `Esperar ${cfg.duration || 1} ${cfg.unit || 'minutos'}`;
    case 'wait_for_reply':
      return `Até ${cfg.timeout_hours || 24}h para responder`;
    case 'add_tag':
      return cfg.tag_name ? `Tag: #${cfg.tag_name}` : 'Escolha uma tag';
    case 'webhook_trigger':
      return 'Disparado por Webhook externo';
    default:
      return cfg.description || 'Configurar nó';
  }
});
</script>

<template>
  <div
    class="relative w-64 rounded-2xl bg-white dark:bg-slate-800 border-2 shadow-lg transition-all cursor-pointer select-none group"
    :class="[
      isSelected ? 'ring-4 ring-primary-500/20 border-primary-500 scale-[1.02]' : 'hover:border-slate-400 dark:hover:border-slate-600',
      nodeMeta.borderColor,
      executionState === 'success' ? 'ring-2 ring-emerald-500 bg-emerald-50/20' : '',
      executionState === 'running' ? 'ring-2 ring-sky-500 animate-pulse' : '',
      executionState === 'failed' ? 'ring-2 ring-rose-500 bg-rose-50/20' : '',
      executionState === 'waiting' ? 'ring-2 ring-amber-500 bg-amber-50/20' : ''
    ]"
    @click.stop="emit('select', node)"
  >
    <!-- Handle de Entrada Superior (Input) -->
    <div
      v-if="node.type !== 'webhook_trigger'"
      class="absolute -top-2.5 left-1/2 -translate-x-1/2 w-5 h-5 rounded-full bg-white dark:bg-slate-900 border-2 border-slate-400 flex items-center justify-center shadow-sm"
    >
      <div class="w-1.5 h-1.5 rounded-full bg-slate-600 dark:bg-slate-300" />
    </div>

    <!-- Node Header -->
    <div class="p-3.5 border-b border-slate-100 dark:border-slate-700/60 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <span class="text-base">{{ nodeMeta.icon }}</span>
        <span class="text-xs font-bold text-slate-900 dark:text-white truncate max-w-[120px]">
          {{ node.config?.custom_title || nodeMeta.title }}
        </span>
      </div>

      <span class="text-[10px] font-semibold px-2 py-0.5 rounded-md" :class="nodeMeta.badgeColor">
        {{ nodeMeta.badge }}
      </span>
    </div>

    <!-- Node Body / Resumo de Configuração -->
    <div class="p-3 text-xs text-slate-600 dark:text-slate-300">
      <p class="truncate leading-relaxed">{{ summaryText }}</p>

      <!-- Badge de Execução em Debugger -->
      <div v-if="executionState" class="mt-2 flex items-center gap-1.5 text-[10px] font-semibold uppercase">
        <span v-if="executionState === 'success'" class="text-emerald-600">✓ Concluído</span>
        <span v-else-if="executionState === 'running'" class="text-sky-600">● Executando</span>
        <span v-else-if="executionState === 'failed'" class="text-rose-600">× Erro no nó</span>
        <span v-else-if="executionState === 'waiting'" class="text-amber-600">⏱️ Aguardando</span>
      </div>
    </div>

    <!-- Handle de Saída Inferior (Output) -->
    <div class="relative py-1 flex items-center justify-center">
      <!-- Condição possui 2 handles (SIM / NÃO) -->
      <div v-if="node.type === 'condition'" class="w-full flex items-center justify-around px-4 pb-2">
        <div class="flex flex-col items-center">
          <span class="text-[9px] font-bold text-emerald-600 mb-1">SIM</span>
          <div class="w-4 h-4 rounded-full bg-emerald-500 border-2 border-white shadow-sm flex items-center justify-center">
            <div class="w-1 h-1 rounded-full bg-white" />
          </div>
        </div>
        <div class="flex flex-col items-center">
          <span class="text-[9px] font-bold text-rose-500 mb-1">NÃO</span>
          <div class="w-4 h-4 rounded-full bg-rose-500 border-2 border-white shadow-sm flex items-center justify-center">
            <div class="w-1 h-1 rounded-full bg-white" />
          </div>
        </div>
      </div>

      <!-- Handle padrão único -->
      <div
        v-else
        class="absolute -bottom-2.5 left-1/2 -translate-x-1/2 w-5 h-5 rounded-full bg-white dark:bg-slate-900 border-2 border-slate-400 flex items-center justify-center shadow-sm hover:scale-125 transition-transform"
        @click.stop="emit('addNext', node)"
      >
        <span class="text-[10px] text-slate-600 dark:text-slate-300 font-bold">+</span>
      </div>
    </div>
  </div>
</template>
