<script setup>
import { computed, inject, nextTick, onMounted, ref, watch } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { formatVariable, tokenizeTemplate } from '../variables';

const props = defineProps({
  modelValue: {
    type: [String, Number],
    default: '',
  },
  multiline: {
    type: Boolean,
    default: false,
  },
  rows: {
    type: Number,
    default: 3,
  },
  placeholder: {
    type: String,
    default: '',
  },
  mono: {
    type: Boolean,
    default: false,
  },
  // 'template' insere a variável no cursor; 'path' substitui o valor inteiro.
  mode: {
    type: String,
    default: 'template',
    validator: value => ['template', 'path'].includes(value),
  },
  formatting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);

const MESSAGE_FORMATS = [
  { id: 'bold', title: 'Negrito', icon: 'i-lucide-bold', wrap: ['*', '*'] },
  { id: 'italic', title: 'Itálico', icon: 'i-lucide-italic', wrap: ['_', '_'] },
  {
    id: 'strike',
    title: 'Tachado',
    icon: 'i-lucide-strikethrough',
    wrap: ['~', '~'],
  },
  {
    id: 'mono',
    title: 'Monoespaçado',
    icon: 'i-lucide-code',
    wrap: ['```', '```'],
  },
  { id: 'quote', title: 'Citação', icon: 'i-lucide-text-quote', prefix: '> ' },
  { id: 'bullet', title: 'Lista', icon: 'i-lucide-list', prefix: '- ' },
  { id: 'number', title: 'Lista numerada', icon: 'i-lucide-list-ordered' },
];

const FALLBACK_CATALOG = { groups: [], isValid: () => true };
const catalog = inject(
  'workflowVariables',
  computed(() => FALLBACK_CATALOG)
);

const field = ref(null);
const overlay = ref(null);
const searchInput = ref(null);
const menuOpen = ref(false);
const openedFromButton = ref(false);
const query = ref('');
const activeIndex = ref(0);

const text = computed(() => String(props.modelValue ?? ''));
const segments = computed(() =>
  tokenizeTemplate(text.value, catalog.value.isValid)
);
const invalidList = computed(() =>
  segments.value.filter(seg => seg.type === 'variable' && !seg.valid)
);

const filteredGroups = computed(() => {
  const term = query.value.trim().toLowerCase().replace(/^\$/, '');
  return catalog.value.groups
    .map(group => ({
      ...group,
      items: group.items.filter(item => {
        if (!item?.path) return false;
        if (!term) return true;
        const label = String(item.label || '');
        return (
          item.path.toLowerCase().includes(term) ||
          label.toLowerCase().includes(term)
        );
      }),
    }))
    .filter(group => group.items.length || (!term && group.emptyHint));
});

const flatItems = computed(() =>
  filteredGroups.value.flatMap(group => group.items)
);

const sharedTextClass = computed(() => [
  'px-3 pt-2 text-xs leading-5',
  props.multiline ? 'pb-11 pe-14' : 'pb-2 pe-14',
  props.mono ? 'font-mono' : 'font-sans',
]);

const syncScroll = () => {
  if (!overlay.value || !field.value) return;
  overlay.value.scrollLeft = field.value.scrollLeft;
  overlay.value.scrollTop = field.value.scrollTop;
};

const autoResize = () => {
  if (!props.multiline || !field.value) return;
  field.value.style.height = 'auto';
  field.value.style.height = `${field.value.scrollHeight}px`;
};

const openTriggerIndex = () => {
  const caret = field.value?.selectionStart ?? text.value.length;
  const before = text.value.slice(0, caret);
  const start = before.lastIndexOf('{{');
  if (start === -1 || before.slice(start).includes('}}')) return -1;
  return start;
};

const closeMenu = () => {
  menuOpen.value = false;
  openedFromButton.value = false;
  query.value = '';
};

const onInput = event => {
  emit('update:modelValue', event.target.value);
  nextTick(() => {
    autoResize();
    syncScroll();
    const start = openTriggerIndex();
    if (start === -1) {
      if (!openedFromButton.value) closeMenu();
      return;
    }
    const caret = field.value?.selectionStart;
    if (caret == null) return;
    query.value = text.value.slice(start + 2, caret).trim();
    menuOpen.value = true;
    activeIndex.value = 0;
  });
};

const toggleMenu = () => {
  if (menuOpen.value) {
    closeMenu();
    return;
  }
  menuOpen.value = true;
  openedFromButton.value = true;
  query.value = '';
  activeIndex.value = 0;
  nextTick(() => searchInput.value?.focus());
};

const insertVariable = item => {
  const token = formatVariable(item.path);
  if (props.mode === 'path') {
    emit('update:modelValue', token);
    closeMenu();
    return;
  }

  const caret = field.value?.selectionEnd ?? text.value.length;
  const trigger = openedFromButton.value ? -1 : openTriggerIndex();
  const start = trigger === -1 ? caret : trigger;
  const next = `${text.value.slice(0, start)}${token}${text.value.slice(caret)}`;
  emit('update:modelValue', next);
  closeMenu();

  nextTick(() => {
    const position = start + token.length;
    field.value?.focus();
    field.value?.setSelectionRange(position, position);
    autoResize();
    syncScroll();
  });
};

const onKeydown = event => {
  if (!menuOpen.value || !flatItems.value.length) return;
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    activeIndex.value = (activeIndex.value + 1) % flatItems.value.length;
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    activeIndex.value =
      (activeIndex.value - 1 + flatItems.value.length) % flatItems.value.length;
  } else if (event.key === 'Enter') {
    event.preventDefault();
    insertVariable(flatItems.value[activeIndex.value]);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    closeMenu();
  }
};

const itemIndex = item => flatItems.value.indexOf(item);

const placeCaret = (start, end) => {
  nextTick(() => {
    field.value?.focus();
    field.value?.setSelectionRange(start, end);
    autoResize();
    syncScroll();
  });
};

const applyFormat = format => {
  const value = text.value;
  const start = field.value?.selectionStart ?? value.length;
  const end = field.value?.selectionEnd ?? start;

  if (format.wrap) {
    const [open, close] = format.wrap;
    const inner = value.slice(start, end) || 'texto';
    const next = `${value.slice(0, start)}${open}${inner}${close}${value.slice(end)}`;
    emit('update:modelValue', next);
    placeCaret(start + open.length, start + open.length + inner.length);
    return;
  }

  const lineStart = value.lastIndexOf('\n', Math.max(start - 1, 0)) + 1;
  const lineBreak = value.indexOf('\n', end);
  const lineEnd = lineBreak === -1 ? value.length : lineBreak;
  const prefixed = value
    .slice(lineStart, lineEnd)
    .split('\n')
    .map((line, index) => {
      const marker = format.id === 'number' ? `${index + 1}. ` : format.prefix;
      return line.startsWith(marker) ? line : `${marker}${line}`;
    })
    .join('\n');
  emit(
    'update:modelValue',
    `${value.slice(0, lineStart)}${prefixed}${value.slice(lineEnd)}`
  );
  placeCaret(lineStart + prefixed.length, lineStart + prefixed.length);
};

watch(text, () => nextTick(autoResize));
onMounted(autoResize);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <OnClickOutside class="relative" @trigger="closeMenu">
    <div v-if="formatting" class="mb-1.5 flex flex-wrap gap-1">
      <button
        v-for="format in MESSAGE_FORMATS"
        :key="format.id"
        type="button"
        class="flex size-7 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
        :title="format.title"
        @mousedown.prevent
        @click="applyFormat(format)"
      >
        <span class="size-3.5" :class="format.icon" />
      </button>
    </div>
    <div
      class="relative rounded-lg bg-n-alpha-black2 outline outline-1 transition-colors"
      :class="
        invalidList.length
          ? 'outline-n-ruby-8'
          : 'outline-n-weak hover:outline-n-slate-6 focus-within:!outline-n-brand'
      "
    >
      <div
        ref="overlay"
        aria-hidden="true"
        class="absolute inset-0 overflow-hidden pointer-events-none text-n-slate-12"
        :class="[
          sharedTextClass,
          multiline ? 'whitespace-pre-wrap break-words' : 'whitespace-pre',
        ]"
      >
        <template v-for="(segment, index) in segments" :key="index">
          <span
            v-if="segment.type === 'variable'"
            class="rounded"
            :class="
              segment.valid
                ? 'text-n-iris-11 bg-n-iris-3'
                : 'text-n-ruby-11 bg-n-ruby-3'
            "
            >{{ segment.text }}</span
          ><template v-else>{{ segment.text }}</template>
        </template>
        <template v-if="multiline">{{ '\u200b' }}</template>
      </div>

      <textarea
        v-if="multiline"
        ref="field"
        :value="text"
        :rows="rows"
        :placeholder="placeholder"
        spellcheck="false"
        class="relative block w-full m-0 h-auto min-h-0 resize-none overflow-hidden bg-transparent border-0 outline-none text-transparent caret-n-slate-12 placeholder:text-n-slate-10 selection:bg-n-iris-5 selection:text-transparent"
        :class="sharedTextClass"
        @input="onInput"
        @keydown="onKeydown"
        @scroll="syncScroll"
      />
      <input
        v-else
        ref="field"
        :value="text"
        type="text"
        :placeholder="placeholder"
        spellcheck="false"
        class="reset-base relative block w-full h-11 m-0 bg-transparent border-0 outline-none text-transparent caret-n-slate-12 placeholder:text-n-slate-10 selection:bg-n-iris-5 selection:text-transparent"
        :class="sharedTextClass"
        @input="onInput"
        @keydown="onKeydown"
        @scroll="syncScroll"
        @keyup="syncScroll"
        @click="syncScroll"
      />

      <button
        type="button"
        class="absolute end-1.5 bottom-1.5 flex items-center justify-center h-8 px-2 rounded-lg transition-colors"
        :class="
          menuOpen
            ? 'bg-n-brand text-white'
            : 'text-n-slate-11 hover:text-n-brand hover:bg-n-alpha-2'
        "
        title="Inserir variável"
        @mousedown.prevent
        @click="toggleMenu"
      >
        <span
          class="font-mono text-base font-bold leading-none whitespace-nowrap"
        >
          { }
        </span>
      </button>
    </div>

    <p
      v-if="invalidList.length"
      class="mt-1 flex items-center gap-1 text-[0.6875rem] text-n-ruby-11"
    >
      <span class="i-lucide-circle-alert size-3 shrink-0" />
      <span class="truncate">
        Variável inválida:
        <span class="font-mono">{{
          invalidList.map(s => s.text).join(', ')
        }}</span>
      </span>
    </p>

    <div
      v-if="menuOpen"
      class="absolute start-0 end-0 top-full mt-1 z-50 rounded-xl bg-n-solid-2 border border-n-weak shadow-2xl overflow-hidden"
    >
      <div v-if="openedFromButton" class="p-2 border-b border-n-weak">
        <div class="relative">
          <span
            class="i-lucide-search size-3.5 absolute start-2.5 top-1/2 -translate-y-1/2 text-n-slate-10"
          />
          <input
            ref="searchInput"
            v-model="query"
            type="text"
            placeholder="Buscar variável…"
            class="reset-base w-full h-8 m-0 ps-8 pe-2 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
            @keydown="onKeydown"
          />
        </div>
      </div>
      <div class="max-h-72 overflow-y-auto py-1">
        <div v-for="group in filteredGroups" :key="group.id" class="py-1">
          <p
            class="flex items-center gap-1.5 px-3 py-1 text-[0.625rem] font-semibold uppercase tracking-wide text-n-slate-10"
          >
            <span class="size-3" :class="group.icon" />
            {{ group.label }}
          </p>
          <p
            v-if="!group.items.length"
            class="px-3 py-1 text-xs text-n-slate-10 italic"
          >
            {{ group.emptyHint }}
          </p>
          <button
            v-for="item in group.items"
            :key="item.path"
            type="button"
            class="w-full flex items-center gap-2 px-3 py-1.5 text-start"
            :class="
              itemIndex(item) === activeIndex
                ? 'bg-n-alpha-2'
                : 'hover:bg-n-alpha-1'
            "
            @mousedown.prevent
            @click="insertVariable(item)"
            @mouseenter="activeIndex = itemIndex(item)"
          >
            <span
              class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
              >{ }</span
            >
            <span class="font-mono text-xs text-n-iris-11 truncate"
              >${{ item.path }}</span
            >
            <span class="text-xs text-n-slate-11 truncate">{{
              item.label
            }}</span>
            <span
              v-if="item.sample"
              class="ms-auto max-w-[6rem] truncate text-[0.6875rem] text-n-slate-10 font-mono"
            >
              {{ item.sample }}
            </span>
          </button>
        </div>
        <p
          v-if="!filteredGroups.length"
          class="px-3 py-4 text-center text-xs text-n-slate-11"
        >
          Nenhuma variável encontrada.
        </p>
      </div>
    </div>
  </OnClickOutside>
</template>
