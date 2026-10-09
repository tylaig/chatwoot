<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';
import { getNodeDefinition } from '../nodeRegistry';

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  data: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['add-next']);

const nodeMeta = computed(() => getNodeDefinition(props.data.type));

const summary = computed(() => {
  return nodeMeta.value.summarize
    ? nodeMeta.value.summarize(props.data.config || {})
    : '';
});

// Renderização dinâmica de cor do badge semântico
const badgeColorClasses = computed(() => {
  switch (nodeMeta.value.badgeType) {
    case 'trigger':
      return 'bg-n-amber-3 text-n-amber-11 border border-n-amber-7';
    case 'condition':
      return 'bg-purple-500/10 text-purple-500 border border-purple-500/20';
    case 'time':
      return 'bg-indigo-500/10 text-indigo-500 border border-indigo-500/20';
    case 'integration':
      return 'bg-sky-500/10 text-sky-500 border border-sky-500/20';
    default:
      return 'bg-n-alpha-2 text-n-slate-11 border border-n-weak';
  }
});
</script>

<template>
  <div
    class="relative rounded-2xl bg-n-solid-1 border transition-all duration-150 shadow-lg group select-none min-w-[280px] max-w-[320px]"
    :class="[
      selected
        ? 'border-n-blue-9 ring-2 ring-n-blue-9/30'
        : 'border-n-weak hover:border-n-strong',
    ]"
  >
    <!-- HANDLE DE ENTRADA (INPUT) -->
    <Handle
      v-if="nodeMeta.hasInput !== false"
      type="target"
      :position="Position.Left"
      class="!w-3 !h-3 !bg-n-slate-9 !border-2 !border-n-solid-1 hover:!bg-n-blue-9 !transition-colors !-left-1.5"
    />

    <!-- CONTEÚDO DO CARD -->
    <div class="p-4 space-y-3">
      <!-- HEADER DO CARD -->
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2.5 min-w-0">
          <!-- Ícone oficial WhatsApp ou Genérico -->
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
            <h4 class="text-xs font-bold text-n-slate-12 truncate leading-tight">
              {{ data.config?.custom_title || nodeMeta.title }}
            </h4>
          </div>
        </div>

        <span
          class="text-[10px] px-2 py-0.5 rounded-full font-medium shrink-0"
          :class="badgeColorClasses"
        >
          {{ nodeMeta.badge }}
        </span>
      </div>

      <!-- SUBTÍTULO / DESCRIÇÃO -->
      <p class="text-[11px] text-n-slate-11 leading-relaxed">
        {{ nodeMeta.subtitle }}
      </p>

      <!-- RESUMO VISUAL DO BLOCO -->
      <div
        v-if="summary"
        class="p-2.5 rounded-xl bg-n-alpha-1 border border-n-weak font-mono text-[11px] text-n-slate-12 whitespace-pre-line leading-relaxed break-words"
      >
        {{ summary }}
      </div>
    </div>

    <!-- BOTÃO FLUTUANTE ADICIONAR PRÓXIMA AÇÃO (ESCONDIDO SE READ-ONLY) -->
    <button
      v-if="!data.readOnly && nodeMeta.outputs && nodeMeta.outputs.length === 1 && !nodeMeta.outputs[0].label"
      type="button"
      class="absolute -right-3 top-1/2 -translate-y-1/2 w-6 h-6 rounded-full bg-n-solid-2 border border-n-weak text-n-slate-12 hover:bg-n-blue-9 hover:text-white flex items-center justify-center text-xs font-bold transition-all shadow-md z-10"
      @click.stop="emit('add-next', { nodeId: id, handleId: 'output' })"
    >
      +
    </button>

    <!-- HANDLES DE SAÍDA COM BADGES ESTILIZADOS (CONDIÇÃO, ROTEADOR, WAIT FOR REPLY, HTTP) -->
    <template v-if="nodeMeta.outputs && nodeMeta.outputs.length">
      <!-- SAÍDAS COM LABELS (TRUE, FALSE, ROUTER, REPLIED, TIMEOUT, SUCCESS, ERROR) -->
      <div
        v-if="nodeMeta.outputs.some(o => o.label)"
        class="flex flex-col gap-2.5 absolute -right-3 top-1/2 -translate-y-1/2 z-10"
      >
        <div
          v-for="out in nodeMeta.outputs"
          :key="out.id"
          class="relative flex items-center"
        >
          <!-- Badge visual de Branch -->
          <span
            v-if="out.type === 'success' || out.label === 'TRUE'"
            class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-n-teal-3 text-n-teal-11 border border-n-teal-7 uppercase tracking-wider shadow-sm cursor-pointer hover:bg-n-teal-4 transition-colors"
          >
            {{ out.label }}
          </span>
          <span
            v-else-if="out.type === 'danger' || out.label === 'FALSE'"
            class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-7 uppercase tracking-wider shadow-sm cursor-pointer hover:bg-n-ruby-4 transition-colors"
          >
            {{ out.label }}
          </span>
          <span
            v-else
            class="text-[10px] font-bold px-2 py-0.5 rounded-full border shadow-sm cursor-pointer transition-colors"
            :style="{
              backgroundColor: `${out.color || '#3B82F6'}20`,
              color: out.color || '#3B82F6',
              borderColor: `${out.color || '#3B82F6'}40`,
            }"
          >
            {{ out.label }}
          </span>

          <Handle
            :id="out.id"
            type="source"
            :position="Position.Right"
            class="!w-2.5 !h-2.5 !bg-n-slate-9 !border-2 !border-n-solid-1 hover:!bg-n-blue-9 !transition-colors !-right-1.5"
          />
        </div>
      </div>

      <!-- SAÍDA SIMPLES PADRÃO -->
      <Handle
        v-else
        :id="nodeMeta.outputs[0].id"
        type="source"
        :position="Position.Right"
        class="!w-3 !h-3 !bg-n-slate-9 !border-2 !border-n-solid-1 hover:!bg-n-blue-9 !transition-colors !-right-1.5"
      />
    </template>
  </div>
</template>
