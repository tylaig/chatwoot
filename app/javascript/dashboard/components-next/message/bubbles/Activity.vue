<script setup>
import { computed } from 'vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';

const { content, createdAt } = useMessageContext();

const readableTime = computed(() =>
  messageTimestamp(createdAt.value, 'LLL d, h:mm a')
);
</script>

<template>
  <BaseBubble
    v-tooltip.top="readableTime"
    class="px-3.5 py-1 !rounded-full flex min-w-0 items-center gap-1.5"
    data-bubble-name="activity"
  >
    <span
      class="i-lucide-info size-3.5 text-slate-400 dark:text-slate-400 shrink-0"
    />
    <span :title="content">{{ content }}</span>
  </BaseBubble>
</template>
