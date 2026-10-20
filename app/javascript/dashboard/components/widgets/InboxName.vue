<script setup>
import { computed } from 'vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
  withPhoneNumber: {
    type: Boolean,
    default: false,
  },
  withProviderConnectionStatus: {
    type: Boolean,
    default: false,
  },
});

const providerConnection = computed(() => {
  return props.inbox.provider_connection?.connection;
});

const hexToRgba = (hex, alpha = 0.2) => {
  const clean = String(hex || '').replace('#', '').trim();
  if (!/^[0-9a-fA-F]{6}$/.test(clean)) return '';
  const r = parseInt(clean.slice(0, 2), 16);
  const g = parseInt(clean.slice(2, 4), 16);
  const b = parseInt(clean.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

const inboxColor = computed(() => props.inbox?.inbox_color || '');
const badgeLabel = computed(
  () => props.inbox?.inbox_badge_label || props.inbox?.name || ''
);
const hasCustomIdentity = computed(() =>
  Boolean(inboxColor.value || props.inbox?.inbox_badge_label)
);

const badgeStyle = computed(() => {
  if (!inboxColor.value) return {};
  return {
    backgroundColor: hexToRgba(inboxColor.value, 0.2),
    color: inboxColor.value,
    borderColor: hexToRgba(inboxColor.value, 0.35),
  };
});
</script>

<template>
  <div :title="badgeLabel" class="flex items-center gap-1 min-w-0">
    <span
      v-if="hasCustomIdentity"
      class="inline-flex items-center px-2 py-0.5 rounded-[5px] text-[11px] font-bold uppercase tracking-wide leading-4 truncate border border-transparent bg-n-alpha-2 text-n-slate-12"
      :style="badgeStyle"
    >
      {{ badgeLabel }}
    </span>
    <template v-else>
      <ChannelIcon :inbox="inbox" class="size-4 flex-shrink-0 text-n-slate-11" />
      <span class="truncate text-label-small text-n-slate-11">
        {{ inbox.name }}
      </span>
    </template>
    <span v-if="withPhoneNumber" class="ml-2 text-n-slate-12">{{
      inbox.phone_number
    }}</span>
    <span v-if="withProviderConnectionStatus" class="ml-2">
      <fluent-icon
        icon="circle"
        type="filled"
        :class="
          providerConnection === 'open' ? 'text-green-500' : 'text-n-slate-8'
        "
      />
    </span>
  </div>
</template>
