<script setup>
import { CSAT_RATINGS } from 'shared/constants/messages';

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

const ratingLabels = {
  1: 'Péssimo',
  2: 'Ruim',
  3: 'Regular',
  4: 'Bom',
  5: 'Excelente',
};

const ratings = CSAT_RATINGS;

const buttonClass = rating => [
  'flex flex-col items-center justify-center p-2 rounded-2xl',
  'transition-all duration-200 ease-out flex-1 min-w-[60px]',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
  'focus-visible:ring-[color:var(--survey-brand)]',
  'disabled:cursor-default disabled:opacity-40',
  '[@media(hover:hover)]:hover:enabled:scale-105',
  '[@media(hover:hover)]:hover:enabled:opacity-100',
  '[@media(hover:hover)]:hover:enabled:saturate-100',
  rating.value === props.selectedRating
    ? 'scale-105 opacity-100 saturate-100 bg-[color-mix(in_srgb,var(--survey-brand)_14%,transparent)]'
    : 'opacity-80 saturate-75',
];
</script>

<template>
  <div class="flex flex-wrap justify-between gap-1.5 pb-2 sm:gap-2">
    <button
      v-for="rating in ratings"
      :key="rating.key"
      type="button"
      :disabled="isDisabled"
      :aria-label="`${rating.value} - ${ratingLabels[rating.value] || $t(rating.translationKey)}`"
      :aria-pressed="rating.value === selectedRating"
      :class="buttonClass(rating)"
      @click="emit('selectRating', rating.value)"
    >
      <span aria-hidden="true" class="text-4xl sm:text-5xl">{{
        rating.emoji
      }}</span>
      <span
        class="mt-2 w-full py-1 px-1.5 rounded-xl bg-slate-100 dark:bg-n-solid-2 flex flex-col items-center leading-tight"
      >
        <span
          class="text-xs font-extrabold text-slate-900 dark:text-n-slate-12"
        >
          {{ rating.value }}
        </span>
        <span
          class="text-[10.5px] font-medium text-slate-500 dark:text-n-slate-11"
        >
          {{ ratingLabels[rating.value] }}
        </span>
      </span>
    </button>
  </div>
</template>
