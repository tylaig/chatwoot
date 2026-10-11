<script setup>
import { computed, inject, nextTick, ref, watch } from 'vue';
import { OnClickOutside } from '@vueuse/components';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  fields: {
    type: Array,
    default: () => [],
  },
  placeholder: {
    type: String,
    default: 'customer.phone',
  },
});

const emit = defineEmits(['update:modelValue']);

const registerTarget = inject('registerWebhookPathTarget', null);
const open = ref(false);
const query = ref('');
const draft = ref(props.modelValue || '');
const activeIndex = ref(0);
const input = ref(null);

watch(
  () => props.modelValue,
  value => {
    if (document.activeElement !== input.value) draft.value = value || '';
  }
);

const suggestions = computed(() => {
  const term = (open.value ? query.value : draft.value).trim().toLowerCase();
  return props.fields
    .filter(field => !term || field.path.toLowerCase().includes(term))
    .slice(0, 8);
});

const commit = value => {
  draft.value = value;
  emit('update:modelValue', value);
};

const showMenu = () => {
  open.value = true;
  query.value = draft.value;
  activeIndex.value = 0;
  registerTarget?.(commit);
};

const onInput = event => {
  draft.value = event.target.value;
  query.value = event.target.value;
  open.value = true;
  activeIndex.value = 0;
};

const choose = field => {
  commit(field.path);
  open.value = false;
  nextTick(() => input.value?.blur());
};

const onKeydown = event => {
  if (!open.value || !suggestions.value.length) return;
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    activeIndex.value = (activeIndex.value + 1) % suggestions.value.length;
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    activeIndex.value =
      (activeIndex.value - 1 + suggestions.value.length) %
      suggestions.value.length;
  } else if (event.key === 'Enter') {
    event.preventDefault();
    choose(suggestions.value[activeIndex.value]);
  } else if (event.key === 'Escape') {
    open.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <OnClickOutside class="relative" @trigger="open = false">
    <input
      ref="input"
      :value="draft"
      type="text"
      :placeholder="placeholder"
      class="reset-base h-8 m-0 w-full py-0 ps-2 pe-7 text-xs font-mono rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
      @focus="showMenu"
      @input="onInput"
      @blur="commit(draft)"
      @keydown="onKeydown"
    />
    <span
      class="i-lucide-chevrons-up-down pointer-events-none absolute end-2 top-1/2 size-3.5 -translate-y-1/2 text-n-slate-10"
    />
    <div
      v-if="open && suggestions.length"
      class="absolute z-30 mt-1 w-full max-h-48 overflow-auto rounded-lg border border-n-weak bg-n-solid-2 p-1 shadow-xl"
    >
      <button
        v-for="(field, index) in suggestions"
        :key="field.path"
        type="button"
        class="w-full flex items-center gap-2 rounded-md px-2 py-1.5 text-start"
        :class="index === activeIndex ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'"
        @mousedown.prevent="choose(field)"
      >
        <span
          class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
          >{ }</span
        >
        <span
          class="min-w-0 flex-1 truncate font-mono text-[0.6875rem] text-n-slate-12"
          >{{ field.path }}</span
        >
        <span
          v-if="field.sample"
          class="max-w-[5.5rem] truncate font-mono text-[0.625rem] text-n-slate-10"
          >{{ field.sample }}</span
        >
      </button>
    </div>
  </OnClickOutside>
</template>
