<script setup>
import { computed } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { CSAT_RATINGS } from 'shared/constants/messages';

defineProps({
  leaderboard: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const starSymbol = '★';
const aiSymbol = '🤖';

const ratingColors = computed(() =>
  CSAT_RATINGS.reduce((acc, item) => {
    acc[item.value] = item.color;
    return acc;
  }, {})
);

const getMedal = index => {
  if (index === 0) return '🥇';
  if (index === 1) return '🥈';
  if (index === 2) return '🥉';
  return `${index + 1}º`;
};

const getCountForRating = (row, star) => {
  if (!row?.ratings_count) return 0;
  return row.ratings_count[star] || row.ratings_count[String(star)] || 0;
};

const getPercentForRating = (row, star) => {
  if (!row?.total_count) return 0;
  const count = getCountForRating(row, star);
  return Math.round((count * 100) / row.total_count);
};

const formatStarCount = (row, star) =>
  `${star}★: ${getCountForRating(row, star)}`;

const formatSatisfactionScore = score => `${score}%`;
</script>

<template>
  <div
    class="flex flex-col gap-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <div
      class="flex flex-col sm:flex-row sm:items-center justify-between gap-2"
    >
      <div>
        <h3 class="text-base font-semibold text-n-slate-12 m-0">
          {{ $t('CSAT_REPORTS.LEADERBOARD.TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11 m-0 mt-0.5">
          {{ $t('CSAT_REPORTS.LEADERBOARD.SUBTITLE') }}
        </p>
      </div>
    </div>

    <div v-if="isLoading" class="flex flex-col gap-2.5">
      <div
        v-for="i in 4"
        :key="i"
        class="h-12 w-full rounded-lg bg-n-slate-3 animate-pulse"
      />
    </div>

    <div
      v-else-if="!leaderboard.length"
      class="py-6 text-center text-sm text-n-slate-11 italic"
    >
      {{ $t('CSAT_REPORTS.LEADERBOARD.EMPTY') }}
    </div>

    <div v-else class="overflow-x-auto">
      <table class="w-full text-left border-collapse min-w-[42rem]">
        <thead>
          <tr
            class="border-b border-n-weak text-xs font-semibold text-n-slate-11 uppercase tracking-wider"
          >
            <th class="py-2.5 px-3 w-12">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.RANK') }}
            </th>
            <th class="py-2.5 px-3">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.AGENT') }}
            </th>
            <th class="py-2.5 px-3">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.AVERAGE') }}
            </th>
            <th class="py-2.5 px-3">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.CSAT_SCORE') }}
            </th>
            <th class="py-2.5 px-3">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.TOTAL') }}
            </th>
            <th class="py-2.5 px-3 w-64">
              {{ $t('CSAT_REPORTS.LEADERBOARD.COLUMNS.DISTRIBUTION') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak text-sm">
          <tr
            v-for="(item, idx) in leaderboard"
            :key="item.id"
            class="hover:bg-n-solid-3/50 transition-colors"
          >
            <td class="py-3 px-3 font-bold text-n-slate-12">
              {{ getMedal(idx) }}
            </td>
            <td class="py-3 px-3">
              <div class="flex items-center gap-2.5">
                <div
                  v-if="item.is_ai"
                  class="flex items-center justify-center size-7 rounded-full bg-n-violet-3 text-sm shrink-0"
                >
                  {{ aiSymbol }}
                </div>
                <Avatar
                  v-else
                  :name="item.name"
                  :src="item.thumbnail"
                  :size="28"
                  rounded-full
                />
                <div class="flex flex-col">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-n-slate-12">
                      {{ item.name }}
                    </span>
                    <span
                      v-if="item.is_ai"
                      class="px-1.5 py-0.5 text-[10px] font-semibold rounded bg-n-violet-3 text-n-violet-11 border border-n-violet-6/40"
                    >
                      {{ $t('CSAT_REPORTS.LEADERBOARD.AI_TAG') }}
                    </span>
                    <span
                      v-else
                      class="px-1.5 py-0.5 text-[10px] font-medium rounded bg-n-slate-3 text-n-slate-11"
                    >
                      {{ $t('CSAT_REPORTS.LEADERBOARD.HUMAN_TAG') }}
                    </span>
                  </div>
                </div>
              </div>
            </td>
            <td class="py-3 px-3">
              <div class="flex items-center gap-1.5">
                <span class="text-base font-bold text-n-slate-12">
                  {{ Number(item.average_rating).toFixed(2) }}
                </span>
                <div class="flex items-center text-xs">
                  <span
                    v-for="star in 5"
                    :key="star"
                    :class="
                      star <= Math.round(item.average_rating)
                        ? 'text-n-amber-9'
                        : 'text-n-slate-6 opacity-40'
                    "
                  >
                    {{ starSymbol }}
                  </span>
                </div>
              </div>
            </td>
            <td class="py-3 px-3">
              <span
                class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold"
                :class="
                  item.satisfaction_score >= 75
                    ? 'bg-n-teal-3/60 text-n-teal-11'
                    : item.satisfaction_score >= 50
                      ? 'bg-n-amber-3/60 text-n-amber-11'
                      : 'bg-n-ruby-3/60 text-n-ruby-11'
                "
              >
                {{ formatSatisfactionScore(item.satisfaction_score) }}
              </span>
            </td>
            <td class="py-3 px-3 font-semibold text-n-slate-12">
              {{ item.total_count }}
            </td>
            <td class="py-3 px-3">
              <div class="flex flex-col gap-1">
                <div
                  class="flex h-2 w-full overflow-hidden rounded-full bg-n-slate-4"
                >
                  <div
                    v-for="star in [5, 4, 3, 2, 1]"
                    :key="star"
                    :style="{
                      width: `${getPercentForRating(item, star)}%`,
                      backgroundColor: ratingColors[star],
                    }"
                    class="h-full transition-all duration-300"
                  />
                </div>
                <div
                  class="flex items-center justify-between text-[10px] text-n-slate-11"
                >
                  <span v-for="star in [5, 4, 3, 2, 1]" :key="star">
                    {{ formatStarCount(item, star) }}
                  </span>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
