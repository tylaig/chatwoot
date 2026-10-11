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
    class="relative w-72 rounded-2xl bg-n-solid-1 border shadow-lg transition-all duration-150 select-none"
    :class="[
      connectTarget
        ? 'border-n-brand ring-4 ring-n-brand/25 shadow-xl'
        : selected
          ? 'border-n-brand ring-4 ring-n-brand/15 shadow-xl'
          : isTestCurrent
            ? 'border-green-500 ring-4 ring-green-500/20 shadow-xl'
            : issues.length
              ? 'border-n-ruby-8'
              : ['border-n-weak', style.hoverBorder],
    ]"
  >
    <div class="h-1.5 rounded-t-2xl" :class="style.accent" />

    <Handle
      v-if="nodeMeta.hasInput !== false"
      type="target"
      :position="Position.Left"
      class="!size-3.5 !bg-n-solid-1 !border-2 !border-n-slate-8 hover:!border-n-brand !transition-colors !-left-[0.4375rem]"
    />

    <div class="px-4 pt-3 pb-4 space-y-3">
      <div class="flex items-start gap-3">
        <div
          class="size-9 rounded-xl flex items-center justify-center shrink-0"
          :class="[style.soft, style.text]"
        >
          <span class="size-5" :class="nodeMeta.icon" />
        </div>
        <div class="min-w-0 flex-1">
          <span
            class="inline-flex items-center px-1.5 py-px rounded-md text-[0.625rem] font-semibold uppercase tracking-wide"
            :class="style.badge"
          >
            {{ nodeMeta.badge }}
          </span>
          <h4 class="mt-1 text-sm font-semibold text-n-slate-12 truncate">
            {{ config.custom_title || nodeMeta.title }}
          </h4>
        </div>

        <div
          v-if="issues.length"
          class="shrink-0 pt-0.5"
          :title="issues.join('\n')"
        >
          <span class="i-lucide-circle-alert size-4 text-n-ruby-9" />
        </div>

        <OnClickOutside
          v-if="isEditable"
          class="relative shrink-0"
          @trigger="closeMenu"
        >
          <button
            type="button"
            class="nodrag nopan flex items-center justify-center size-7 rounded-lg text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            title="Opções do bloco"
            @click.stop="showMenu = !showMenu"
          >
            <span class="i-lucide-ellipsis size-4" />
          </button>
          <div
            v-if="showMenu"
            class="nodrag nopan absolute end-0 top-8 z-30 w-56 p-1 rounded-xl bg-n-solid-2 border border-n-weak shadow-xl"
            @click.stop
          >
            <template v-if="!confirmingDelete">
              <button
                type="button"
                class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-slate-12 hover:bg-n-alpha-2"
                @click="configureNode"
              >
                <span class="i-lucide-settings-2 size-4 text-n-slate-11" />
                Configurar
              </button>
              <button
                v-if="!nodeMeta.isTrigger"
                type="button"
                class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-slate-12 hover:bg-n-alpha-2"
                @click="duplicateNode"
              >
                <span class="i-lucide-copy size-4 text-n-slate-11" />
                Duplicar
              </button>
              <button
                v-if="!nodeMeta.isTrigger"
                type="button"
                class="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-sm text-n-ruby-11 hover:bg-n-ruby-9/10"
                @click="confirmingDelete = true"
              >
                <span class="i-lucide-trash-2 size-4" />
                Excluir bloco
              </button>
            </template>
            <div v-else class="p-2 space-y-2">
              <p class="text-sm font-semibold text-n-slate-12">
                Excluir este bloco?
              </p>
              <p class="text-xs text-n-slate-11">
                As conexões dele também serão removidas. Você pode desfazer com
                Ctrl+Z.
              </p>
              <div class="flex justify-end gap-2 pt-1">
                <button
                  type="button"
                  class="px-2.5 py-1.5 rounded-lg text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2"
                  @click="confirmingDelete = false"
                >
                  Cancelar
                </button>
                <button
                  type="button"
                  class="px-2.5 py-1.5 rounded-lg text-xs font-semibold text-white bg-n-ruby-9 hover:bg-n-ruby-10"
                  @click="deleteNode"
                >
                  Excluir
                </button>
              </div>
            </div>
          </div>
        </OnClickOutside>
      </div>

      <div
        v-if="data.type === 'condition'"
        class="p-2.5 rounded-xl bg-n-alpha-1 text-xs space-y-1.5"
      >
        <p v-if="!(config.conditions || []).length" class="text-n-slate-10">
          Configure as regras…
        </p>
        <template v-for="(cond, idx) in config.conditions || []" :key="idx">
          <p
            v-if="idx > 0"
            class="text-[0.625rem] font-bold uppercase text-violet-600 dark:text-violet-400"
          >
            {{ config.match_type === 'any' ? 'ou' : 'e' }}
          </p>
          <p class="font-mono text-n-slate-12 truncate flex items-center gap-1">
            <span
              class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
              >{ }</span
            >
            <span class="text-n-iris-11 truncate">{{ cond.field }}</span>
            <span class="mx-1 text-n-slate-10">{{
              OPERATOR_SYMBOLS[cond.operator] || cond.operator
            }}</span>
            <span class="font-semibold">{{ cond.value }}</span>
          </p>
        </template>
      </div>

      <div
        v-else-if="data.type === 'router'"
        class="p-2.5 rounded-xl bg-n-alpha-1 text-xs font-mono truncate flex items-center gap-1"
      >
        <span class="text-n-slate-10 me-1">Rotear por</span>
        <span
          class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
          >{ }</span
        >
        <span class="text-n-iris-11 truncate">{{
          config.source_variable || '—'
        }}</span>
      </div>

      <div
        v-else-if="data.type === 'http_request'"
        class="p-2.5 rounded-xl bg-n-alpha-1 text-xs flex items-center gap-2 min-w-0"
      >
        <span
          class="px-1.5 py-0.5 rounded-md text-[0.625rem] font-bold bg-n-iris-9/15 text-n-iris-11 shrink-0"
        >
          {{ config.method || 'POST' }}
        </span>
        <span class="font-mono text-n-slate-12 truncate">{{
          config.url || 'https://…'
        }}</span>
      </div>

      <p
        v-else-if="summary"
        class="p-2.5 rounded-xl bg-n-alpha-1 text-xs text-n-slate-12 whitespace-pre-line break-words line-clamp-3"
      >
        <template v-for="(segment, idx) in summarySegments" :key="idx">
          <span
            v-if="segment.type === 'variable'"
            class="inline-flex items-center gap-0.5 px-0.5 rounded font-mono text-[0.6875rem]"
            :class="
              segment.valid
                ? 'text-n-iris-11 bg-n-iris-3'
                : 'text-n-ruby-11 bg-n-ruby-3'
            "
          >
            <span class="font-mono text-sm font-bold leading-none">{ }</span>
            {{ segment.text }}
          </span>
          <template v-else>{{ segment.text }}</template>
        </template>
      </p>
      <p v-else class="text-xs text-n-slate-11">{{ nodeMeta.subtitle }}</p>

      <div
        v-if="data.type === 'send_message' && config.attachments?.length"
        class="flex flex-wrap gap-1"
      >
        <span
          v-for="file in config.attachments"
          :key="file.blob_id"
          class="inline-flex max-w-full items-center gap-1 rounded-md bg-n-alpha-2 px-1.5 py-1 text-[0.6875rem] text-n-slate-12"
        >
          <span
            class="size-3 shrink-0"
            :class="attachmentIcon(file.file_type)"
          />
          <span class="truncate">{{ file.filename }}</span>
        </span>
      </div>

      <div v-if="hasLabeledOutputs" class="space-y-1.5 pt-1">
        <div
          v-for="out in outputs"
          :key="out.id"
          class="relative flex items-center justify-end gap-2 h-7 ps-3 pe-3 -me-4 rounded-s-lg bg-n-alpha-1"
        >
          <span
            class="size-2 rounded-full"
            :style="{ backgroundColor: getOutputColor(out) }"
          />
          <span class="text-xs font-medium text-n-slate-12 truncate">{{
            out.label
          }}</span>
          <Handle
            :id="out.id"
            type="source"
            :position="Position.Right"
            class="!size-3.5 !bg-n-solid-1 !border-2 hover:!border-n-brand !transition-colors !-right-[0.4375rem]"
            :style="{ borderColor: getOutputColor(out) }"
          />
        </div>
      </div>
    </div>

    <template v-if="outputs.length && !hasLabeledOutputs">
      <Handle
        :id="outputs[0].id"
        type="source"
        :position="Position.Right"
        class="!size-3.5 !bg-n-solid-1 !border-2 !border-n-slate-8 hover:!border-n-brand !transition-colors !-right-[0.4375rem]"
      />
    </template>
  </div>
</template>
