<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();

// Routes that manage filters/pagination via query params opt out of
// query-keyed remounts, else every filter change rebuilds the page.
const routeKey = computed(() =>
  route.meta.reuseOnQueryChange ? route.path : route.fullPath
);

const isFullWidthRoute = computed(() => Boolean(route.meta.fullWidth));
</script>

<template>
  <div
    class="flex flex-col w-full h-full m-0 pb-8 pt-4 px-6 overflow-auto bg-n-surface-1"
  >
    <div
      class="flex items-start w-full mx-auto"
      :class="isFullWidthRoute ? 'max-w-none' : 'max-w-5xl'"
    >
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="routeKey" />
        </keep-alive>
        <component :is="Component" v-else :key="routeKey" />
      </router-view>
    </div>
  </div>
</template>
