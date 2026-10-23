<script setup>
import {
  ref,
  computed,
  watch,
  nextTick,
  onMounted,
  onBeforeUnmount,
} from 'vue';
import {
  WORKFLOW_NODES_REGISTRY,
  NODE_CATEGORIES,
  CATEGORY_STYLES,
} from '../nodeRegistry';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  allowTriggers: {
    type: Boolean,
    default: false,
  },
  anchor: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'select']);

const PANEL_MARGIN = 8;

const searchQuery = ref('');
const selectedCategory = ref('all');
const searchInput = ref(null);
const panelRef = ref(null);
const position = ref({ x: 24, y: 80 });
const dragOffset = ref(null);

const clampPosition = (x, y) => {
  const panel = panelRef.value;
  const parent = panel?.offsetParent;
  if (!panel || !parent) return { x, y };

  const maxX = parent.clientWidth - panel.offsetWidth - PANEL_MARGIN;
  const maxY = parent.clientHeight - panel.offsetHeight - PANEL_MARGIN;
  return {
    x: Math.min(Math.max(PANEL_MARGIN, x), Math.max(PANEL_MARGIN, maxX)),
    y: Math.min(Math.max(PANEL_MARGIN, y), Math.max(PANEL_MARGIN, maxY)),
  };
};

const placePanel = () => {
  const panel = panelRef.value;
  const parent = panel?.offsetParent;
  if (!panel || !parent) return;

  const x = props.anchor
    ? props.anchor.x
    : parent.clientWidth - panel.offsetWidth - 24;
  const y = props.anchor ? props.anchor.y : 80;
  position.value = clampPosition(x, y);
};

const onPointerMove = event => {
  if (!dragOffset.value) return;
  const parentRect = panelRef.value?.offsetParent?.getBoundingClientRect();
  if (!parentRect) return;
  position.value = clampPosition(
    event.clientX - parentRect.left - dragOffset.value.x,
    event.clientY - parentRect.top - dragOffset.value.y
  );
};

const stopDragging = () => {
  dragOffset.value = null;
};

const startDragging = event => {
  if (event.button !== 0 || event.target.closest('button, input')) return;
  const parentRect = panelRef.value?.offsetParent?.getBoundingClientRect();
  if (!parentRect) return;
  dragOffset.value = {
    x: event.clientX - parentRect.left - position.value.x,
    y: event.clientY - parentRect.top - position.value.y,
  };
  event.currentTarget.setPointerCapture(event.pointerId);
};

const availableNodes = computed(() =>
  Object.values(WORKFLOW_NODES_REGISTRY).filter(
    node => props.allowTriggers || !node.isTrigger
  )
);

const categories = computed(() =>
  NODE_CATEGORIES.filter(
    cat =>
      cat.id === 'all' ||
      availableNodes.value.some(node => node.category === cat.id)
  )
);

const filteredNodes = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return availableNodes.value.filter(node => {
    const matchesCategory =
      selectedCategory.value === 'all' ||
      node.category === selectedCategory.value;
    const matchesSearch =
      !query ||
      node.title.toLowerCase().includes(query) ||
      node.subtitle.toLowerCase().includes(query);
    return matchesCategory && matchesSearch;
  });
});

watch(
  () => [props.show, props.anchor?.x, props.anchor?.y],
  () => {
    if (!props.show) return;
    searchQuery.value = '';
    nextTick(() => {
      placePanel();
      searchInput.value?.focus();
    });
  }
);

const keepInside = () => {
  if (!props.show) return;
  position.value = clampPosition(position.value.x, position.value.y);
};

onMounted(() => window.addEventListener('resize', keepInside));
onBeforeUnmount(() => window.removeEventListener('resize', keepInside));
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    v-if="show"
    ref="panelRef"
    class="msc-node-selector-modal absolute z-30 w-[26rem] h-[36rem] max-h-[calc(100%-1rem)] rounded-2xl bg-[#0A1319]/95 backdrop-blur-xl border border-emerald-500/30 shadow-2xl overflow-hidden flex flex-col text-white"
    :style="{ left: `${position.x}px`, top: `${position.y}px` }"
    @keydown.esc="emit('close')"
  >
    <div
      class="px-4 py-3 border-b border-white/[0.08] bg-gradient-to-r from-emerald-500/10 to-transparent flex items-center justify-between cursor-grab active:cursor-grabbing touch-none"
      @pointerdown="startDragging"
      @pointermove="onPointerMove"
      @pointerup="stopDragging"
      @pointercancel="stopDragging"
    >
      <div>
        <h3
          class="text-sm font-bold text-white flex items-center gap-1.5"
        >
          <span class="i-lucide-grip-horizontal size-4 text-emerald-400" />
          Adicionar bloco ao fluxo
        </h3>
        <p class="text-xs text-slate-400">Clique para inserir um passo no construtor</p>
      </div>
      <button
        type="button"
        class="flex items-center justify-center size-7 rounded-lg text-slate-400 hover:text-white hover:bg-white/10"
        title="Fechar"
        @click="emit('close')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <div class="p-3 border-b border-white/[0.08]">
      <div class="relative">
        <span
          class="i-lucide-search size-4 absolute start-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
        />
        <input
          ref="searchInput"
          v-model="searchQuery"
          type="text"
          placeholder="Buscar blocos…"
          class="msc-wf-search-input reset-base w-full h-9 ps-10 pe-3 text-sm rounded-xl bg-[#060C10] border border-white/10 focus:border-emerald-500/50 text-white placeholder:text-slate-500"
        />
      </div>
      <div class="flex flex-wrap gap-1.5 mt-3">
        <button
          v-for="cat in categories"
          :key="cat.id"
          type="button"
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold transition-all border"
          :class="
            selectedCategory === cat.id
              ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/45 shadow-sm'
              : 'bg-[#070E13] text-slate-400 border-white/10 hover:text-white hover:border-emerald-500/30'
          "
          @click="selectedCategory = cat.id"
        >
          <span class="size-3.5" :class="cat.icon" />
          {{ cat.name }}
        </button>
      </div>
    </div>

    <div class="flex-1 min-h-0 p-2 overflow-y-auto space-y-1.5">
      <button
        v-for="node in filteredNodes"
        :key="node.type"
        type="button"
        class="w-full p-2.5 rounded-xl bg-[#070E13]/80 border border-white/[0.06] hover:border-emerald-500/35 hover:bg-emerald-500/[0.06] transition-all flex items-center gap-3 text-start group"
        @click="emit('select', node)"
      >
        <div
          class="size-9 rounded-xl flex items-center justify-center shrink-0 border"
          :class="[
            CATEGORY_STYLES[node.category].soft,
            CATEGORY_STYLES[node.category].text,
          ]"
          :style="{
            borderColor: CATEGORY_STYLES[node.category].borderHex,
            boxShadow: `0 0 12px -3px ${CATEGORY_STYLES[node.category].glow}`,
          }"
        >
          <span class="size-5" :class="node.icon" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <h4 class="text-sm font-semibold text-white truncate">
              {{ node.title }}
            </h4>
            <span
              class="px-1.5 py-px rounded text-[10px] font-bold uppercase tracking-wider shrink-0"
              :class="CATEGORY_STYLES[node.category].badge"
            >
              {{ node.badge }}
            </span>
          </div>
          <p class="text-xs text-slate-400 truncate mt-0.5">
            {{ node.subtitle }}
          </p>
        </div>
        <span
          class="i-lucide-plus size-4 text-emerald-400 opacity-0 group-hover:opacity-100 transition-opacity"
        />
      </button>
      <p
        v-if="!filteredNodes.length"
        class="px-3 py-8 text-center text-sm text-slate-400"
      >
        Nenhum bloco encontrado.
      </p>
    </div>
  </div>
</template>
