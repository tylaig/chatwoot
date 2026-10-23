<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  lucideIcon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <div class="text-sm msc-accordion-item">
    <button
      class="flex items-center select-none w-full rounded-xl bg-[#0B1216]/95 border border-emerald-500/20 hover:border-emerald-500/40 m-0 cursor-grab justify-between py-2.5 px-3.5 drag-handle transition-all duration-200 group"
      :class="{
        'rounded-bl-none rounded-br-none border-emerald-500/30 bg-[#0D171D]':
          isOpen,
      }"
      @click.stop="onToggle"
    >
      <div class="flex items-center gap-2.5 min-w-0">
        <span
          v-if="lucideIcon"
          :class="lucideIcon"
          class="text-base text-emerald-400 flex-shrink-0 transition-transform duration-200 group-hover:scale-105"
        />
        <EmojiOrIcon
          v-else-if="icon || emoji"
          class="inline-block w-5 text-emerald-400 flex-shrink-0"
          :icon="icon"
          :emoji="emoji"
        />
        <h5
          class="text-slate-100 group-hover:text-white text-sm font-medium mb-0 py-0 pr-2 pl-0 truncate"
        >
          {{ title }}
        </h5>
      </div>
      <div class="flex flex-row items-center gap-1.5 flex-shrink-0">
        <slot name="button" />
        <div
          class="flex items-center justify-center w-5 h-5 text-emerald-400/90 group-hover:text-emerald-300 cursor-pointer transition-colors"
        >
          <fluent-icon v-if="isOpen" size="20" icon="subtract" type="solid" />
          <fluent-icon v-else size="20" icon="add" type="solid" />
        </div>
      </div>
    </button>
    <div
      v-if="isOpen"
      class="bg-[#091014]/90 border border-t-0 border-emerald-500/20 rounded-br-xl rounded-bl-xl"
      :class="compact ? 'p-0' : 'px-3 py-3.5'"
    >
      <slot />
    </div>
  </div>
</template>
