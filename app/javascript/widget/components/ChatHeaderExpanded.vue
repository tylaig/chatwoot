<script setup>
import HeaderActions from './HeaderActions.vue';
import { computed } from 'vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

const props = defineProps({
  avatarUrl: {
    type: String,
    default: '',
  },
  introHeading: {
    type: String,
    default: '',
  },
  introBody: {
    type: String,
    default: '',
  },
  showPopoutButton: {
    type: Boolean,
    default: false,
  },
});

const { formatMessage } = useMessageFormatter();

const containerClasses = computed(() => [
  props.avatarUrl ? 'justify-between' : 'justify-end',
]);
</script>

<template>
  <header
    class="header-expanded pt-6 pb-2 px-5 relative box-border w-full bg-transparent"
  >
    <div class="flex items-start" :class="containerClasses">
      <div
        v-if="avatarUrl"
        class="w-12 h-12 rounded-[14px] bg-white dark:bg-n-solid-2 flex items-center justify-center shadow-[0_2px_6px_rgba(15,23,42,0.06)] p-1.5"
      >
        <img
          class="w-full h-full object-contain rounded-lg"
          :src="avatarUrl"
          alt="Avatar"
        />
      </div>
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="mt-3.5 text-[21px] leading-[1.25] tracking-[-0.02em] mb-2 font-bold text-slate-900 dark:text-n-slate-12 line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="text-[14px] leading-[1.5] text-slate-600 dark:text-n-slate-11 [&_a]:underline line-clamp-6"
    />
  </header>
</template>
