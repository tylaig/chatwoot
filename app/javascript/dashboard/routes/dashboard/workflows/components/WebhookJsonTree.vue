<script setup>
defineProps({
  value: {
    type: null,
    default: null,
  },
  path: {
    type: String,
    default: '',
  },
  depth: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['pick']);

const isBranch = value => value !== null && typeof value === 'object';

const entriesOf = value => {
  if (Array.isArray(value)) {
    return value.map((item, index) => [String(index), item]);
  }
  return Object.entries(value || {});
};

const childPath = (parent, key) => (parent ? `${parent}.${key}` : key);

const preview = value => {
  if (value === null) return 'null';
  if (typeof value === 'string') return JSON.stringify(value);
  return String(value);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <ul
    class="space-y-0.5"
    :class="depth ? 'ms-3 border-s border-n-weak ps-2' : ''"
  >
    <li v-for="[key, child] in entriesOf(value)" :key="childPath(path, key)">
      <details v-if="isBranch(child)" :open="depth < 1" class="group">
        <summary
          class="flex items-center gap-1.5 cursor-pointer list-none text-n-slate-11 hover:text-n-slate-12"
        >
          <span
            class="i-lucide-chevron-right size-3 transition-transform group-open:rotate-90"
          />
          <span class="text-n-amber-11">{{ key }}</span>
          <span class="text-n-slate-10">{{
            Array.isArray(child) ? `[${child.length}]` : '{…}'
          }}</span>
        </summary>
        <WebhookJsonTree
          class="mt-0.5"
          :value="child"
          :path="childPath(path, key)"
          :depth="depth + 1"
          @pick="emit('pick', $event)"
        />
      </details>
      <button
        v-else
        type="button"
        class="w-full flex items-center gap-1.5 min-w-0 rounded-md px-1 py-0.5 text-start hover:bg-n-alpha-2"
        :title="`Usar ${childPath(path, key)}`"
        @click="emit('pick', childPath(path, key))"
      >
        <span
          class="font-mono text-sm font-bold leading-none text-n-iris-11 shrink-0"
          >{ }</span
        >
        <span class="text-n-iris-11 shrink-0">{{ key }}</span>
        <span class="truncate text-n-slate-10">{{ preview(child) }}</span>
      </button>
    </li>
  </ul>
</template>
