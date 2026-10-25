<script setup>
import { computed, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
});

defineEmits(['toggleMode']);

const wootEditorReplyMode = useTemplateRef('wootEditorReplyMode');
const wootEditorPrivateMode = useTemplateRef('wootEditorPrivateMode');

const replyModeSize = useElementSize(wootEditorReplyMode);
const privateModeSize = useElementSize(wootEditorPrivateMode);

/**
 * Computed boolean indicating if the editor is in private note mode
 * When isReplyRestricted is true, force switch to private note
 * Otherwise, respect the current mode prop
 * @type {ComputedRef<boolean>}
 */
const isPrivate = computed(() => {
  if (props.isReplyRestricted) {
    // Force switch to private note when replies are restricted
    return true;
  }
  // Otherwise respect the current mode
  return props.mode === REPLY_EDITOR_MODES.NOTE;
});

/**
 * Computes the width of the sliding background chip in pixels
 * Includes 16px of padding in the calculation
 * @type {ComputedRef<string>}
 */
const width = computed(() => {
  const widthToUse = isPrivate.value
    ? privateModeSize.width.value
    : replyModeSize.width.value;

  const widthWithPadding = widthToUse + 16;
  return `${widthWithPadding}px`;
});

/**
 * Computes the X translation value for the sliding background chip
 * Translates by the width of reply mode + padding when in private mode
 * @type {ComputedRef<string>}
 */
const translateValue = computed(() => {
  const xTranslate = isPrivate.value ? replyModeSize.width.value + 16 : 0;

  return `${xTranslate}px`;
});
</script>

<template>
  <button
    type="button"
    class="flex items-center w-auto h-8 p-1 transition-all border border-slate-200/90 dark:border-white/10 rounded-full bg-slate-100/90 dark:bg-[#09131E] group relative duration-300 ease-in-out z-0 active:scale-[0.995] active:duration-75 text-[12.5px] sm:text-[13px] shrink-0 whitespace-nowrap"
    :disabled="disabled || isReplyRestricted"
    :class="{
      'cursor-not-allowed opacity-70': disabled || isReplyRestricted,
    }"
    @click="$emit('toggleMode')"
  >
    <div
      ref="wootEditorReplyMode"
      class="flex items-center gap-1.5 px-2 sm:px-2.5 z-20 transition-colors whitespace-nowrap shrink-0"
      :class="
        !isPrivate
          ? 'text-emerald-700 dark:text-emerald-300 font-semibold'
          : 'text-slate-500 dark:text-slate-400 font-medium'
      "
    >
      <span
        class="i-lucide-message-square size-3.5 shrink-0"
        :class="
          !isPrivate
            ? 'text-emerald-600 dark:text-emerald-400'
            : 'text-slate-400 dark:text-slate-500'
        "
      />
      <span>{{ $t('CONVERSATION.REPLYBOX.REPLY') }}</span>
    </div>
    <div
      ref="wootEditorPrivateMode"
      class="flex items-center gap-1.5 px-2 sm:px-2.5 z-20 transition-colors whitespace-nowrap shrink-0"
      :class="
        isPrivate
          ? 'text-amber-900 dark:text-amber-200 font-semibold'
          : 'text-slate-500 dark:text-slate-400 font-medium'
      "
    >
      <span
        class="i-lucide-lock size-3.5 shrink-0"
        :class="
          isPrivate
            ? 'text-amber-600 dark:text-amber-400'
            : 'text-slate-400 dark:text-slate-500'
        "
      />
      <span>{{ $t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') }}</span>
    </div>
    <div
      class="absolute shadow-xs rounded-full h-6 w-[var(--chip-width)] ease-in-out translate-x-[var(--translate-x)] rtl:translate-x-[var(--rtl-translate-x)]"
      :class="[
        isPrivate
          ? 'bg-amber-100 dark:bg-amber-500/20 border border-amber-300/70 dark:border-amber-500/35'
          : 'bg-white dark:bg-emerald-500/20 border border-slate-200/90 dark:border-emerald-500/35',
        {
          'transition-all duration-300': !disabled && !isReplyRestricted,
        },
      ]"
      :style="{
        '--chip-width': width,
        '--translate-x': translateValue,
        '--rtl-translate-x': `calc(-1 * var(--translate-x))`,
      }"
    />
  </button>
</template>
