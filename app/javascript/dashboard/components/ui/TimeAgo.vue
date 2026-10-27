<script>
const MINUTE_IN_MILLI_SECONDS = 60000;
const HOUR_IN_MILLI_SECONDS = MINUTE_IN_MILLI_SECONDS * 60;
const DAY_IN_MILLI_SECONDS = HOUR_IN_MILLI_SECONDS * 24;

import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

export default {
  name: 'TimeAgo',
  props: {
    isAutoRefreshEnabled: {
      type: Boolean,
      default: true,
    },
    lastActivityTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    createdAtTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    conversationId: {
      type: [String, Number],
      default: '',
    },
  },
  setup() {
    return { exactTimestamp: useExactTimestamp() };
  },
  data() {
    return {
      lastActivityAtTimeAgo: dynamicTime(this.lastActivityTimestamp),
      createdAtTimeAgo: dynamicTime(this.createdAtTimestamp),
      nowTick: Date.now(),
      timer: null,
    };
  },
  computed: {
    lastActivityTime() {
      return shortTimestamp(this.lastActivityAtTimeAgo);
    },
    createdAtTime() {
      return shortTimestamp(this.createdAtTimeAgo);
    },
    createdAtColorClass() {
      return this.getTimeUrgencyColorClass(this.createdAtTimestamp);
    },
    lastActivityColorClass() {
      return this.getTimeUrgencyColorClass(this.lastActivityTimestamp);
    },
    createdAt() {
      return `${this.$t(
        'CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST'
      )} ${this.exactTimestamp(this.createdAtTimestamp)}`;
    },
    lastActivity() {
      return `${this.$t(
        'CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE'
      )} ${this.exactTimestamp(this.lastActivityTimestamp)}`;
    },
    tooltipText() {
      return `${this.createdAt}\n${this.lastActivity}`;
    },
  },
  watch: {
    lastActivityTimestamp() {
      this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
      this.nowTick = Date.now();
    },
    createdAtTimestamp() {
      this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
      this.nowTick = Date.now();
    },
    conversationId() {
      // Reset display values and timer when the row is recycled to a different conversation.
      this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
      this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
      this.nowTick = Date.now();
      if (this.isAutoRefreshEnabled) {
        clearTimeout(this.timer);
        this.createTimer();
      }
    },
  },
  mounted() {
    if (this.isAutoRefreshEnabled) {
      this.createTimer();
    }
  },
  unmounted() {
    clearTimeout(this.timer);
  },
  methods: {
    getTimeUrgencyColorClass(timestamp) {
      // Reference nowTick so Vue recomputes color classes on timer ticks
      const currentMs = this.nowTick || Date.now();
      const tsSeconds = Number(timestamp);
      if (!tsSeconds || Number.isNaN(tsSeconds)) {
        return 'text-n-slate-10';
      }
      const elapsedMinutes = Math.max(0, (currentMs - tsSeconds * 1000) / MINUTE_IN_MILLI_SECONDS);
      if (elapsedMinutes < 15) {
        return 'text-green-500 dark:text-green-400 font-medium';
      }
      if (elapsedMinutes < 30) {
        return 'text-amber-500 dark:text-amber-400 font-medium';
      }
      return 'text-red-500 dark:text-red-400 font-semibold';
    },
    createTimer() {
      this.timer = setTimeout(() => {
        this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
        this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
        this.nowTick = Date.now();
        this.createTimer();
      }, this.refreshTime());
    },
    refreshTime() {
      const timeDiff = Date.now() - this.lastActivityTimestamp * 1000;
      if (timeDiff > DAY_IN_MILLI_SECONDS) {
        return DAY_IN_MILLI_SECONDS;
      }
      if (timeDiff > HOUR_IN_MILLI_SECONDS) {
        return HOUR_IN_MILLI_SECONDS;
      }

      return MINUTE_IN_MILLI_SECONDS;
    },
  },
};
</script>

<template>
  <div
    v-tooltip.top="{
      content: tooltipText,
      popperClass: 'whitespace-pre-line',
      delay: { show: 1000, hide: 0 },
    }"
    class="ml-auto leading-4 text-xxs text-n-slate-10 hover:text-n-slate-11"
  >
    <span :class="createdAtColorClass">{{ createdAtTime }}</span><span :class="createdAtColorClass"> • </span><span :class="lastActivityColorClass">{{ lastActivityTime }}</span>
  </div>
</template>
