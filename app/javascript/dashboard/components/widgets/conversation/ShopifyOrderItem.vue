<script setup>
import { ref, computed } from 'vue';
import { format } from 'date-fns';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
  defaultExpanded: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const isExpanded = ref(props.defaultExpanded);

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
};

const formatDate = dateString => {
  if (!dateString) return '—';
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
    }).format(Number(amount || 0));
  } catch {
    return `${currency || 'R$'} ${amount}`;
  }
};

const getStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-6/30',
    pending: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-6/30',
    refunded: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-6/30',
    voided: 'bg-n-slate-3 text-n-slate-11 border border-n-weak',
  };
  return classes[status] || 'bg-n-solid-3 text-n-slate-12 border border-n-weak';
};

const getStatusI18nKey = (type, status = '') => {
  return `CONVERSATION_SIDEBAR.SHOPIFY.${type.toUpperCase()}_STATUS.${status.toUpperCase()}`;
};

const fulfillmentStatus = computed(() => {
  const { fulfillment_status: status } = props.order;
  if (!status) {
    return 'Não enviado';
  }
  const translated = t(getStatusI18nKey('FULFILLMENT', status));
  return translated.includes('CONVERSATION_SIDEBAR') ? status : translated;
});

const financialStatus = computed(() => {
  const { financial_status: status } = props.order;
  if (!status) {
    return 'Pendente';
  }
  const translated = t(getStatusI18nKey('FINANCIAL', status));
  return translated.includes('CONVERSATION_SIDEBAR') ? status : translated;
});

const getFulfillmentBadgeClass = status => {
  const classes = {
    fulfilled: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-6/30',
    partial: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-6/30',
    unfulfilled: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-6/30',
  };
  return classes[status] || 'bg-n-alpha-2 text-n-slate-11 border border-n-weak';
};

const lineItems = computed(() =>
  Array.isArray(props.order.line_items) ? props.order.line_items : []
);

const fulfillments = computed(() =>
  Array.isArray(props.order.fulfillments) ? props.order.fulfillments : []
);

const orderTags = computed(() => {
  if (!props.order.tags) return [];
  return String(props.order.tags)
    .split(',')
    .map(tag => tag.trim())
    .filter(Boolean);
});

const orderDisplayTitle = computed(
  () => props.order.name || `#${props.order.id}`
);

const recentOrderBadge = computed(() => {
  if (!props.order.within_one_hour_window) return '';
  return `< 1h (${props.order.minutes_since_created}m)`;
});

const copyText = async (val, label) => {
  if (!val) return;
  try {
    await navigator.clipboard.writeText(String(val));
    useAlert(`${label} copiado!`);
  } catch {
    // ignore
  }
};
</script>

<!-- eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template -->
<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-2.5"
  >
    <!-- Linha 1: Loja + Badge < 1h -->
    <div
      v-if="order.store_name || order.shop_domain"
      class="flex items-center justify-between gap-1.5"
    >
      <span
        class="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-md bg-n-brand/10 text-n-brand truncate"
        :title="order.shop_domain"
      >
        <i class="i-lucide-store text-[11px] shrink-0" />
        <span class="truncate">{{
          order.store_name || order.shop_domain
        }}</span>
      </span>
      <span
        v-if="recentOrderBadge"
        class="inline-flex items-center gap-1 text-[10px] px-2 py-0.5 rounded-full bg-n-amber-3 text-n-amber-11 font-semibold shrink-0"
      >
        <i class="i-lucide-clock text-[10px]" />
        {{ recentOrderBadge }}
      </span>
    </div>

    <!-- Linha 2: Número do Pedido + Status Financeiro e Entrega -->
    <div class="flex justify-between items-center gap-2 flex-wrap">
      <div class="font-bold text-sm flex items-center gap-1.5 min-w-0">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline text-n-slate-12 cursor-pointer truncate flex items-center gap-1"
        >
          <span>{{ orderDisplayTitle }}</span>
          <i class="i-lucide-external-link text-xs text-n-slate-10 shrink-0" />
        </a>
        <button
          type="button"
          class="text-n-slate-10 hover:text-n-slate-12 !p-0.5 rounded hover:bg-n-alpha-2"
          title="Copiar número do pedido"
          @click.stop="copyText(orderDisplayTitle, 'Pedido')"
        >
          <i class="i-lucide-copy text-[11px]" />
        </button>
      </div>

      <div class="flex items-center gap-1.5 shrink-0">
        <span
          :class="getStatusClass(order.financial_status)"
          class="text-[11px] font-medium px-2 py-0.5 rounded-full capitalize truncate"
          :title="financialStatus"
        >
          {{ financialStatus }}
        </span>
        <span
          v-if="fulfillmentStatus"
          :class="getFulfillmentBadgeClass(order.fulfillment_status)"
          class="text-[11px] font-medium px-2 py-0.5 rounded-full capitalize truncate"
          :title="fulfillmentStatus"
        >
          {{ fulfillmentStatus }}
        </span>
      </div>
    </div>

    <!-- Linha 3: Data + Valor Total -->
    <div
      class="text-xs text-n-slate-12 flex items-center justify-between bg-n-alpha-1 px-2.5 py-1.5 rounded-lg border border-n-weak/60"
    >
      <span class="text-n-slate-11 flex items-center gap-1">
        <i class="i-lucide-calendar text-xs text-n-slate-10" />
        {{ formatDate(order.created_at) }}
      </span>
      <span class="font-bold text-sm text-n-slate-12">
        {{ formatCurrency(order.total_price, order.currency) }}
      </span>
    </div>

    <!-- Linha 4: Resumo de Itens (Sempre visível) -->
    <div v-if="lineItems.length" class="flex flex-col gap-1.5">
      <div
        v-for="item in lineItems"
        :key="item.id"
        class="flex items-start justify-between gap-2 p-2 rounded-lg bg-n-solid-3/60 border border-n-weak/50 text-xs"
      >
        <div class="flex flex-col min-w-0 flex-1">
          <span
            class="font-medium text-n-slate-12 line-clamp-2 leading-snug"
            :title="item.title"
          >
            {{ item.quantity }}x {{ item.title }}
          </span>
          <div
            class="flex items-center gap-2 text-[11px] text-n-slate-10 mt-0.5 flex-wrap"
          >
            <span v-if="item.variant_title">{{ item.variant_title }}</span>
            <span v-if="item.sku" class="font-mono text-n-slate-11">
              • SKU: {{ item.sku }}
            </span>
          </div>
        </div>
        <span
          v-if="item.price"
          class="font-semibold text-n-slate-12 shrink-0 text-xs"
        >
          {{ formatCurrency(item.price, order.currency) }}
        </span>
      </div>
    </div>

    <!-- Botão Expandir / Recolher Detalhes Completos do Pedido -->
    <button
      type="button"
      class="flex items-center justify-between w-full px-2.5 py-1.5 rounded-lg text-xs font-medium text-n-brand bg-n-brand/5 hover:bg-n-brand/10 border border-n-brand/20 transition-colors"
      @click="toggleExpand"
    >
      <span class="flex items-center gap-1.5">
        <i class="i-lucide-list-collapse text-xs" />
        <span>
          {{
            isExpanded
              ? 'Recolher detalhes do pedido'
              : 'Expandir detalhes completos do pedido'
          }}
        </span>
      </span>
      <i
        class="text-xs transition-transform"
        :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
      />
    </button>

    <!-- Painel Expandido com Todos os Detalhes do Pedido -->
    <div
      v-if="isExpanded"
      class="flex flex-col gap-2.5 p-3 rounded-xl bg-n-alpha-1 border border-n-weak text-xs animate-fade-in"
    >
      <!-- Dados do Cliente e Pagamento -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <div
          class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-solid-2 border border-n-weak/60"
        >
          <span
            class="text-[10px] uppercase tracking-wider text-n-slate-10 font-semibold"
          >
            Cliente & Contato
          </span>
          <span class="font-semibold text-n-slate-12 truncate">
            {{ order.customer_name || 'Cliente Shopify' }}
          </span>
          <span
            v-if="order.email"
            class="text-[11px] text-n-slate-11 truncate cursor-pointer hover:text-n-brand"
            @click="copyText(order.email, 'E-mail')"
          >
            {{ order.email }}
          </span>
          <span
            v-if="order.phone"
            class="text-[11px] text-n-slate-11 truncate cursor-pointer hover:text-n-brand"
            @click="copyText(order.phone, 'Telefone')"
          >
            {{ order.phone }}
          </span>
        </div>

        <div
          class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-solid-2 border border-n-weak/60"
        >
          <span
            class="text-[10px] uppercase tracking-wider text-n-slate-10 font-semibold"
          >
            Pagamento & Entrega
          </span>
          <span class="font-medium text-n-slate-12 truncate">
            {{ order.payment_method || 'PIX / Cartão de Crédito' }}
          </span>
          <span class="text-[11px] text-n-slate-11 truncate">
            Destino: {{ order.shipping_city || 'Entrega Digital' }}
          </span>
          <span class="text-[11px] text-n-slate-10">
            Atualizado: {{ formatDate(order.updated_at || order.created_at) }}
          </span>
        </div>
      </div>

      <!-- Resumo Financeiro Detalhado -->
      <div
        class="flex flex-col gap-1 p-2.5 rounded-lg bg-n-solid-2 border border-n-weak/60"
      >
        <div
          class="flex items-center justify-between text-[11px] text-n-slate-11"
        >
          <span>Subtotal dos itens ({{ lineItems.length }})</span>
          <span>{{
            formatCurrency(
              order.subtotal_price || order.total_price,
              order.currency
            )
          }}</span>
        </div>
        <div
          v-if="Number(order.total_discounts) > 0"
          class="flex items-center justify-between text-[11px] text-n-teal-11"
        >
          <span>Descontos aplicados</span>
          <span>
            {{ `-${formatCurrency(order.total_discounts, order.currency)}` }}
          </span>
        </div>
        <div
          class="flex items-center justify-between text-xs font-bold text-n-slate-12 pt-1 border-t border-n-weak"
        >
          <span>Total do Pedido</span>
          <span>{{ formatCurrency(order.total_price, order.currency) }}</span>
        </div>
      </div>

      <!-- Rastreio / Fulfillments -->
      <div
        v-if="fulfillments.length"
        class="flex flex-col gap-1.5 p-2.5 rounded-lg bg-n-solid-2 border border-n-weak/60"
      >
        <span
          class="text-[10px] uppercase tracking-wider text-n-slate-10 font-semibold"
        >
          Envio / Rastreamento
        </span>
        <div
          v-for="ful in fulfillments"
          :key="ful.id"
          class="flex items-center justify-between gap-2 text-[11px]"
        >
          <div class="flex flex-col min-w-0">
            <span class="font-medium text-n-slate-12 truncate">
              {{ ful.tracking_company }}
            </span>
            <span v-if="ful.tracking_number" class="font-mono text-n-slate-11">
              Código: {{ ful.tracking_number }}
            </span>
          </div>
          <a
            v-if="ful.tracking_url"
            :href="ful.tracking_url"
            target="_blank"
            rel="noopener noreferrer"
            class="px-2 py-1 rounded bg-n-brand/10 text-n-brand font-medium hover:underline shrink-0"
          >
            Rastrear
          </a>
        </div>
      </div>

      <!-- Observações e Tags -->
      <div
        v-if="order.note || orderTags.length"
        class="flex flex-col gap-1.5 p-2.5 rounded-lg bg-n-solid-2 border border-n-weak/60"
      >
        <p
          v-if="order.note"
          class="text-[11px] text-n-slate-11 leading-relaxed"
        >
          <strong class="text-n-slate-12">Nota:</strong> {{ order.note }}
        </p>
        <div v-if="orderTags.length" class="flex items-center gap-1 flex-wrap">
          <span
            v-for="tag in orderTags"
            :key="tag"
            class="px-1.5 py-0.5 text-[10px] font-medium rounded bg-n-alpha-2 text-n-slate-11 border border-n-weak"
          >
            #{{ tag }}
          </span>
        </div>
      </div>

      <!-- Ações Rápidas -->
      <div class="flex items-center justify-between gap-2 pt-1">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-lg bg-n-brand text-white font-medium text-xs hover:opacity-90 transition-opacity"
        >
          <i class="i-lucide-external-link text-xs" />
          <span>Abrir na Shopify Admin</span>
        </a>
        <a
          v-if="order.order_status_url"
          :href="order.order_status_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center justify-center gap-1 py-1.5 px-2.5 rounded-lg bg-n-solid-3 text-n-slate-12 font-medium text-xs hover:bg-n-alpha-2 border border-n-weak"
        >
          <i class="i-lucide-eye text-xs" />
          <span>Status Cliente</span>
        </a>
      </div>
    </div>
  </div>
</template>
