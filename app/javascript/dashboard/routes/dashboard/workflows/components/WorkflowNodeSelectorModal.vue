<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'select']);

const searchQuery = ref('');
const selectedCategory = ref('all');

const categories = [
  { id: 'all', name: 'Todos os Blocos' },
  { id: 'triggers', name: 'Triggers' },
  { id: 'whatsapp', name: 'WhatsApp' },
  { id: 'logic', name: 'Lógica' },
  { id: 'time', name: 'Tempo' },
  { id: 'chatwoot', name: 'CRM / Chatwoot' },
  { id: 'integration', name: 'Integrações' },
];

const availableNodes = [
  {
    type: 'send_whatsapp_message',
    category: 'whatsapp',
    title: 'Enviar Mensagem WhatsApp',
    description: 'Envia mensagem de texto ou template com verificação de janela de 24h',
    icon: '💬',
    badge: 'WhatsApp',
  },
  {
    type: 'condition',
    category: 'logic',
    title: 'Condição (IF / ELSE)',
    description: 'Bifurca o fluxo avaliando variáveis do contato, webhook ou contexto',
    icon: '🔀',
    badge: 'Lógica',
  },
  {
    type: 'router',
    category: 'logic',
    title: 'Router / Switch',
    description: 'Roteia para múltiplos caminhos baseado no valor de uma variável',
    icon: '🧭',
    badge: 'Lógica',
  },
  {
    type: 'delay',
    category: 'time',
    title: 'Esperar (Delay)',
    description: 'Pausa a execução por minutos, horas ou dias sem consumir threads',
    icon: '⏱️',
    badge: 'Tempo',
  },
  {
    type: 'wait_for_reply',
    category: 'time',
    title: 'Aguardar Resposta',
    description: 'Aguarda resposta do cliente no WhatsApp com timeout configurável',
    icon: '⏳',
    badge: 'Tempo',
  },
  {
    type: 'add_tag',
    category: 'chatwoot',
    title: 'Adicionar Tag',
    description: 'Insere uma etiqueta na conversa no Chatwoot',
    icon: '🏷️',
    badge: 'CRM',
  },
  {
    type: 'remove_tag',
    category: 'chatwoot',
    title: 'Remover Tag',
    description: 'Remove uma etiqueta existente da conversa',
    icon: '🔖',
    badge: 'CRM',
  },
  {
    type: 'resolve_conversation',
    category: 'chatwoot',
    title: 'Resolver Conversa',
    description: 'Marca a conversa atual como resolvida',
    icon: '✅',
    badge: 'CRM',
  },
  {
    type: 'add_private_note',
    category: 'chatwoot',
    title: 'Nota Privada',
    description: 'Adiciona uma nota interna na conversa visível apenas para agentes',
    icon: '📝',
    badge: 'CRM',
  },
  {
    type: 'http_request',
    category: 'integration',
    title: 'HTTP Request',
    description: 'Chama uma API externa via GET, POST, PUT com suporte a variáveis',
    icon: '🌐',
    badge: 'Integração',
  },
];

const filteredNodes = computed(() => {
  return availableNodes.filter((node) => {
    const matchCategory = selectedCategory.value === 'all' || node.category === selectedCategory.value;
    const matchQuery = !searchQuery.value ||
      node.title.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      node.description.toLowerCase().includes(searchQuery.value.toLowerCase());
    return matchCategory && matchQuery;
  });
});
</script>

<template>
  <div v-if="show" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm" @click.self="emit('close')">
    <div class="w-full max-w-xl bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 overflow-hidden flex flex-col max-h-[85vh]">
      <!-- Header -->
      <div class="p-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
        <h3 class="text-sm font-bold text-slate-900 dark:text-white">Adicionar Bloco de Automação</h3>
        <button type="button" class="text-slate-400 hover:text-slate-600 text-lg leading-none" @click="emit('close')">
          ✕
        </button>
      </div>

      <!-- Search & Categories Bar -->
      <div class="p-3 border-b border-slate-100 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 space-y-2">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Pesquisar ação, mensagem, delay..."
          class="w-full px-3 py-1.5 text-xs rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-800 dark:text-white"
          autofocus
        />

        <div class="flex items-center gap-1.5 overflow-x-auto pb-1">
          <button
            v-for="cat in categories"
            :key="cat.id"
            type="button"
            class="px-2.5 py-1 text-[11px] font-medium rounded-lg whitespace-nowrap transition-colors"
            :class="selectedCategory === cat.id ? 'bg-primary-500 text-white shadow-sm' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-100'"
            @click="selectedCategory = cat.id"
          >
            {{ cat.name }}
          </button>
        </div>
      </div>

      <!-- Node Grid -->
      <div class="p-4 overflow-y-auto grid grid-cols-1 md:grid-cols-2 gap-3 flex-1">
        <div
          v-for="n in filteredNodes"
          :key="n.type"
          class="p-3 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 hover:border-primary-500 hover:shadow-md cursor-pointer transition-all flex flex-col justify-between"
          @click="emit('select', n)"
        >
          <div class="flex items-start gap-2.5">
            <span class="text-xl p-2 rounded-xl bg-slate-100 dark:bg-slate-800">{{ n.icon }}</span>
            <div class="flex-1">
              <h4 class="text-xs font-bold text-slate-900 dark:text-white">{{ n.title }}</h4>
              <p class="text-[11px] text-slate-500 dark:text-slate-400 leading-tight mt-0.5">{{ n.description }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
