<script setup>
import { computed, inject } from 'vue';

const props = defineProps({
  index: {
    type: Number,
    default: 0,
  },
  name: {
    type: String,
    required: true,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  count: {
    type: Number,
    default: 0,
  },
  showBadge: {
    type: Boolean,
    default: true,
  },
  isCompact: {
    type: Boolean,
    default: false,
  },
});

const activeIndex = inject('activeIndex');
const updateActiveIndex = inject('updateActiveIndex');

const active = computed(() => props.index === activeIndex.value);
const getItemCount = computed(() => props.count);

const onTabClick = event => {
  event.preventDefault();
  if (!props.disabled) {
    updateActiveIndex(props.index);
  }
};
</script>

<template>
  <li
    class="flex-shrink-0 my-0 mx-2 ltr:first:ml-0 rtl:first:mr-0 ltr:last:mr-0 rtl:last:ml-0 hover:text-slate-900 dark:hover:text-slate-100"
  >
    <a
      class="flex items-center flex-row select-none cursor-pointer relative after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200 text-button"
      :class="[
        active
          ? 'text-emerald-700 dark:text-emerald-400 font-semibold after:bg-emerald-500 after:opacity-100 msc-tab-link-active'
          : 'text-slate-600 dark:text-slate-400 after:bg-transparent after:opacity-0 msc-tab-link-inactive',
        isCompact ? 'py-2.5' : '!text-base py-3',
      ]"
      @click="onTabClick"
    >
      <span class="msc-tab-label">{{ name }}</span>
      <div
        v-if="showBadge"
        class="rounded-full h-5 flex items-center justify-center text-[11px] font-semibold my-0 ltr:ml-1.5 rtl:mr-1.5 px-1.5 py-0 min-w-[20px] msc-tab-count-badge"
        :class="[
          active
            ? 'bg-emerald-500 text-white dark:bg-emerald-500/25 dark:text-emerald-300 shadow-2xs is-active'
            : 'bg-slate-200/70 dark:bg-white/[0.08] text-slate-600 dark:text-slate-400',
        ]"
      >
        <span class="msc-tab-count-num">
          {{ getItemCount }}
        </span>
      </div>
    </a>
  </li>
</template>
