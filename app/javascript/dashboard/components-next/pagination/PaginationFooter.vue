<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNumberFormatter } from 'shared/composables/useNumberFormatter';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  currentPage: {
    type: Number,
    required: true,
  },
  totalItems: {
    type: Number,
    required: true,
  },
  itemsPerPage: {
    type: Number,
    default: 16,
  },
  currentPageInfo: {
    type: String,
    default: '',
  },
});
const emit = defineEmits(['update:currentPage']);
const { t } = useI18n();
const { formatCompactNumber, formatFullNumber } = useNumberFormatter();

const totalPages = computed(() =>
  Math.ceil(props.totalItems / props.itemsPerPage)
);
const startItem = computed(
  () => (props.currentPage - 1) * props.itemsPerPage + 1
);
const endItem = computed(() =>
  Math.min(startItem.value + props.itemsPerPage - 1, props.totalItems)
);
const isFirstPage = computed(() => props.currentPage === 1);
const isLastPage = computed(() => props.currentPage === totalPages.value);
const changePage = newPage => {
  if (newPage >= 1 && newPage <= totalPages.value) {
    emit('update:currentPage', newPage);
  }
};

const currentPageInformation = computed(() => {
  const translationKey = props.currentPageInfo || 'PAGINATION_FOOTER.SHOWING';
  return t(
    translationKey,
    {
      startItem: formatFullNumber(startItem.value),
      endItem: formatFullNumber(endItem.value),
      totalItems: formatCompactNumber(props.totalItems),
    },
    Number(props.totalItems)
  );
});

const pageInfo = computed(() => {
  return t(
    'PAGINATION_FOOTER.CURRENT_PAGE_INFO',
    {
      currentPage: '',
      totalPages: formatCompactNumber(totalPages.value),
    },
    Number(totalPages.value)
  );
});
</script>

<template>
  <div
    class="relative flex justify-between h-[3.25rem] w-full mx-auto py-2.5 pl-14 pr-16 lg:px-6 items-center"
  >
    <div class="flex items-center gap-3 min-w-0">
      <span class="min-w-0 text-xs sm:text-sm font-medium line-clamp-1 text-slate-300">
        {{ currentPageInformation }}
      </span>
    </div>
    <div class="flex items-center gap-1.5 sm:gap-2">
      <Button
        icon="i-lucide-chevrons-left"
        variant="ghost"
        size="sm"
        color="slate"
        class="!w-7 !h-7 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-md"
        :disabled="isFirstPage"
        @click="changePage(1)"
      />
      <Button
        icon="i-lucide-chevron-left"
        variant="ghost"
        color="slate"
        size="sm"
        class="!w-7 !h-7 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-md"
        :disabled="isFirstPage"
        @click="changePage(currentPage - 1)"
      />
      <div class="inline-flex items-center gap-2 text-xs sm:text-sm">
        <span
          class="px-2.5 tabular-nums py-0.5 font-semibold bg-[#10B981]/15 text-[#10B981] border border-[#10B981]/30 rounded-md"
        >
          {{ formatFullNumber(currentPage) }}
        </span>
        <span class="truncate text-slate-400">
          {{ pageInfo }}
        </span>
      </div>
      <Button
        icon="i-lucide-chevron-right"
        variant="ghost"
        color="slate"
        size="sm"
        class="!w-7 !h-7 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-md"
        :disabled="isLastPage"
        @click="changePage(currentPage + 1)"
      />
      <Button
        icon="i-lucide-chevrons-right"
        variant="ghost"
        color="slate"
        size="sm"
        class="!w-7 !h-7 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-md"
        :disabled="isLastPage"
        @click="changePage(totalPages)"
      />
    </div>
  </div>
</template>
