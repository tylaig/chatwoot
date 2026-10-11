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
    class="absolute z-30 w-[26rem] h-[36rem] max-h-[calc(100%-1rem)] rounded-2xl bg-n-solid-1 border border-n-weak shadow-2xl overflow-hidden flex flex-col text-n-slate-12"
    :style="{ left: `${position.x}px`, top: `${position.y}px` }"
    @keydown.esc="emit('close')"
  >
    <div
      class="px-4 py-3 border-b border-n-weak flex items-center justify-between cursor-grab active:cursor-grabbing touch-none"
      @pointerdown="startDragging"
      @pointermove="onPointerMove"
      @pointerup="stopDragging"
      @pointercancel="stopDragging"
    >
      <div>
        <h3
          class="text-sm font-semibold text-n-slate-12 flex items-center gap-1.5"
        >
          <span class="i-lucide-grip-horizontal size-4 text-n-slate-9" />
          Adicionar bloco
        </h3>
        <p class="text-xs text-n-slate-11">Clique para inserir no fluxo</p>
      </div>
      <button
        type="button"
        class="flex items-center justify-center size-7 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
        title="Fechar"
        @click="emit('close')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <div class="p-3 border-b border-n-weak">
      <div class="relative">
        <span
          class="i-lucide-search size-4 absolute start-3 top-1/2 -translate-y-1/2 text-n-slate-10"
        />
        <input
          ref="searchInput"
          v-model="searchQuery"
          type="text"
          placeholder="Buscar blocos…"
          class="reset-base w-full h-9 ps-9 pe-3 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
        />
      </div>
      <div class="flex flex-wrap gap-1.5 mt-3">
        <button
          v-for="cat in categories"
          :key="cat.id"
          type="button"
          class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium transition-colors"
          :class="
            selectedCategory === cat.id
              ? 'bg-n-brand text-white'
              : 'bg-n-alpha-1 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2'
          "
          @click="selectedCategory = cat.id"
        >
          <span class="size-3.5" :class="cat.icon" />
          {{ cat.name }}
        </button>
      </div>
    </div>

    <div class="flex-1 min-h-0 p-2 overflow-y-auto space-y-1">
      <button
        v-for="node in filteredNodes"
        :key="node.type"
        type="button"
        class="w-full p-2.5 rounded-xl hover:bg-n-alpha-2 transition-colors flex items-center gap-3 text-start group"
        @click="emit('select', node)"
      >
        <div
          class="size-9 rounded-xl flex items-center justify-center shrink-0"
          :class="[
            CATEGORY_STYLES[node.category].soft,
            CATEGORY_STYLES[node.category].text,
          ]"
        >
          <span class="size-5" :class="node.icon" />
        </div>
        <div class="min-w-0 flex-1">
          <h4 class="text-sm font-medium text-n-slate-12 truncate">
            {{ node.title }}
          </h4>
          <p class="text-xs text-n-slate-11 truncate">
            {{ node.subtitle }}
          </p>
        </div>
        <span
          class="i-lucide-plus size-4 text-n-brand opacity-0 group-hover:opacity-100 transition-opacity"
        />
      </button>
      <p
        v-if="!filteredNodes.length"
        class="px-3 py-8 text-center text-sm text-n-slate-11"
      >
        Nenhum bloco encontrado.
      </p>
    </div>
  </div>
</template>
