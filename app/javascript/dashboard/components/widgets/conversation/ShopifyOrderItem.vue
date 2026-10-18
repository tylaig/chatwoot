<script setup>
import { ref, computed, watch } from 'vue';
import { format } from 'date-fns';
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
  embedded: {
    type: Boolean,
    default: false,
  },
});

const isExpanded = ref(props.defaultExpanded);

watch(
  () => props.defaultExpanded,
  val => {
    isExpanded.value = val;
  }
);

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

const storeMeta = computed(() => {
  const rawName = (
    props.order.store_name ||
    props.order.shop_domain ||
    'Loja Shopify'
  ).trim();
  const domain = (props.order.shop_domain || '').toLowerCase();
  const shortLabel = rawName.split('—')[0].split('(')[0].trim() || rawName;
  const isComBr =
    rawName.toLowerCase().includes('.com.br') || domain.includes('.com.br');
  let suffix = '';
  if (isComBr) {
    suffix = '.com.br';
  } else if (domain.includes('.com')) {
    suffix = '.com';
  }
  return {
    shortLabel,
    suffix,
    fullTitle: `${rawName}${domain ? ` (${domain})` : ''}`,
    isComBr,
  };
});

const financialBadge = computed(() => {
  const status = (props.order.financial_status || 'pending').toLowerCase();
  const map = {
    paid: {
      label: 'Pago',
      icon: 'i-lucide-check-circle-2',
      cls: 'bg-n-teal-3 text-n-teal-11 border-n-teal-6/30',
    },
    pending: {
      label: 'Aguardando Pagto',
      icon: 'i-lucide-clock',
      cls: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6/30',
    },
    authorized: {
      label: 'Autorizado',
      icon: 'i-lucide-shield-check',
      cls: 'bg-n-teal-3 text-n-teal-11 border-n-teal-6/30',
    },
    partially_paid: {
      label: 'Pago Parcial',
      icon: 'i-lucide-pie-chart',
      cls: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6/30',
    },
    refunded: {
      label: 'Reembolsado',
      icon: 'i-lucide-rotate-ccw',
      cls: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6/30',
    },
    partially_refunded: {
      label: 'Reemb. Parcial',
      icon: 'i-lucide-rotate-ccw',
      cls: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6/30',
    },
    voided: {
      label: 'Cancelado',
      icon: 'i-lucide-x-circle',
      cls: 'bg-n-slate-3 text-n-slate-11 border-n-weak',
    },
  };
  return (
    map[status] || {
      label: 'Pendente',
      icon: 'i-lucide-clock',
      cls: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6/30',
    }
  );
});

const fulfillmentBadge = computed(() => {
  const status = (
    props.order.fulfillment_status || 'unfulfilled'
  ).toLowerCase();
  const map = {
    fulfilled: {
      label: 'Entregue',
      icon: 'i-lucide-package-check',
      cls: 'bg-n-teal-3 text-n-teal-11 border-n-teal-6/30',
    },
    partial: {
      label: 'Envio Parcial',
      icon: 'i-lucide-truck',
      cls: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6/30',
    },
    partially_fulfilled: {
      label: 'Envio Parcial',
      icon: 'i-lucide-truck',
      cls: 'bg-n-amber-3 text-n-amber-11 border-n-amber-6/30',
    },
    unfulfilled: {
      label: 'Aguardando Envio',
      icon: 'i-lucide-package',
      cls: 'bg-n-amber-3/70 text-n-amber-11 border-n-amber-6/30',
    },
  };
  return (
    map[status] || {
      label: 'Aguardando Envio',
      icon: 'i-lucide-package',
      cls: 'bg-n-amber-3/70 text-n-amber-11 border-n-amber-6/30',
    }
  );
});

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
  return `Há ${props.order.minutes_since_created}m (< 1h)`;
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
    class="flex flex-col gap-3 transition-all"
    :class="
      embedded
        ? 'pt-1'
        : 'p-3.5 rounded-2xl border border-n-weak bg-n-solid-2 hover:border-n-brand/40 shadow-sm'
    "
  >
    <!-- Topo: Número do Pedido + Valor Total + Loja (quando na sidebar) -->
    <div class="flex items-start justify-between gap-2">
      <div class="flex flex-col gap-1 min-w-0">
        <div class="flex items-center gap-1.5 flex-wrap">
          <a
            :href="order.admin_url"
            target="_blank"
            rel="noopener noreferrer"
            class="font-extrabold text-sm font-mono text-n-slate-12 hover:text-n-brand hover:underline flex items-center gap-1"
            title="Abrir pedido na Shopify"
          >
            <span>{{ orderDisplayTitle }}</span>
            <i class="i-lucide-external-link text-[11px] text-n-slate-10" />
          </a>
          <button
            type="button"
            class="inline-flex items-center justify-center size-5 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            title="Copiar número do pedido"
            @click.stop="copyText(orderDisplayTitle, 'Pedido')"
          >
            <i class="i-lucide-copy text-[11px]" />
          </button>
          <span
            v-if="recentOrderBadge"
            class="inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded-md bg-n-amber-3 text-n-amber-11 font-bold whitespace-nowrap"
          >
            <i class="i-lucide-zap text-[10px]" />
            {{ recentOrderBadge }}
          </span>
        </div>

        <div class="flex items-center gap-1.5 text-[11px] text-n-slate-11">
          <i class="i-lucide-calendar text-[11px] text-n-slate-10 shrink-0" />
          <span>{{ formatDate(order.created_at) }}</span>
        </div>
      </div>

      <div class="flex flex-col items-end gap-1 shrink-0">
        <span class="font-extrabold text-sm text-n-slate-12 tabular-nums">
          {{ formatCurrency(order.total_price, order.currency) }}
        </span>
        <span
          v-if="!embedded && (order.store_name || order.shop_domain)"
          class="inline-flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded-md border whitespace-nowrap"
          :class="
            storeMeta.isComBr
              ? 'bg-n-amber-3/70 text-n-amber-11 border-n-amber-6/30'
              : 'bg-n-brand/10 text-n-brand border-n-brand/20'
          "
          :title="storeMeta.fullTitle"
        >
          <i class="i-lucide-store text-[10px] shrink-0" />
          <span>{{ storeMeta.shortLabel }}</span>
          <span v-if="storeMeta.suffix" class="font-mono opacity-80">
            {{ storeMeta.suffix }}
          </span>
        </span>
      </div>
    </div>

    <!-- Status Claros Separados: Pagamento vs Entrega -->
    <div class="grid grid-cols-2 gap-2">
      <div
        class="flex flex-col gap-0.5 px-2.5 py-1.5 rounded-xl bg-n-alpha-1 border border-n-weak/70"
      >
        <span
          class="text-[10px] uppercase tracking-wider font-semibold text-n-slate-10"
        >
          Pagamento
        </span>
        <div class="flex items-center gap-1.5 mt-0.5">
          <span
            class="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-full border whitespace-nowrap"
            :class="financialBadge.cls"
          >
            <i class="text-[11px] shrink-0" :class="financialBadge.icon" />
            <span>{{ financialBadge.label }}</span>
          </span>
        </div>
      </div>

      <div
        class="flex flex-col gap-0.5 px-2.5 py-1.5 rounded-xl bg-n-alpha-1 border border-n-weak/70"
      >
        <span
          class="text-[10px] uppercase tracking-wider font-semibold text-n-slate-10"
        >
          Entrega
        </span>
        <div class="flex items-center gap-1.5 mt-0.5">
          <span
            class="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-full border whitespace-nowrap"
            :class="fulfillmentBadge.cls"
          >
            <i class="text-[11px] shrink-0" :class="fulfillmentBadge.icon" />
            <span>{{ fulfillmentBadge.label }}</span>
          </span>
        </div>
      </div>
    </div>

    <!-- Lista de Produtos do Pedido -->
    <div v-if="lineItems.length" class="flex flex-col gap-1.5">
      <div
        v-for="item in lineItems"
        :key="item.id"
        class="flex items-center justify-between gap-2.5 p-2 rounded-xl bg-n-surface-1 border border-n-weak/70 text-xs"
      >
        <div class="flex items-center gap-2.5 min-w-0 flex-1">
          <img
            v-if="item.image_url"
            :src="item.image_url"
            :alt="item.title"
            class="size-9 rounded-lg object-cover border border-n-weak bg-n-alpha-2 shrink-0"
            @error="
              $event.target.src = '/dashboard/images/integrations/shopify.png'
            "
          />
          <div
            v-else
            class="flex items-center justify-center size-9 rounded-lg bg-n-brand/10 text-n-brand shrink-0"
          >
            <i class="i-lucide-gamepad-2 text-sm" />
          </div>

          <div class="flex flex-col min-w-0 flex-1">
            <span
              class="font-semibold text-n-slate-12 line-clamp-1 leading-snug"
              :title="item.title"
            >
              {{ item.quantity }}x {{ item.title }}
            </span>
            <div
              class="flex items-center gap-1.5 text-[11px] text-n-slate-10 mt-0.5 truncate"
            >
              <span v-if="item.variant_title" class="truncate">
                {{ item.variant_title }}
              </span>
              <span
                v-if="item.sku"
                class="font-mono text-[10px] text-n-slate-11 shrink-0"
              >
                • {{ item.sku }}
              </span>
            </div>
          </div>
        </div>

        <span
          v-if="item.price"
          class="font-bold text-n-slate-12 shrink-0 text-xs tabular-nums"
        >
          {{ formatCurrency(item.price, order.currency) }}
        </span>
      </div>
    </div>

    <!-- Botão Expandir / Recolher Detalhes Completos -->
    <button
      type="button"
      class="flex items-center justify-between w-full px-3 py-1.5 rounded-xl text-xs font-semibold text-n-slate-11 hover:text-n-slate-12 bg-n-alpha-1 hover:bg-n-alpha-2 border border-n-weak transition-colors"
      @click="toggleExpand"
    >
      <span class="flex items-center gap-1.5">
        <i class="i-lucide-receipt text-xs text-n-brand" />
        <span>
          {{
            isExpanded
              ? 'Ocultar resumo completo'
              : 'Ver cliente, pagamento e envio'
          }}
        </span>
      </span>
      <i
        class="text-xs transition-transform"
        :class="
          isExpanded
            ? 'i-lucide-chevron-up text-n-brand'
            : 'i-lucide-chevron-down'
        "
      />
    </button>

    <!-- Painel Expandido com Todos os Detalhes do Pedido -->
    <div
      v-if="isExpanded"
      class="flex flex-col gap-2.5 p-3 rounded-xl bg-n-surface-1 border border-n-weak text-xs animate-fade-in"
    >
      <!-- Dados do Cliente e Pagamento -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <div
          class="flex flex-col gap-1 p-2.5 rounded-xl bg-n-solid-2 border border-n-weak/60"
        >
          <span
            class="text-[10px] uppercase tracking-wider text-n-slate-10 font-bold flex items-center gap-1"
          >
            <i class="i-lucide-user text-[10px] text-n-brand" />
            Cliente &amp; Contato
          </span>
          <span class="font-semibold text-n-slate-12 truncate">
            {{ order.customer_name || 'Cliente Shopify' }}
          </span>
          <span
            v-if="order.email"
            class="text-[11px] text-n-slate-11 truncate font-mono cursor-pointer hover:text-n-brand"
            title="Clique para copiar o e-mail"
            @click="copyText(order.email, 'E-mail')"
          >
            {{ order.email }}
          </span>
          <span
            v-if="order.phone"
            class="text-[11px] text-n-slate-11 truncate cursor-pointer hover:text-n-brand"
            title="Clique para copiar o telefone"
            @click="copyText(order.phone, 'Telefone')"
          >
            {{ order.phone }}
          </span>
        </div>

        <div
          class="flex flex-col gap-1 p-2.5 rounded-xl bg-n-solid-2 border border-n-weak/60"
        >
          <span
            class="text-[10px] uppercase tracking-wider text-n-slate-10 font-bold flex items-center gap-1"
          >
            <i class="i-lucide-credit-card text-[10px] text-n-brand" />
            Meio &amp; Modalidade
          </span>
          <span class="font-semibold text-n-slate-12 truncate">
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
        class="flex flex-col gap-1 p-2.5 rounded-xl bg-n-solid-2 border border-n-weak/60"
      >
        <div
          class="flex items-center justify-between text-[11px] text-n-slate-11"
        >
          <span>Subtotal dos itens ({{ lineItems.length }})</span>
          <span class="tabular-nums">{{
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
          <span class="tabular-nums">
            {{ `-${formatCurrency(order.total_discounts, order.currency)}` }}
          </span>
        </div>
        <div
          class="flex items-center justify-between text-xs font-bold text-n-slate-12 pt-1.5 mt-0.5 border-t border-n-weak"
        >
          <span>Total do Pedido</span>
          <span class="tabular-nums">{{
            formatCurrency(order.total_price, order.currency)
          }}</span>
        </div>
      </div>

      <!-- Rastreio / Fulfillments -->
      <div
        v-if="fulfillments.length"
        class="flex flex-col gap-1.5 p-2.5 rounded-xl bg-n-solid-2 border border-n-weak/60"
      >
        <span
          class="text-[10px] uppercase tracking-wider text-n-slate-10 font-bold"
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
            class="px-2 py-1 rounded-lg bg-n-brand/10 text-n-brand font-semibold hover:underline shrink-0"
          >
            Rastrear
          </a>
        </div>
      </div>

      <!-- Observações e Tags -->
      <div
        v-if="order.note || orderTags.length"
        class="flex flex-col gap-1.5 p-2.5 rounded-xl bg-n-solid-2 border border-n-weak/60"
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
            class="px-1.5 py-0.5 text-[10px] font-medium rounded-md bg-n-alpha-2 text-n-slate-11 border border-n-weak"
          >
            #{{ tag }}
          </span>
        </div>
      </div>

      <!-- Ações Rápidas -->
      <div class="flex items-center justify-between gap-2 pt-0.5">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-xl bg-n-brand text-white font-semibold text-xs hover:opacity-90 transition-opacity"
        >
          <i class="i-lucide-external-link text-xs" />
          <span>Abrir na Shopify</span>
        </a>
        <a
          v-if="order.order_status_url"
          :href="order.order_status_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center justify-center gap-1 py-1.5 px-2.5 rounded-xl bg-n-solid-3 text-n-slate-12 font-semibold text-xs hover:bg-n-alpha-2 border border-n-weak"
        >
          <i class="i-lucide-eye text-xs" />
          <span>Status Cliente</span>
        </a>
      </div>
    </div>
  </div>
</template>
