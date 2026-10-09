<script setup>
import { ref, computed } from 'vue';
import {
  WORKFLOW_NODES_REGISTRY,
  NODE_CATEGORIES,
} from '../nodeRegistry';

defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'select']);

const searchQuery = ref('');
const selectedCategory = ref('all');

const allNodesList = computed(() => Object.values(WORKFLOW_NODES_REGISTRY));

const filteredNodes = computed(() => {
  return allNodesList.value.filter(n => {
    const matchesCat =
      selectedCategory.value === 'all' || n.category === selectedCategory.value;
    const matchesSearch =
      !searchQuery.value ||
      n.title.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      n.subtitle.toLowerCase().includes(searchQuery.value.toLowerCase());
    return matchesCat && matchesSearch;
  });
});

const handleSelect = nodeMeta => {
  emit('select', nodeMeta);
};
</script>

<template>
  <div
    v-if="show"
    class="absolute left-6 top-6 z-30 w-80 rounded-2xl bg-n-solid-1 border border-n-weak shadow-2xl overflow-hidden flex flex-col select-none text-n-slate-12"
    style="max-height: calc(100% - 48px);"
  >
    <!-- HEADER DA PALETA -->
    <div
      class="p-4 border-b border-n-weak flex items-center justify-between"
    >
      <h3 class="text-xs font-bold text-n-slate-12">Adicionar Ação</h3>
      <button
        type="button"
        class="text-n-slate-9 hover:text-n-slate-12 text-xs p-1"
        @click="emit('close')"
      >
        ✕
      </button>
    </div>

    <!-- BUSCA DE BLOCOS -->
    <div class="p-3 border-b border-n-weak">
      <div class="relative">
        <span class="absolute left-3 top-2.5 text-xs text-n-slate-9">🔍</span>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Pesquisar blocos..."
          class="w-full pl-8 pr-3 py-1.5 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-blue-500"
        />
      </div>
    </div>

    <!-- LAYOUT DE CATEGORIAS + LISTA DE NODES -->
    <div class="flex flex-1 min-h-0 overflow-hidden">
      <!-- SIDEBAR DE CATEGORIAS -->
      <div
        class="w-24 border-r border-n-weak p-1.5 overflow-y-auto space-y-0.5 shrink-0"
      >
        <button
          v-for="cat in NODE_CATEGORIES"
          :key="cat.id"
          type="button"
          class="w-full text-left px-2 py-1.5 rounded-lg text-[11px] font-medium transition-colors truncate"
          :class="
            selectedCategory === cat.id
              ? 'bg-blue-600/10 text-blue-600 dark:text-blue-400 font-bold'
              : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1'
          "
          @click="selectedCategory = cat.id"
        >
          {{ cat.name }}
        </button>
      </div>

      <!-- LISTAGEM DE NODES -->
      <div class="flex-1 p-2 overflow-y-auto space-y-1.5">
        <div
          v-for="node in filteredNodes"
          :key="node.type"
          draggable="true"
          class="p-2.5 rounded-xl bg-n-solid-2 border border-n-weak hover:border-n-strong hover:bg-n-alpha-2 transition-all cursor-pointer flex items-start gap-2.5 group"
          @click="handleSelect(node)"
          @dragstart="$event.dataTransfer.setData('application/vueflow', node.type)"
        >
          <!-- Ícone -->
          <div
            v-if="node.icon === 'whatsapp'"
            class="w-6 h-6 rounded-full bg-[#25D366] flex items-center justify-center shrink-0 shadow-sm mt-0.5"
          >
            <svg class="w-3.5 h-3.5 text-white fill-current" viewBox="0 0 24 24">
              <path
                d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"
              />
            </svg>
          </div>
          <div
            v-else
            class="w-6 h-6 rounded-lg flex items-center justify-center text-xs font-semibold shrink-0 mt-0.5"
            :style="{
              backgroundColor: `${node.iconColor || '#3B82F6'}1A`,
              color: node.iconColor || '#3B82F6',
            }"
          >
            {{ node.icon }}
          </div>

          <div class="min-w-0 flex-1">
            <h4
              class="text-xs font-bold text-n-slate-12 group-hover:text-blue-500 transition-colors truncate"
            >
              {{ node.title }}
            </h4>
            <p class="text-[10px] text-n-slate-11 line-clamp-2 leading-tight">
              {{ node.subtitle }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
