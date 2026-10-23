<script setup>
import { computed, inject, ref } from 'vue';
import { Handle, Position } from '@vue-flow/core';
import { OnClickOutside } from '@vueuse/components';
import {
  getNodeDefinition,
  getCategoryStyle,
  getNodeOutputs,
  getOutputColor,
} from '../nodeRegistry';
import { tokenizeTemplate } from '../variables';

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
  connectTarget: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['configure', 'duplicate', 'delete']);

const builder = inject('workflowBuilder', null);
const testNodeId = inject('workflowTestNodeId', ref(null));
const variableCatalog = inject('workflowVariables', null);

const nodeMeta = computed(() => getNodeDefinition(props.data.type));
const isTestCurrent = computed(() => testNodeId.value === props.id);
const style = computed(() => getCategoryStyle(props.data.type));
const config = computed(() => props.data.config || {});
const outputs = computed(() => getNodeOutputs(props.data.type, config.value));
const hasLabeledOutputs = computed(() => outputs.value.some(o => o.label));
const isEditable = computed(
  () => builder && !builder.readOnly && !props.data.readOnly
);
const issues = computed(() => builder?.issuesByNode.value.get(props.id) || []);
const summary = computed(() =>
  nodeMeta.value.summarize ? nodeMeta.value.summarize(config.value) : ''
);
const summarySegments = computed(() =>
  tokenizeTemplate(
    summary.value,
    variableCatalog ? variableCatalog.value.isValid : () => true
  )
);

const OPERATOR_SYMBOLS = {
  equal_to: '=',
  not_equal_to: '≠',
  contains: 'contém',
  greater_than: '>',
  less_than: '<',
  is_empty: 'vazio',
};

const attachmentIcon = type =>
  ({
    image: 'i-lucide-image',
    video: 'i-lucide-video',
    audio: 'i-lucide-mic',
    file: 'i-lucide-paperclip',
  })[type] || 'i-lucide-paperclip';

const showMenu = ref(false);
const confirmingDelete = ref(false);

const closeMenu = () => {
  showMenu.value = false;
  confirmingDelete.value = false;
};

const configureNode = () => {
  closeMenu();
  emit('configure', props.id);
};

const duplicateNode = () => {
  closeMenu();
  emit('duplicate', props.id);
};

const deleteNode = () => {
  closeMenu();
  emit('delete', props.id);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="msc-workflow-node relative w-72 rounded-2xl bg-[#0A1217]/95 backdrop-blur-md border transition-all duration-200 select-none"
    :class="[
      connectTarget
        ? 'border-emerald-400 ring-4 ring-emerald-500/30 shadow-2xl scale-[1.01]'
        : selected
          ? 'ring-2 shadow-2xl'
          : isTestCurrent
            ? 'border-emerald-400 ring-4 ring-emerald-500/25 shadow-2xl'
            : issues.length
              ? 'border-rose-500/80'
              : [style.border, style.hoverBorder],
    ]"
    :style="{
      borderColor:
        connectTarget || isTestCurrent
          ? '#10B981'
          : issues.length
            ? '#F43F5E'
            : selected
              ? style.hex
              : style.borderHex,
      boxShadow: selected
        ? `0 18px 40px -10px rgba(0, 0, 0, 0.8), 0 0 28px -4px ${style.glow}, 0 0 0 2px ${style.hex}`
        : `0 14px 32px -8px rgba(0, 0, 0, 0.72), 0 0 22px -6px ${style.glow}, inset 0 1px 0 rgba(255, 255, 255, 0.07)`,
    }"
  >
    <!-- Top Luminous Category Accent Strip -->
    <div
      class="h-1.5 rounded-t-2xl"
      :style="{
        background: `linear-gradient(90deg, ${style.hex} 0%, ${style.borderHex} 100%)`,
        boxShadow: `0 2px 12px ${style.glow}`,
      }"
    />

    <Handle
      v-if="nodeMeta.hasInput !== false"
      id="input"
      type="target"
      :position="Position.Left"
      class="!size-3.5 !bg-[#081015] !border-2 hover:!scale-125 !transition-all !-left-[0.4375rem]"
      :style="{
        borderColor: style.hex,
        boxShadow: `0 0 10px ${style.glow}`,
      }"
    />

    <!-- Node Header Banner with Tinted Category Gradient -->
    <div
      class="px-4 py-3 border-b border-white/[0.06] flex items-start gap-3"
      :style="{ background: style.headerBg }"
    >
      <div
        class="size-9 rounded-xl flex items-center justify-center shrink-0 border"
        :class="[style.soft, style.text]"
        :style="{
          borderColor: style.borderHex,
          boxShadow: `0 0 14px -2px ${style.glow}`,
        }"
      >
        <span class="size-5" :class="nodeMeta.icon" />
      </div>
      <div class="min-w-0 flex-1">
        <span
          class="inline-flex items-center px-1.5 py-0.5 rounded-md text-[0.625rem] font-bold uppercase tracking-wider"
          :class="style.badge"
        >
          {{ nodeMeta.badge }}
        </span>
        <h4 class="mt-1 text-sm font-semibold text-white truncate">
          {{ config.custom_title || nodeMeta.title }}
        </h4>
      </div>

      <div
        v-if="issues.length"
        class="shrink-0 pt-0.5"
        :title="issues.join('\n')"
      >
        <span class="i-lucide-circle-alert size-4 text-rose-400" />
      </div>

      <OnClickOutside
        v-if="isEditable"
        class="relative shrink-0"
        @trigger="closeMenu"
      >
        <button
          type="button"
          class="nodrag nopan flex items-center justify-center size-7 rounded-lg text-slate-400 hover:text-white hover:bg-white/10 transition-colors"
          title="Opções do bloco"
          @click.stop="showMenu = !showMenu"
        >
          <span class="i-lucide-ellipsis-vertical size-4" />
        </button>
        <div
          v-if="showMenu"
          class="nodrag nopan absolute end-0 top-8 z-30 w-56 p-1.5 rounded-xl bg-[#0D171E] border border-emerald-500/25 shadow-2xl"
          @click.stop
        >
          <template v-if="!confirmingDelete">
            <button
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-slate-100 hover:bg-white/[0.06]"
              @click="configureNode"
            >
              <span class="i-lucide-settings-2 size-4 text-emerald-400" />
              Configurar
            </button>
            <button
              v-if="!nodeMeta.isTrigger"
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-slate-100 hover:bg-white/[0.06]"
              @click="duplicateNode"
            >
              <span class="i-lucide-copy size-4 text-cyan-400" />
              Duplicar
            </button>
            <button
              v-if="!nodeMeta.isTrigger"
              type="button"
              class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-rose-400 hover:bg-rose-500/15"
              @click="confirmingDelete = true"
            >
              <span class="i-lucide-trash-2 size-4" />
              Excluir bloco
            </button>
          </template>
          <div v-else class="p-2 space-y-2">
            <p class="text-sm font-semibold text-white">
              Excluir este bloco?
            </p>
            <p class="text-xs text-slate-400">
              As conexões dele também serão removidas. Você pode desfazer com
              Ctrl+Z.
            </p>
            <div class="flex justify-end gap-2 pt-1">
              <button
                type="button"
                class="px-2.5 py-1.5 rounded-lg text-xs font-medium text-slate-200 hover:bg-white/10"
                @click="confirmingDelete = false"
              >
                Cancelar
              </button>
              <button
                type="button"
                class="px-2.5 py-1.5 rounded-lg text-xs font-semibold text-white bg-rose-600 hover:bg-rose-500"
                @click="deleteNode"
              >
                Excluir
              </button>
            </div>
          </div>
        </div>
      </OnClickOutside>
    </div>

    <!-- Node Body Content -->
    <div class="px-4 py-3.5 space-y-3">
      <div
        v-if="data.type === 'condition'"
        class="p-2.5 rounded-xl bg-[#070D11]/90 border border-white/[0.07] text-xs space-y-1.5"
      >
        <p v-if="!(config.conditions || []).length" class="text-slate-400">
          Configure as regras…
        </p>
        <template v-for="(cond, idx) in config.conditions || []" :key="idx">
          <p
            v-if="idx > 0"
            class="text-[0.625rem] font-bold uppercase text-rose-400"
          >
            {{ config.match_type === 'any' ? 'ou' : 'e' }}
          </p>
          <p class="font-mono text-slate-100 truncate flex items-center gap-1">
            <span
              class="font-mono text-sm font-bold leading-none text-amber-400 shrink-0"
              >{ }</span
            >
            <span class="text-emerald-300 truncate">{{ cond.field }}</span>
            <span class="mx-1 text-slate-400">{{
              OPERATOR_SYMBOLS[cond.operator] || cond.operator
            }}</span>
            <span class="font-semibold text-white">{{ cond.value }}</span>
          </p>
        </template>
      </div>

      <div
        v-else-if="data.type === 'router'"
        class="p-2.5 rounded-xl bg-[#070D11]/90 border border-white/[0.07] text-xs font-mono truncate flex items-center gap-1"
      >
        <span class="text-slate-400 me-1">Rotear por</span>
        <span
          class="font-mono text-sm font-bold leading-none text-amber-400 shrink-0"
          >{ }</span
        >
        <span class="text-emerald-300 truncate">{{
          config.source_variable || '—'
        }}</span>
      </div>

      <div
        v-else-if="data.type === 'http_request'"
        class="p-2.5 rounded-xl bg-[#070D11]/90 border border-white/[0.07] text-xs flex items-center gap-2 min-w-0"
      >
        <span
          class="px-1.5 py-0.5 rounded-md text-[0.625rem] font-bold bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 shrink-0"
        >
          {{ config.method || 'POST' }}
        </span>
        <span class="font-mono text-slate-200 truncate">{{
          config.url || 'https://…'
        }}</span>
      </div>

      <p
        v-else-if="summary"
        class="p-2.5 rounded-xl bg-[#070D11]/90 border border-white/[0.07] text-xs text-slate-200 whitespace-pre-line break-words line-clamp-3"
      >
        <template v-for="(segment, idx) in summarySegments" :key="idx">
          <span
            v-if="segment.type === 'variable'"
            class="inline-flex items-center gap-0.5 px-1 py-0.5 rounded font-mono text-[0.6875rem]"
            :class="
              segment.valid
                ? 'text-emerald-300 bg-emerald-500/15 border border-emerald-500/30'
                : 'text-rose-300 bg-rose-500/15 border border-rose-500/30'
            "
          >
            <span class="font-mono text-xs font-bold leading-none">{ }</span>
            {{ segment.text }}
          </span>
          <template v-else>{{ segment.text }}</template>
        </template>
      </p>
      <p v-else class="text-xs text-slate-300 leading-relaxed">
        {{ nodeMeta.subtitle }}
      </p>

      <div
        v-if="data.type === 'send_message' && config.attachments?.length"
        class="flex flex-wrap gap-1"
      >
        <span
          v-for="file in config.attachments"
          :key="file.blob_id"
          class="inline-flex max-w-full items-center gap-1 rounded-md bg-white/[0.06] border border-white/10 px-1.5 py-1 text-[0.6875rem] text-slate-200"
        >
          <span
            class="size-3 shrink-0 text-cyan-400"
            :class="attachmentIcon(file.file_type)"
          />
          <span class="truncate">{{ file.filename }}</span>
        </span>
      </div>

      <div v-if="hasLabeledOutputs" class="space-y-1.5 pt-1">
        <div
          v-for="out in outputs"
          :key="out.id"
          class="relative flex items-center justify-end gap-2 h-7 ps-3 pe-3 -me-4 rounded-s-lg bg-[#070D11]/90 border border-e-0 border-white/[0.07]"
        >
          <span
            class="size-2 rounded-full"
            :style="{
              backgroundColor: getOutputColor(out),
              boxShadow: `0 0 8px ${getOutputColor(out)}`,
            }"
          />
          <span class="text-xs font-medium text-slate-200 truncate">{{
            out.label
          }}</span>
          <Handle
            :id="out.id"
            type="source"
            :position="Position.Right"
            class="!size-3.5 !bg-[#081015] !border-2 hover:!scale-125 !transition-all !-right-[0.4375rem]"
            :style="{
              borderColor: getOutputColor(out),
              boxShadow: `0 0 10px ${getOutputColor(out)}`,
            }"
          />
        </div>
      </div>
    </div>

    <template v-if="outputs.length && !hasLabeledOutputs">
      <Handle
        :id="outputs[0].id"
        type="source"
        :position="Position.Right"
        class="!size-3.5 !bg-[#081015] !border-2 hover:!scale-125 !transition-all !-right-[0.4375rem]"
        :style="{
          borderColor: style.hex,
          boxShadow: `0 0 10px ${style.glow}`,
        }"
      />
    </template>
  </div>
</template>
