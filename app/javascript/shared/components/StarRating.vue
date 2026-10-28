<script setup>
import { ref } from 'vue';

const props = defineProps({
  selectedRating: {
    type: Number,
    default: null,
  },
  isDisabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectRating']);

const starRatings = [
  { value: 1, label: 'Péssimo' },
  { value: 2, label: 'Ruim' },
  { value: 3, label: 'Regular' },
  { value: 4, label: 'Bom' },
  { value: 5, label: 'Excelente' },
];
const hoveredRating = ref(0);

const onHoverRating = value => {
  if (props.isDisabled) return;
  hoveredRating.value = value;
};

const selectRating = value => {
  if (props.isDisabled) return;
  emit('selectRating', value);
};

const isStarHighlighted = value => {
  if (props.selectedRating) {
    return props.selectedRating >= value;
  }
  if (hoveredRating.value > 0 && !props.isDisabled) {
    return hoveredRating.value >= value;
  }
  return true;
};

const isBadgeSelected = value => {
  return (
    props.selectedRating === value ||
    (hoveredRating.value === value && !props.isDisabled)
  );
};
</script>

<template>
  <div
    class="flex justify-between items-start py-4 px-2.5 sm:px-4 gap-1.5 w-full box-border"
  >
    <button
      v-for="item in starRatings"
      :key="item.value"
      type="button"
      class="group flex flex-col items-center flex-1 min-w-0 p-1 rounded-xl bg-transparent border-0 transition-transform duration-200 focus:enabled:scale-105 hover:enabled:scale-105 focus:outline-none cursor-pointer select-none"
      :class="{ 'cursor-not-allowed opacity-60': isDisabled }"
      :disabled="isDisabled"
      :aria-label="`${item.value} - ${item.label}`"
      @click="selectRating(item.value)"
      @mouseenter="onHoverRating(item.value)"
      @mouseleave="onHoverRating(0)"
    >
      <span
        class="i-ri-star-fill text-[28px] sm:text-[32px] leading-none transition-all duration-200 drop-shadow-[0_2px_4px_rgba(245,158,11,0.28)]"
        :class="
          isStarHighlighted(item.value)
            ? 'text-[#fbbf24] scale-100'
            : 'text-slate-300 dark:text-n-slate-8 scale-95 opacity-60'
        "
      />
      <div
        class="mt-2 w-full py-1 px-1 rounded-xl flex flex-col items-center justify-center transition-colors duration-200 border border-solid"
        :class="
          isBadgeSelected(item.value)
            ? 'bg-amber-50 dark:bg-amber-950/40 border-amber-300 dark:border-amber-700'
            : 'bg-[#f1f5f9] dark:bg-n-solid-2 border-transparent group-hover:bg-slate-200/70'
        "
      >
        <span
          class="text-[12px] font-extrabold leading-tight text-slate-900 dark:text-n-slate-12"
        >
          {{ item.value }}
        </span>
        <span
          class="text-[10px] font-medium leading-tight text-slate-500 dark:text-n-slate-11 truncate max-w-full"
        >
          {{ item.label }}
        </span>
      </div>
    </button>
  </div>
</template>
