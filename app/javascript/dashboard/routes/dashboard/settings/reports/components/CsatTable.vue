<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';

import { messageStamp, dynamicTime } from 'shared/helpers/timeHelper';

import Pagination from 'dashboard/components/table/Pagination.vue';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import ShowMore from 'dashboard/components/widgets/ShowMore.vue';
import CsatContactCell from './CsatContactCell.vue';
import CsatExpandedRow from './CsatExpandedRow.vue';
import CsatEmptyState from './CsatEmptyState.vue';
import CsatTableLoader from './CsatTableLoader.vue';

import { CSAT_RATINGS } from 'shared/constants/messages';

import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';

const { pageIndex } = defineProps({
  pageIndex: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['pageChange']);
const { t } = useI18n();
const { isCloudFeatureEnabled, isOnChatwootCloud } = useAccount();
const csatResponses = useMapGetter('csat/getCSATResponses');

const isFeatureEnabled = computed(() =>
  isCloudFeatureEnabled('csat_review_notes')
);
const showExpandableRows = computed(
  () => isFeatureEnabled.value || isOnChatwootCloud.value
);
const metrics = useMapGetter('csat/getMetrics');
const uiFlags = useMapGetter('csat/getUIFlags');

const isLoading = computed(() => uiFlags.value.isFetching);

const expandedRows = ref({});

const toggleRow = id => {
  expandedRows.value = {
    ...expandedRows.value,
    [id]: !expandedRows.value[id],
  };
};

const isRowExpanded = id => !!expandedRows.value[id];

const tableData = computed(() => {
  return csatResponses.value.map(response => ({
    id: response.id,
    contact: response.contact,
    assignedAgent: response.assigned_agent,
    handledByAi: response.handled_by_ai,
    aiAgentName: response.ai_agent_name,
    inboxName: response.inbox_name,
    rating: response.rating,
    feedbackText: response.feedback_message || '',
    conversationId: response.conversation_id,
    csatReviewNotes: response.csat_review_notes,
    createdAgo: dynamicTime(response.created_at),
    createdAt: messageStamp(response.created_at, 'LLL d yyyy, h:mm a'),
    _original: response,
  }));
});

const getRatingData = rating => {
  return CSAT_RATINGS.find(r => r.value === rating) || {};
};

const starSymbol = '★';
const aiSymbol = 'IA';
const formatRatingFraction = rating => `${rating}/5`;
const formatRatingText = rating => {
  const key = getRatingData(rating).translationKey;
  return key ? t(key).replace(/^[^\p{L}\p{N}]+\s*/u, '') : '';
};

const columnHelper = createColumnHelper();

const columns = computed(() => {
  const baseColumns = [
    columnHelper.accessor('contact', {
      header: t('CSAT_REPORTS.TABLE.HEADER.CONTACT_NAME'),
    }),
    columnHelper.accessor('rating', {
      header: t('CSAT_REPORTS.TABLE.HEADER.RATING'),
      size: 170,
    }),
    columnHelper.accessor('feedbackText', {
      header: t('CSAT_REPORTS.TABLE.HEADER.FEEDBACK_TEXT'),
      size: 460,
    }),
    columnHelper.accessor('assignedAgent', {
      header: t('CSAT_REPORTS.TABLE.HEADER.HANDLED_BY'),
      size: 200,
    }),
  ];

  if (showExpandableRows.value) {
    baseColumns.push(
      columnHelper.accessor('actions', {
        header: '',
        size: 50,
      })
    );
  }

  return baseColumns;
});

const paginationParams = computed(() => {
  return {
    pageIndex: pageIndex,
    pageSize: 25,
  };
});

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  manualPagination: true,
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
  get rowCount() {
    return metrics.value.totalResponseCount;
  },
  state: {
    get pagination() {
      return paginationParams.value;
    },
  },
  onPaginationChange: updater => {
    const newPagination = updater(paginationParams.value);
    emit('pageChange', newPagination.pageIndex);
  },
});
</script>

<template>
  <div
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 overflow-hidden"
  >
    <CsatTableLoader v-if="isLoading" />

    <div v-else-if="tableData.length" class="overflow-x-auto">
      <table class="w-full">
        <thead class="bg-n-solid-2 border-b border-n-container">
          <tr>
            <th
              v-for="header in table.getFlatHeaders()"
              :key="header.id"
              :style="{
                width: header.getSize() ? `${header.getSize()}px` : 'auto',
              }"
              class="text-left py-3 px-5 font-medium text-sm text-n-slate-12"
            >
              {{ header.column.columnDef.header }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-container">
          <template v-for="row in tableData" :key="row.id">
            <tr
              class="group hover:bg-n-slate-2 dark:hover:bg-n-solid-3 transition-colors"
              :class="{
                'bg-n-slate-2 dark:bg-n-solid-3': isRowExpanded(row.id),
                'cursor-pointer': showExpandableRows,
              }"
              @click="showExpandableRows && toggleRow(row.id)"
            >
              <td class="py-4 px-5">
                <CsatContactCell
                  :contact="row.contact"
                  :conversation-id="row.conversationId"
                  :created-ago="row.createdAgo"
                  :created-at="row.createdAt"
                />
              </td>
              <td class="py-4 px-5">
                <div class="flex flex-col items-start gap-1">
                  <div class="flex items-center gap-0.5 text-sm leading-none">
                    <span
                      v-for="star in 5"
                      :key="star"
                      class="i-lucide-star size-3.5"
                      :class="
                        star <= row.rating
                          ? 'text-n-amber-9'
                          : 'text-n-slate-6 dark:text-n-slate-7 opacity-35'
                      "
                    />
                    <span class="ml-1 text-xs font-bold text-n-slate-12">
                      {{ formatRatingFraction(row.rating) }}
                    </span>
                  </div>
                  <div
                    class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md"
                    :style="{
                      backgroundColor: `${getRatingData(row.rating).color}20`,
                    }"
                  >
                    <span class="text-xs font-medium text-n-slate-12 truncate">
                      {{ formatRatingText(row.rating) }}
                    </span>
                  </div>
                </div>
              </td>
              <td class="py-4 px-5">
                <span
                  v-if="!row.feedbackText"
                  class="text-n-slate-10 italic text-sm"
                >
                  {{ $t('CSAT_REPORTS.NO_FEEDBACK') }}
                </span>
                <div v-else class="text-sm text-n-slate-12">
                  <ShowMore :text="row.feedbackText" :limit="100" />
                </div>
              </td>
              <td class="py-4 px-5">
                <div v-if="row.assignedAgent" class="flex flex-col gap-0.5">
                  <UserAvatarWithName :user="row.assignedAgent" :size="28" />
                  <span
                    v-if="row.inboxName"
                    class="text-[11px] text-n-slate-10 pl-9 truncate"
                  >
                    {{ row.inboxName }}
                  </span>
                </div>
                <div
                  v-else
                  class="inline-flex flex-col items-start gap-0.5 px-2.5 py-1 rounded-lg bg-n-violet-3/60 dark:bg-n-violet-3/30 border border-n-violet-6/40"
                >
                  <div class="flex items-center gap-1.5">
                    <span
                      class="inline-flex items-center justify-center px-1.5 py-0.5 rounded bg-n-violet-9 text-white text-[10px] font-bold leading-none"
                    >
                      {{ aiSymbol }}
                    </span>
                    <span class="text-xs font-semibold text-n-violet-11">
                      {{
                        row.aiAgentName || $t('CSAT_REPORTS.AI_HANDLED_BADGE')
                      }}
                    </span>
                  </div>
                  <span
                    v-if="row.inboxName"
                    class="text-[11px] text-n-slate-10 pl-5 truncate"
                  >
                    {{ row.inboxName }}
                  </span>
                </div>
              </td>
              <td v-if="showExpandableRows" class="py-4 px-5">
                <div
                  class="p-1.5 rounded-md text-n-slate-10 group-hover:text-n-slate-12 transition-colors"
                >
                  <i
                    class="size-4 block transition-transform duration-200"
                    :class="
                      isRowExpanded(row.id)
                        ? 'i-lucide-chevron-up'
                        : 'i-lucide-chevron-down'
                    "
                  />
                </div>
              </td>
            </tr>
            <tr
              v-if="showExpandableRows && isRowExpanded(row.id)"
              class="!border-t-0"
            >
              <td colspan="5" class="p-0 !border-t-0">
                <CsatExpandedRow :response="row._original" />
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <CsatEmptyState
      v-else
      :title="$t('CSAT_REPORTS.NO_RECORDS')"
      :description="$t('CSAT_REPORTS.NO_RECORDS_DESCRIPTION')"
    />

    <div
      v-if="metrics.totalResponseCount"
      class="px-6 py-4 border-t border-n-weak"
    >
      <Pagination :table="table" />
    </div>
  </div>
</template>
