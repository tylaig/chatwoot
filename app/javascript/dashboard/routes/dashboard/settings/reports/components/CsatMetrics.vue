<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import CsatMetricCard from './CsatMetricCard.vue';
import CsatRatingDistribution from './CsatRatingDistribution.vue';
import CsatAgentLeaderboard from './CsatAgentLeaderboard.vue';

const metrics = useMapGetter('csat/getMetrics');
const ratingCount = useMapGetter('csat/getRatingCount');
const satisfactionScore = useMapGetter('csat/getSatisfactionScore');
const responseRate = useMapGetter('csat/getResponseRate');
const agentLeaderboard = useMapGetter('csat/getAgentLeaderboard');
const uiFlags = useMapGetter('csat/getUIFlags');

const isLoading = computed(() => uiFlags.value?.isFetchingMetrics);

const responseCount = computed(() =>
  metrics.value?.totalResponseCount
    ? metrics.value.totalResponseCount.toLocaleString()
    : '0'
);

const averageStarRating = computed(() => {
  const total = metrics.value?.totalResponseCount || 0;
  if (!total) return '0.00 ★';
  const rc = ratingCount.value || {};
  const weightedSum =
    (rc[1] || 0) * 1 +
    (rc[2] || 0) * 2 +
    (rc[3] || 0) * 3 +
    (rc[4] || 0) * 4 +
    (rc[5] || 0) * 5;
  return `${(weightedSum / total).toFixed(2)} ★`;
});

const aiVsHumanValue = computed(() => {
  const ai = metrics.value?.aiResponsesCount || 0;
  const human = metrics.value?.humanResponsesCount || 0;
  return `${ai} IA / ${human} Hum.`;
});

const aiVsHumanParams = computed(() => {
  const total = metrics.value?.totalResponseCount || 0;
  const ai = metrics.value?.aiResponsesCount || 0;
  const human = metrics.value?.humanResponsesCount || 0;
  const aiPercent = total ? Math.round((ai * 100) / total) : 0;
  const humanPercent = total ? 100 - aiPercent : 0;
  return {
    ai,
    aiPercent,
    human,
    humanPercent,
  };
});

const formatPercent = value => (value ? `${value}%` : '0%');
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 w-full gap-4 lg:gap-6 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
    >
      <CsatMetricCard
        :label="$t('CSAT_REPORTS.METRIC.TOTAL_RESPONSES.LABEL')"
        :tooltip="$t('CSAT_REPORTS.METRIC.TOTAL_RESPONSES.TOOLTIP')"
        :value="responseCount"
        :is-loading="isLoading"
      />

      <CsatMetricCard
        :label="$t('CSAT_REPORTS.METRIC.AVERAGE_RATING.LABEL')"
        :tooltip="$t('CSAT_REPORTS.METRIC.AVERAGE_RATING.TOOLTIP')"
        :value="averageStarRating"
        :is-loading="isLoading"
      />

      <CsatMetricCard
        :label="$t('CSAT_REPORTS.METRIC.SATISFACTION_SCORE.LABEL')"
        :tooltip="$t('CSAT_REPORTS.METRIC.SATISFACTION_SCORE.TOOLTIP')"
        :value="formatPercent(satisfactionScore)"
        :is-loading="isLoading"
      />

      <CsatMetricCard
        :label="$t('CSAT_REPORTS.METRIC.RESPONSE_RATE.LABEL')"
        :tooltip="$t('CSAT_REPORTS.METRIC.RESPONSE_RATE.TOOLTIP')"
        :value="formatPercent(responseRate)"
        :is-loading="isLoading"
      />

      <CsatMetricCard
        :label="$t('CSAT_REPORTS.METRIC.AI_VS_HUMAN.LABEL')"
        :tooltip="$t('CSAT_REPORTS.METRIC.AI_VS_HUMAN.TOOLTIP')"
        :value="aiVsHumanValue"
        :sub-text="
          metrics.totalResponseCount
            ? $t('CSAT_REPORTS.METRIC.AI_VS_HUMAN.AI_SUB', aiVsHumanParams)
            : ''
        "
        :is-loading="isLoading"
      />
    </div>

    <CsatRatingDistribution
      :rating-count="ratingCount"
      :total-response-count="metrics.totalResponseCount"
      :is-loading="isLoading"
    />

    <CsatAgentLeaderboard
      :leaderboard="agentLeaderboard"
      :is-loading="isLoading"
    />
  </div>
</template>
