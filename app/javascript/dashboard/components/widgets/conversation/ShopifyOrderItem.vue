<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const formatDate = dateString => {
  try {
    return format(new Date(dateString), 'dd/MM/yyyy HH:mm');
  } catch {
    return dateString;
  }
};

const formatCurrency = (amount, currency) => {
  try {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: currency || 'BRL',
    }).format(amount);
  } catch {
    return `${currency || 'R$'} ${amount}`;
  }
};

const getStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-5 text-n-teal-12',
    pending: 'bg-n-amber-5 text-n-amber-12',
    refunded: 'bg-n-ruby-5 text-n-ruby-12',
  };
  return classes[status] || 'bg-n-solid-3 text-n-slate-12';
};

const getStatusI18nKey = (type, status = '') => {
  return `CONVERSATION_SIDEBAR.SHOPIFY.${type.toUpperCase()}_STATUS.${status.toUpperCase()}`;
};

const fulfillmentStatus = computed(() => {
  const { fulfillment_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FULFILLMENT', status));
});

const financialStatus = computed(() => {
  const { financial_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FINANCIAL', status));
});

const getFulfillmentClass = status => {
  const classes = {
    fulfilled: 'text-n-teal-9',
    partial: 'text-n-amber-9',
    unfulfilled: 'text-n-ruby-9',
  };
  return classes[status] || 'text-n-slate-11';
};

const lineItems = computed(() =>
  Array.isArray(props.order.line_items) ? props.order.line_items : []
);

const orderDisplayTitle = computed(
  () => props.order.name || `#${props.order.id}`
);

const recentOrderBadge = computed(() => {
  if (!props.order.within_one_hour_window) return '';
  return `< 1h (${props.order.minutes_since_created}m)`;
});

const formatLineItem = item => {
  const variant = item.variant_title ? ` (${item.variant_title})` : '';
  return `${item.quantity}x ${item.title}${variant}`;
};
</script>

<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-1.5"
  >
    <div
      v-if="order.store_name || order.shop_domain"
      class="flex items-center justify-between gap-1"
    >
      <span
        class="text-[11px] font-semibold px-2 py-0.5 rounded bg-n-solid-3 text-n-slate-12 truncate"
        :title="order.shop_domain"
      >
        {{ order.store_name || order.shop_domain }}
      </span>
      <span
        v-if="recentOrderBadge"
        class="text-[10px] px-1.5 py-0.5 rounded bg-n-amber-4 text-n-amber-12 font-medium"
      >
        {{ recentOrderBadge }}
      </span>
    </div>

    <div class="flex justify-between items-center gap-2">
      <div class="font-semibold flex items-center min-w-0">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline text-n-slate-12 cursor-pointer truncate flex items-center gap-1"
        >
          <span>{{ orderDisplayTitle }}</span>
          <i class="i-lucide-external-link text-xs shrink-0" />
        </a>
      </div>
      <div
        :class="getStatusClass(order.financial_status)"
        class="text-xs px-2 py-0.5 rounded capitalize truncate shrink-0"
        :title="financialStatus"
      >
        {{ financialStatus }}
      </div>
    </div>

    <div class="text-xs text-n-slate-12 flex items-center justify-between">
      <span class="text-n-slate-11">
        {{ formatDate(order.created_at) }}
      </span>
      <span class="font-medium text-n-slate-12">
        {{ formatCurrency(order.total_price, order.currency) }}
      </span>
    </div>

    <div class="flex items-center justify-between text-xs">
      <span
        v-if="fulfillmentStatus"
        :class="getFulfillmentClass(order.fulfillment_status)"
        class="capitalize font-medium"
        :title="fulfillmentStatus"
      >
        {{ fulfillmentStatus }}
      </span>
      <span
        v-if="order.email"
        class="text-n-slate-11 truncate max-w-[160px]"
        :title="order.email"
      >
        {{ order.email }}
      </span>
    </div>

    <div
      v-if="lineItems.length"
      class="mt-1 pt-1.5 border-t border-n-weak/60 flex flex-col gap-1"
    >
      <div
        v-for="item in lineItems"
        :key="item.id"
        class="text-xs text-n-slate-11 flex justify-between gap-2"
      >
        <span class="truncate" :title="item.title">
          {{ formatLineItem(item) }}
        </span>
      </div>
    </div>
  </div>
</template>
