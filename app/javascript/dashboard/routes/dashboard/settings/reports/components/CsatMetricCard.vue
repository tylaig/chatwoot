<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  tooltip: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
  subText: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div class="flex flex-col gap-1.5 items-start justify-center min-w-[9rem]">
    <span
      class="inline-flex items-center gap-1 text-sm font-medium text-n-slate-11"
    >
      {{ label }}
      <span
        v-tooltip.right="tooltip"
        class="i-lucide-info flex flex-shrink-0 text-n-slate-10 size-3.5"
      />
    </span>
    <div
      v-if="isLoading"
      class="w-16 h-8 rounded-md bg-n-slate-3 animate-pulse"
    />
    <div v-else class="flex flex-col gap-0.5">
      <span class="text-2xl font-semibold text-n-slate-12">
        {{ value }}
      </span>
      <span v-if="subText" class="text-xs font-medium text-n-slate-10">
        {{ subText }}
      </span>
    </div>
  </div>
</template>
