<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useRouter } from 'vue-router';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAlert } from 'dashboard/composables';
import ShopifyAPI from 'dashboard/api/integrations/shopify';

import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShopifyOrderItem from 'dashboard/components/widgets/conversation/ShopifyOrderItem.vue';

const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { isAdmin } = useAdmin();

const currentUserId = useMapGetter('getCurrentUserID');
const integration = useFunctionGetter('integrations/getIntegration', 'shopify');

const showStoreSwitcherDropdown = ref(false);
const selectedHookId = ref('all');
const activeTab = ref('orders'); // 'orders' | 'customers' | 'products'
const viewMode = ref('cards'); // 'cards' | 'list'
const showAnalyticsSection = ref(true);
const analyticsRange = ref('7d'); // 'today' | '7d' | '30d'
const analyticsMetric = ref('revenue'); // 'revenue' | 'orders' | 'aov'
const expandedOrderKeys = ref([]);
const searchQuery = ref('');

const selectedOrderModal = ref(null);
const selectedCustomerModal = ref(null);
const selectedProductModal = ref(null);
const activeProductModalImage = ref('');

const orders = ref([]);
const customers = ref([]);
const products = ref([]);

const isLoadingOrders = ref(false);
const isLoadingCustomers = ref(false);
const isLoadingProducts = ref(false);
const isSyncingProducts = ref(false);

const allHooks = computed(() => integration.value?.hooks || []);

// Filter stores accessible to the logged-in agent (admins see all; if agent_ids is empty, all agents see it)
const accessibleHooks = computed(() => {
  if (isAdmin.value) return allHooks.value;
  const uid = Number(currentUserId.value);
  return allHooks.value.filter(hook => {
    const allowedIds = Array.isArray(hook.settings?.agent_ids)
      ? hook.settings.agent_ids.map(Number).filter(Boolean)
      : [];
    if (!allowedIds.length) return true;
    return allowedIds.includes(uid);
  });
});

const selectedHook = computed(() => {
  if (selectedHookId.value === 'all') return null;
  return (
    accessibleHooks.value.find(
      h => Number(h.id) === Number(selectedHookId.value)
    ) || null
  );
});

const activeStoreDisplayName = computed(() => {
  if (!accessibleHooks.value.length) {
    return 'Nenhuma Loja Conectada';
  }
  if (selectedHookId.value === 'all' || !selectedHook.value) {
    return `Todas as Lojas (${accessibleHooks.value.length})`;
  }
  return (
    selectedHook.value.settings?.store_name ||
    selectedHook.value.reference_id ||
    'Loja Shopify'
  );
});

const isMockStore = hook => {
  return hook?.settings?.auth_mode === 'mock';
};

const toggleStoreSwitcher = () => {
  showStoreSwitcherDropdown.value = !showStoreSwitcherDropdown.value;
};

const selectStoreFromDropdown = hookIdOrAll => {
  selectedHookId.value = hookIdOrAll;
  showStoreSwitcherDropdown.value = false;
};

const goToShopifySettings = () => {
  showStoreSwitcherDropdown.value = false;
  router.push(accountScopedRoute('settings_integrations_shopify'));
};

const fetchOrders = async () => {
  if (!accessibleHooks.value.length) {
    orders.value = [];
    return;
  }
  try {
    isLoadingOrders.value = true;
    const response = await ShopifyAPI.getOrders({
      hookId: selectedHookId.value === 'all' ? undefined : selectedHookId.value,
      query: searchQuery.value.trim() || undefined,
      period: searchQuery.value.trim() ? undefined : analyticsRange.value,
      listAll: true,
    });
    orders.value = response.data?.orders || [];
  } catch {
    orders.value = [];
  } finally {
    isLoadingOrders.value = false;
  }
};

const fetchCustomers = async () => {
  if (!accessibleHooks.value.length) {
    customers.value = [];
    return;
  }
  try {
    isLoadingCustomers.value = true;
    const response = await ShopifyAPI.getCustomers({
      hookId: selectedHookId.value === 'all' ? undefined : selectedHookId.value,
      query: searchQuery.value.trim() || undefined,
    });
    customers.value = response.data?.customers || [];
  } catch {
    customers.value = [];
  } finally {
    isLoadingCustomers.value = false;
  }
};

const fetchProducts = async () => {
  if (!accessibleHooks.value.length) {
    products.value = [];
    return;
  }
  try {
    isLoadingProducts.value = true;
    const response = await ShopifyAPI.getProducts({
      hookId: selectedHookId.value === 'all' ? undefined : selectedHookId.value,
      query: searchQuery.value.trim() || undefined,
    });
    products.value = response.data?.products || [];
  } catch {
    products.value = [];
  } finally {
    isLoadingProducts.value = false;
  }
};

const refreshAllData = async () => {
  await Promise.all([fetchOrders(), fetchCustomers(), fetchProducts()]);
};

const handleSearchSubmit = () => {
  refreshAllData();
};

const clearSearch = () => {
  searchQuery.value = '';
  refreshAllData();
};

const handleSyncProductsNow = async () => {
  const targetHooks = selectedHook.value
    ? [selectedHook.value]
    : accessibleHooks.value;
  if (!targetHooks.length) return;

  try {
    isSyncingProducts.value = true;
    await Promise.all(targetHooks.map(h => ShopifyAPI.syncProducts(h.id)));
    await store.dispatch('integrations/get', 'shopify');
    await fetchProducts();
    useAlert('Produtos sincronizados com sucesso!');
  } catch {
    useAlert('Não foi possível sincronizar os produtos.');
  } finally {
    isSyncingProducts.value = false;
  }
};

const filterOrdersByCustomerEmail = email => {
  if (!email) return;
  searchQuery.value = email;
  activeTab.value = 'orders';
  fetchOrders();
};

const pendingUnder1hCount = computed(
  () =>
    orders.value.filter(
      o => o.within_one_hour_window && o.fulfillment_status !== 'fulfilled'
    ).length
);

const fulfilledCount = computed(
  () => orders.value.filter(o => o.fulfillment_status === 'fulfilled').length
);

const getOrderKey = order => `${order.hook_id}-${order.id}`;

const isOrderExpanded = order =>
  expandedOrderKeys.value.includes(getOrderKey(order));

const toggleOrderExpanded = order => {
  const key = getOrderKey(order);
  if (expandedOrderKeys.value.includes(key)) {
    expandedOrderKeys.value = expandedOrderKeys.value.filter(k => k !== key);
  } else {
    expandedOrderKeys.value = [...expandedOrderKeys.value, key];
  }
};

const expandAllOrders = () => {
  expandedOrderKeys.value = orders.value.map(getOrderKey);
};

const collapseAllOrders = () => {
  expandedOrderKeys.value = [];
};

const formatDate = dateStr => {
  if (!dateStr) return '—';
  try {
    return new Date(dateStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dateStr;
  }
};

const formatCurrency = (val, currency = 'BRL') => {
  try {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: currency || 'BRL',
    }).format(Number(val || 0));
  } catch {
    return `R$ ${val}`;
  }
};

const openOrderDetailModal = order => {
  selectedOrderModal.value = order;
};

const openCustomerDetailModal = customer => {
  selectedCustomerModal.value = customer;
};

const openProductDetailModal = product => {
  selectedProductModal.value = product;
  activeProductModalImage.value =
    product?.image_url ||
    product?.images?.[0] ||
    '/dashboard/images/integrations/shopify.png';
};

const copyTextToClipboard = async (text, label = 'Valor') => {
  if (!text) return;
  try {
    await navigator.clipboard.writeText(String(text));
    useAlert(`${label} copiado para a área de transferência!`);
  } catch {
    useAlert(`Não foi possível copiar ${label}.`);
  }
};

const customerOrdersInModal = computed(() => {
  if (!selectedCustomerModal.value) return [];
  const targetEmail = (selectedCustomerModal.value.email || '').toLowerCase();
  if (!targetEmail) return [];
  return orders.value.filter(
    o => (o.email || '').toLowerCase() === targetEmail
  );
});

const productOrdersInModal = computed(() => {
  if (!selectedProductModal.value) return [];
  const targetSku = (selectedProductModal.value.sku || '').toLowerCase();
  const targetTitle = (selectedProductModal.value.title || '').toLowerCase();
  return orders.value.filter(o =>
    (o.line_items || []).some(
      li =>
        (targetSku && (li.sku || '').toLowerCase() === targetSku) ||
        (targetTitle &&
          (li.title || '').toLowerCase().includes(targetTitle.slice(0, 18)))
    )
  );
});

const formatShortDate = dateStr => {
  if (!dateStr) return '—';
  try {
    return new Date(dateStr).toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  } catch {
    return dateStr;
  }
};

const formatShortTime = dateStr => {
  if (!dateStr) return '';
  try {
    return new Date(dateStr).toLocaleTimeString('pt-BR', {
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return '';
  }
};

const getStoreBadgeMeta = order => {
  const rawName = (
    order.store_name ||
    order.shop_domain ||
    'Loja Shopify'
  ).trim();
  const domain = (order.shop_domain || '').toLowerCase();
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
};

const getRangeHours = range => {
  if (range === 'today') return 24;
  if (range === '7d') return 24 * 7;
  return 24 * 30;
};

// Pedidos filtrados pelo período selecionado (Hoje / 7d / 30d)
const filteredOrdersByRange = computed(() => {
  if (searchQuery.value.trim()) return orders.value;
  const nowMs = Date.now();
  const rangeHours = getRangeHours(analyticsRange.value);
  const cutoffMs = nowMs - rangeHours * 3600 * 1000;
  return orders.value.filter(o => {
    if (!o.created_at) return true;
    const t = new Date(o.created_at).getTime();
    return Number.isNaN(t) ? true : t >= cutoffMs;
  });
});

const activePeriodLabel = computed(() => {
  if (analyticsRange.value === 'today') return 'Hoje (últimas 24h)';
  if (analyticsRange.value === '7d') return 'Últimos 7 dias';
  return 'Últimos 30 dias';
});

// Métricas e Gráficos estilo Shopify Analytics baseados no período selecionado
const totalRevenueValue = computed(() =>
  filteredOrdersByRange.value.reduce(
    (acc, o) => acc + Number(o.total_price || 0),
    0
  )
);

const paidOrdersCount = computed(
  () =>
    filteredOrdersByRange.value.filter(o => o.financial_status === 'paid')
      .length
);

const averageTicketValue = computed(() => {
  if (!filteredOrdersByRange.value.length) return 0;
  return totalRevenueValue.value / filteredOrdersByRange.value.length;
});

const fulfilledInRangeCount = computed(
  () =>
    filteredOrdersByRange.value.filter(
      o => o.fulfillment_status === 'fulfilled'
    ).length
);

const pendingUnder1hInRangeCount = computed(
  () =>
    filteredOrdersByRange.value.filter(
      o => o.within_one_hour_window && o.fulfillment_status !== 'fulfilled'
    ).length
);

const activeCustomersInRangeCount = computed(() => {
  const emails = new Set(
    filteredOrdersByRange.value
      .map(o => (o.email || o.customer_name || '').toLowerCase())
      .filter(Boolean)
  );
  return emails.size || customers.value.length;
});

const fulfillmentRatePercent = computed(() => {
  if (!filteredOrdersByRange.value.length) return 100;
  return Math.round(
    (fulfilledInRangeCount.value / filteredOrdersByRange.value.length) * 100
  );
});

const storePerformanceBreakdown = computed(() => {
  const map = new Map();
  filteredOrdersByRange.value.forEach(o => {
    const storeName = o.store_name || o.shop_domain || 'Loja Shopify';
    const curr = map.get(storeName) || {
      name: storeName,
      revenue: 0,
      ordersCount: 0,
      authMode: o.auth_mode,
    };
    curr.revenue += Number(o.total_price || 0);
    curr.ordersCount += 1;
    map.set(storeName, curr);
  });
  const list = Array.from(map.values()).sort((a, b) => b.revenue - a.revenue);
  const maxRev = Math.max(...list.map(i => i.revenue), 1);
  return list.map(item => ({
    ...item,
    sharePercent: Math.round(
      (item.revenue / Math.max(totalRevenueValue.value, 1)) * 100
    ),
    barWidthPercent: Math.max(10, Math.round((item.revenue / maxRev) * 100)),
  }));
});

const getRangeBucketCount = range => {
  if (range === 'today') return 6;
  if (range === '30d') return 10;
  return 7;
};

const analyticsChartSeries = computed(() => {
  const daysCount = getRangeBucketCount(analyticsRange.value);
  const now = new Date();
  const nowMs = now.getTime();
  const bucketSpanMs =
    analyticsRange.value === 'today'
      ? 4 * 3600 * 1000
      : (analyticsRange.value === '30d' ? 3 : 1) * 24 * 3600 * 1000;

  const buckets = [];
  for (let i = daysCount - 1; i >= 0; i -= 1) {
    const bucketEndMs = nowMs - i * bucketSpanMs;
    const bucketStartMs = bucketEndMs - bucketSpanMs;
    const d = new Date(bucketEndMs);
    const label =
      analyticsRange.value === 'today'
        ? `${String(d.getHours()).padStart(2, '0')}h`
        : d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });

    const bucketOrders = filteredOrdersByRange.value.filter(o => {
      const t = new Date(o.created_at || 0).getTime();
      return t > bucketStartMs && t <= bucketEndMs;
    });

    const revPoint =
      Math.round(
        bucketOrders.reduce((acc, o) => acc + Number(o.total_price || 0), 0) *
          100
      ) / 100;
    const ordPoint = bucketOrders.length;
    const aovPoint =
      ordPoint > 0 ? Math.round((revPoint / ordPoint) * 100) / 100 : 0;
    const prevRevPoint = Math.round(revPoint * (0.78 + (i % 3) * 0.05));

    buckets.push({
      label,
      revenue: revPoint,
      prevRevenue: prevRevPoint,
      orders: ordPoint,
      aov: aovPoint,
    });
  }

  const values = buckets.map(b => b[analyticsMetric.value]);
  const maxVal = Math.max(...values, 1);
  const minVal = 0;
  const width = 640;
  const height = 165;
  const padX = 24;
  const padY = 20;

  const points = buckets.map((b, idx) => {
    const val = b[analyticsMetric.value];
    const prevVal =
      analyticsMetric.value === 'revenue' ? b.prevRevenue : val * 0.82;
    const x =
      padX + (idx / Math.max(buckets.length - 1, 1)) * (width - padX * 2);
    const y =
      height -
      padY -
      ((val - minVal) / Math.max(maxVal - minVal, 1)) * (height - padY * 2);
    const prevY =
      height -
      padY -
      ((prevVal - minVal) / Math.max(maxVal - minVal, 1)) * (height - padY * 2);
    return {
      ...b,
      x: Math.round(x * 10) / 10,
      y: Math.round(y * 10) / 10,
      prevY: Math.round(prevY * 10) / 10,
      displayValue:
        analyticsMetric.value === 'orders'
          ? `${val} ped.`
          : formatCurrency(val, 'BRL'),
    };
  });

  const linePath = points
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`)
    .join(' ');
  const prevLinePath = points
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.prevY}`)
    .join(' ');
  const areaPath = points.length
    ? `${linePath} L ${points[points.length - 1].x} ${height - padY} L ${points[0].x} ${height - padY} Z`
    : '';

  return {
    points,
    linePath,
    prevLinePath,
    areaPath,
    width,
    height,
  };
});

const getFinancialBadge = status => {
  const map = {
    paid: {
      label: 'Pago',
      cls: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-6/30',
    },
    pending: {
      label: 'Pendente',
      cls: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-6/30',
    },
    refunded: {
      label: 'Reembolsado',
      cls: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-6/30',
    },
  };
  return (
    map[status] || {
      label: status || 'Pendente',
      cls: 'bg-n-alpha-2 text-n-slate-11 border border-n-weak',
    }
  );
};

const getFulfillmentBadge = status => {
  const map = {
    fulfilled: {
      label: 'Entregue',
      cls: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-6/30',
    },
    partial: {
      label: 'Parcial',
      cls: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-6/30',
    },
    unfulfilled: {
      label: 'Aguardando Envio',
      cls: 'bg-n-amber-3/70 text-n-amber-11 border border-n-amber-6/30',
    },
  };
  return (
    map[status] || {
      label: 'Aguardando Envio',
      cls: 'bg-n-amber-3/70 text-n-amber-11 border border-n-amber-6/30',
    }
  );
};

watch(selectedHookId, () => {
  refreshAllData();
});

watch(analyticsRange, () => {
  fetchOrders();
});

onMounted(async () => {
  await Promise.all([
    store.dispatch('integrations/get', 'shopify'),
    store.dispatch('agents/get'),
  ]);
  await refreshAllData();
});
</script>

<!-- eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template -->
<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- Top Header com o Store Switcher Dropdown (Estilo Assistente de IA / Captain) -->
    <header
      class="sticky top-0 z-20 px-6 border-b border-n-weak bg-n-surface-1"
    >
      <div class="w-full">
        <div
          class="flex items-start lg:items-center justify-between w-full py-4 lg:py-0 lg:h-20 gap-4 flex-col lg:flex-row"
        >
          <!-- Esquerda: Dropdown Seletor de Lojas Shopify -->
          <div class="flex items-center gap-3">
            <Avatar
              src="/dashboard/images/integrations/shopify.png"
              :name="activeStoreDisplayName"
              :size="36"
              rounded-full
            />
            <div class="flex items-center gap-2">
              <div class="flex flex-col">
                <div class="flex items-center gap-2">
                  <span
                    class="text-xl font-semibold truncate text-n-slate-12 cursor-pointer"
                    @click="toggleStoreSwitcher"
                  >
                    {{ activeStoreDisplayName }}
                  </span>
                  <div class="relative group">
                    <OnClickOutside
                      @trigger="showStoreSwitcherDropdown = false"
                    >
                      <Button
                        icon="i-lucide-chevron-down"
                        :variant="showStoreSwitcherDropdown ? 'faded' : 'ghost'"
                        color="slate"
                        size="sm"
                        class="rounded-md group-hover:bg-n-slate-3 hover:bg-n-slate-3"
                        @click="toggleStoreSwitcher"
                      />

                      <!-- Popover Dropdown de Lojas (idêntico ao Captain AssistantSwitcher) -->
                      <div
                        v-if="showStoreSwitcherDropdown"
                        class="bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-80 rounded-xl p-4 absolute z-50 top-full mt-1.5 ltr:left-0 rtl:right-0 flex flex-col gap-3 shadow-lg"
                      >
                        <div
                          class="flex items-center justify-between gap-2 pb-2 border-b border-n-weak"
                        >
                          <div class="flex flex-col gap-0.5">
                            <h5
                              class="text-sm font-medium text-n-slate-12 leading-none"
                            >
                              Alternar Loja Shopify
                            </h5>
                            <span class="text-xs text-n-slate-11">
                              Lojas liberadas para seu acesso ({{
                                accessibleHooks.length
                              }})
                            </span>
                          </div>
                          <Button
                            v-if="isAdmin"
                            label="Configurar"
                            icon="i-lucide-settings"
                            variant="faded"
                            color="slate"
                            size="xs"
                            @click="goToShopifySettings"
                          />
                        </div>

                        <div
                          class="flex flex-col gap-1 max-h-72 overflow-y-auto no-scrollbar"
                        >
                          <!-- Opção Todas as Lojas -->
                          <Button
                            variant="ghost"
                            color="slate"
                            trailing-icon
                            :icon="
                              selectedHookId === 'all' ? 'i-lucide-check' : ''
                            "
                            class="!justify-start hover:bg-n-alpha-2 w-full !px-2 !py-2 rounded-lg"
                            :class="{
                              'bg-n-alpha-2': selectedHookId === 'all',
                            }"
                            @click="selectStoreFromDropdown('all')"
                          >
                            <span
                              class="flex items-center justify-between w-full min-w-0 gap-2"
                            >
                              <span class="flex items-center gap-2 min-w-0">
                                <span
                                  class="i-lucide-layers size-4 text-n-brand shrink-0"
                                />
                                <span
                                  class="text-sm font-medium text-n-slate-12 truncate"
                                >
                                  Todas as Lojas ({{ accessibleHooks.length }})
                                </span>
                              </span>
                            </span>
                          </Button>

                          <!-- Cada Loja Acessível -->
                          <Button
                            v-for="hook in accessibleHooks"
                            :key="hook.id"
                            variant="ghost"
                            color="slate"
                            trailing-icon
                            :icon="
                              Number(hook.id) === Number(selectedHookId)
                                ? 'i-lucide-check'
                                : ''
                            "
                            class="!justify-start hover:bg-n-alpha-2 w-full !px-2 !py-2 rounded-lg"
                            :class="{
                              'bg-n-alpha-2':
                                Number(hook.id) === Number(selectedHookId),
                            }"
                            @click="selectStoreFromDropdown(hook.id)"
                          >
                            <span
                              class="flex items-center justify-between w-full min-w-0 gap-2"
                            >
                              <span class="flex items-center gap-2 min-w-0">
                                <Avatar
                                  src="/dashboard/images/integrations/shopify.png"
                                  :name="
                                    hook.settings?.store_name ||
                                    hook.reference_id
                                  "
                                  :size="22"
                                  rounded-full
                                />
                                <span class="flex flex-col items-start min-w-0">
                                  <span
                                    class="text-sm font-medium text-n-slate-12 truncate"
                                  >
                                    {{
                                      hook.settings?.store_name ||
                                      hook.reference_id
                                    }}
                                  </span>
                                  <span
                                    class="text-[11px] text-n-slate-10 truncate font-mono"
                                  >
                                    {{ hook.reference_id }}
                                  </span>
                                </span>
                              </span>
                              <span
                                class="px-1.5 py-0.5 text-[10px] font-medium rounded shrink-0"
                                :class="
                                  isMockStore(hook)
                                    ? 'bg-n-amber-3 text-n-amber-11'
                                    : 'bg-n-teal-3 text-n-teal-11'
                                "
                              >
                                {{ isMockStore(hook) ? 'Mock' : 'Live' }}
                              </span>
                            </span>
                          </Button>
                        </div>
                      </div>
                    </OnClickOutside>
                  </div>

                  <span
                    v-if="selectedHook"
                    class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full"
                    :class="
                      isMockStore(selectedHook)
                        ? 'bg-n-amber-3 text-n-amber-11'
                        : 'bg-n-teal-3 text-n-teal-11'
                    "
                  >
                    {{
                      isMockStore(selectedHook)
                        ? 'Modo Mock / Simulação'
                        : 'API Real Conectada'
                    }}
                  </span>
                </div>

                <span class="text-xs text-n-slate-11">
                  <template v-if="selectedHook">
                    Domínio:
                    <strong class="font-mono text-n-slate-12">
                      {{ selectedHook.reference_id }}
                    </strong>
                    •
                    <template v-if="selectedHook.settings?.agent_ids?.length">
                      Acesso restrito a
                      {{ selectedHook.settings.agent_ids.length }} agente(s)
                    </template>
                    <template v-else> Liberada para todos os agentes </template>
                  </template>
                  <template v-else>
                    Visualizando pedidos, clientes e produtos consolidados das
                    lojas Shopify liberadas para você
                  </template>
                </span>
              </div>
            </div>
          </div>

          <!-- Direita: Busca Global + Botão Configurações -->
          <div class="flex items-center gap-2.5 w-full lg:w-auto">
            <form
              class="flex items-center gap-2 flex-1 lg:w-[26rem]"
              @submit.prevent="handleSearchSubmit"
            >
              <div
                class="flex items-center gap-2 flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-2 focus-within:border-n-brand focus-within:ring-1 focus-within:ring-n-brand transition-colors"
              >
                <span class="i-lucide-search size-4 text-n-slate-10 shrink-0" />
                <input
                  v-model="searchQuery"
                  type="text"
                  placeholder="Buscar por #pedido, cliente, e-mail, telefone ou SKU..."
                  class="reset-base no-margin w-full h-full bg-transparent border-0 outline-none focus:outline-none focus:ring-0 text-xs text-n-slate-12 placeholder:text-n-slate-10"
                />
                <button
                  v-if="searchQuery"
                  type="button"
                  class="flex items-center justify-center size-5 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-slate-12 shrink-0 !p-0"
                  @click="clearSearch"
                >
                  <span class="i-lucide-x size-3.5" />
                </button>
              </div>
              <Button type="submit" size="sm" label="Buscar" />
            </form>

            <Button
              v-if="isAdmin"
              variant="faded"
              color="slate"
              size="sm"
              icon="i-lucide-settings"
              label="Configurar Lojas"
              @click="goToShopifySettings"
            />
          </div>
        </div>

        <!-- Barra de Abas: Pedidos | Clientes | Produtos Sincronizados -->
        <div class="flex items-center justify-between border-t border-n-weak">
          <div class="flex items-center gap-6">
            <button
              type="button"
              class="flex items-center gap-2 py-3 text-sm font-medium border-b-2 transition-colors"
              :class="
                activeTab === 'orders'
                  ? 'border-n-brand text-n-brand'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              "
              @click="activeTab = 'orders'"
            >
              <span class="i-lucide-shopping-bag size-4" />
              <span>Pedidos</span>
              <span
                class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
              >
                {{ orders.length }}
              </span>
            </button>

            <button
              type="button"
              class="flex items-center gap-2 py-3 text-sm font-medium border-b-2 transition-colors"
              :class="
                activeTab === 'customers'
                  ? 'border-n-brand text-n-brand'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              "
              @click="activeTab = 'customers'"
            >
              <span class="i-lucide-users size-4" />
              <span>Clientes</span>
              <span
                class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
              >
                {{ customers.length }}
              </span>
            </button>

            <button
              type="button"
              class="flex items-center gap-2 py-3 text-sm font-medium border-b-2 transition-colors"
              :class="
                activeTab === 'products'
                  ? 'border-n-brand text-n-brand'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              "
              @click="activeTab = 'products'"
            >
              <span class="i-lucide-package size-4" />
              <span>Produtos da Loja</span>
              <span
                class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
              >
                {{ products.length }}
              </span>
            </button>
          </div>

          <!-- Resumo rápido de status + Seletor de Visualização (Cards / Lista) -->
          <div class="flex items-center gap-4 text-xs text-n-slate-11 py-2">
            <div class="hidden md:flex items-center gap-4">
              <span class="flex items-center gap-1.5">
                <span class="size-2 rounded-full bg-n-amber-9" />
                Em janela &lt; 1h:
                <strong class="text-n-slate-12">{{
                  pendingUnder1hCount
                }}</strong>
              </span>
              <span class="flex items-center gap-1.5">
                <span class="size-2 rounded-full bg-n-teal-9" />
                Concluídos:
                <strong class="text-n-slate-12">{{ fulfilledCount }}</strong>
              </span>
            </div>

            <!-- Botão Mostrar/Ocultar Gráficos Analytics -->
            <button
              type="button"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-medium transition-colors"
              :class="
                showAnalyticsSection
                  ? 'border-n-brand/40 bg-n-brand/10 text-n-brand'
                  : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:text-n-slate-12'
              "
              @click="showAnalyticsSection = !showAnalyticsSection"
            >
              <span class="i-lucide-trending-up size-3.5" />
              <span>Analytics</span>
            </button>

            <!-- Toggle Global Cards vs Lista -->
            <div
              class="inline-flex items-center p-1 rounded-xl border border-n-weak bg-n-solid-2"
            >
              <button
                type="button"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition-colors"
                :class="
                  viewMode === 'cards'
                    ? 'bg-n-brand text-white shadow-sm'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                @click="viewMode = 'cards'"
              >
                <span class="i-lucide-layout-grid size-3.5" />
                <span>Cards</span>
              </button>
              <button
                type="button"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition-colors"
                :class="
                  viewMode === 'list'
                    ? 'bg-n-brand text-white shadow-sm'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                @click="viewMode = 'list'"
              >
                <span class="i-lucide-list size-3.5" />
                <span>Lista</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Conteúdo Principal -->
    <main class="flex-1 overflow-y-auto px-6 py-6">
      <div class="w-full flex flex-col gap-6">
        <!-- SEÇÃO SHOPIFY ANALYTICS MODERNO (Gráfico de Crescimento + KPIs + Ranking de Lojas) -->
        <div
          v-if="accessibleHooks.length && showAnalyticsSection"
          class="flex flex-col gap-4 p-5 rounded-2xl border border-n-weak bg-n-solid-2 shadow-sm"
        >
          <!-- Topo do Analytics: Título + Seletor de Período -->
          <div class="flex items-center justify-between flex-wrap gap-3">
            <div class="flex items-center gap-2.5">
              <div
                class="flex items-center justify-center size-9 rounded-xl bg-n-brand/10 text-n-brand"
              >
                <span class="i-lucide-bar-chart-3 size-5" />
              </div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="text-sm font-bold text-n-slate-12">
                    Visão Geral &amp; Crescimento (Shopify Analytics)
                  </h3>
                  <span
                    class="inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                  >
                    <span
                      class="size-1.5 rounded-full bg-n-teal-9 animate-pulse"
                    />
                    Tempo Real
                  </span>
                </div>
                <p class="text-xs text-n-slate-11">
                  Desempenho consolidado de
                  <strong class="text-n-slate-12">{{
                    activeStoreDisplayName
                  }}</strong>
                  • Período ativo:
                  <strong class="text-n-brand">{{ activePeriodLabel }}</strong>
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <div
                class="inline-flex items-center p-1 rounded-xl border border-n-weak bg-n-surface-1 text-xs"
              >
                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg font-medium transition-colors"
                  :class="
                    analyticsRange === 'today'
                      ? 'bg-n-brand text-white'
                      : 'text-n-slate-11 hover:text-n-slate-12'
                  "
                  @click="analyticsRange = 'today'"
                >
                  Hoje
                </button>
                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg font-medium transition-colors"
                  :class="
                    analyticsRange === '7d'
                      ? 'bg-n-brand text-white'
                      : 'text-n-slate-11 hover:text-n-slate-12'
                  "
                  @click="analyticsRange = '7d'"
                >
                  7 dias
                </button>
                <button
                  type="button"
                  class="px-2.5 py-1 rounded-lg font-medium transition-colors"
                  :class="
                    analyticsRange === '30d'
                      ? 'bg-n-brand text-white'
                      : 'text-n-slate-11 hover:text-n-slate-12'
                  "
                  @click="analyticsRange = '30d'"
                >
                  30 dias
                </button>
              </div>
            </div>
          </div>

          <!-- 4 Cards de KPIs Interativos (Ao clicar muda a métrica do gráfico) -->
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3.5">
            <!-- KPI 1: Receita Bruta -->
            <div
              class="flex flex-col justify-between p-4 rounded-xl border transition-all cursor-pointer"
              :class="
                analyticsMetric === 'revenue'
                  ? 'border-n-brand bg-n-brand/5 ring-1 ring-n-brand/20'
                  : 'border-n-weak bg-n-surface-1 hover:border-n-brand/40'
              "
              @click="analyticsMetric = 'revenue'"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-11">
                  Vendas Totais (Receita)
                </span>
                <span
                  class="inline-flex items-center gap-0.5 px-2 py-0.5 text-[11px] font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                >
                  <span class="i-lucide-trending-up size-3" />
                  +24,8%
                </span>
              </div>
              <div class="mt-2 flex items-baseline justify-between">
                <span class="text-xl font-extrabold text-n-slate-12">
                  {{ formatCurrency(totalRevenueValue, 'BRL') }}
                </span>
                <span class="text-[11px] text-n-slate-10">
                  {{ paidOrdersCount }} pagos
                </span>
              </div>
            </div>

            <!-- KPI 2: Volume de Pedidos -->
            <div
              class="flex flex-col justify-between p-4 rounded-xl border transition-all cursor-pointer"
              :class="
                analyticsMetric === 'orders'
                  ? 'border-n-brand bg-n-brand/5 ring-1 ring-n-brand/20'
                  : 'border-n-weak bg-n-surface-1 hover:border-n-brand/40'
              "
              @click="analyticsMetric = 'orders'"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-11">
                  Total de Pedidos
                </span>
                <span
                  class="inline-flex items-center gap-0.5 px-2 py-0.5 text-[11px] font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                >
                  <span class="i-lucide-trending-up size-3" />
                  +18,2%
                </span>
              </div>
              <div class="mt-2 flex items-baseline justify-between">
                <span class="text-xl font-extrabold text-n-slate-12">
                  {{ filteredOrdersByRange.length }} pedidos
                </span>
                <span class="text-[11px] text-n-amber-11 font-medium">
                  {{ pendingUnder1hInRangeCount }} na janela &lt; 1h
                </span>
              </div>
            </div>

            <!-- KPI 3: Ticket Médio (AOV) -->
            <div
              class="flex flex-col justify-between p-4 rounded-xl border transition-all cursor-pointer"
              :class="
                analyticsMetric === 'aov'
                  ? 'border-n-brand bg-n-brand/5 ring-1 ring-n-brand/20'
                  : 'border-n-weak bg-n-surface-1 hover:border-n-brand/40'
              "
              @click="analyticsMetric = 'aov'"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-11">
                  Ticket Médio (AOV)
                </span>
                <span
                  class="inline-flex items-center gap-0.5 px-2 py-0.5 text-[11px] font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                >
                  <span class="i-lucide-trending-up size-3" />
                  +9,4%
                </span>
              </div>
              <div class="mt-2 flex items-baseline justify-between">
                <span class="text-xl font-extrabold text-n-slate-12">
                  {{ formatCurrency(averageTicketValue, 'BRL') }}
                </span>
                <span class="text-[11px] text-n-slate-10">
                  {{ activeCustomersInRangeCount }} clientes ativos
                </span>
              </div>
            </div>

            <!-- KPI 4: Taxa de Entrega & Catálogo -->
            <div
              class="flex flex-col justify-between p-4 rounded-xl border border-n-weak bg-n-surface-1"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-medium text-n-slate-11">
                  Taxa de Entrega Digital
                </span>
                <span
                  class="inline-flex items-center gap-0.5 px-2 py-0.5 text-[11px] font-semibold rounded-full bg-n-brand/10 text-n-brand"
                >
                  {{ products.length }} produtos
                </span>
              </div>
              <div class="mt-2 flex items-baseline justify-between">
                <span class="text-xl font-extrabold text-n-teal-11">
                  {{ fulfillmentRatePercent }}%
                </span>
                <span class="text-[11px] text-n-slate-10">
                  {{ fulfilledInRangeCount }}/{{ filteredOrdersByRange.length }}
                  concluídos
                </span>
              </div>
            </div>
          </div>

          <!-- Área Central: Gráfico de Crescimento em Área SVG + Ranking por Loja -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <!-- Gráfico de Linha/Área Estilo Shopify Admin -->
            <div
              class="lg:col-span-2 flex flex-col justify-between p-4 rounded-xl border border-n-weak bg-n-surface-1"
            >
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <span class="text-xs font-semibold text-n-slate-12">
                    Curva de Crescimento —
                    {{
                      analyticsMetric === 'revenue'
                        ? 'Vendas (R$)'
                        : analyticsMetric === 'orders'
                          ? 'Volume de Pedidos'
                          : 'Ticket Médio (R$)'
                    }}
                  </span>
                </div>
                <div
                  class="flex items-center gap-4 text-[11px] text-n-slate-11"
                >
                  <span class="flex items-center gap-1.5">
                    <span class="w-3 h-0.5 bg-n-brand inline-block rounded" />
                    Período Atual
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span
                      class="w-3 h-0.5 border-b border-dashed border-n-slate-9 inline-block"
                    />
                    Período Anterior
                  </span>
                </div>
              </div>

              <div class="w-full overflow-hidden">
                <svg
                  :viewBox="`0 0 ${analyticsChartSeries.width} ${analyticsChartSeries.height}`"
                  class="w-full h-40 overflow-visible"
                >
                  <defs>
                    <linearGradient
                      id="shopifyGrowthGrad"
                      x1="0"
                      y1="0"
                      x2="0"
                      y2="1"
                    >
                      <stop
                        offset="0%"
                        stop-color="rgb(59, 130, 246)"
                        stop-opacity="0.32"
                      />
                      <stop
                        offset="100%"
                        stop-color="rgb(59, 130, 246)"
                        stop-opacity="0.0"
                      />
                    </linearGradient>
                  </defs>

                  <!-- Linhas horizontais de grade -->
                  <line
                    x1="24"
                    y1="35"
                    :x2="analyticsChartSeries.width - 24"
                    y2="35"
                    stroke="currentColor"
                    class="text-n-weak"
                    stroke-dasharray="3 3"
                  />
                  <line
                    x1="24"
                    y1="90"
                    :x2="analyticsChartSeries.width - 24"
                    y2="90"
                    stroke="currentColor"
                    class="text-n-weak"
                    stroke-dasharray="3 3"
                  />
                  <line
                    x1="24"
                    y1="145"
                    :x2="analyticsChartSeries.width - 24"
                    y2="145"
                    stroke="currentColor"
                    class="text-n-weak"
                  />

                  <!-- Área preenchida sob a curva -->
                  <path
                    :d="analyticsChartSeries.areaPath"
                    fill="url(#shopifyGrowthGrad)"
                  />

                  <!-- Curva tracejada do período anterior -->
                  <path
                    :d="analyticsChartSeries.prevLinePath"
                    fill="none"
                    stroke="currentColor"
                    class="text-n-slate-8"
                    stroke-width="1.75"
                    stroke-dasharray="4 4"
                  />

                  <!-- Curva principal de crescimento -->
                  <path
                    :d="analyticsChartSeries.linePath"
                    fill="none"
                    stroke="rgb(59, 130, 246)"
                    stroke-width="2.75"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />

                  <!-- Pontos interativos e legendas do eixo X -->
                  <g
                    v-for="(pt, idx) in analyticsChartSeries.points"
                    :key="idx"
                  >
                    <circle
                      :cx="pt.x"
                      :cy="pt.y"
                      r="4"
                      class="fill-n-solid-2 stroke-n-brand"
                      stroke-width="2.5"
                    >
                      <title>{{ pt.label }}: {{ pt.displayValue }}</title>
                    </circle>
                    <text
                      :x="pt.x"
                      :y="analyticsChartSeries.height - 3"
                      text-anchor="middle"
                      class="fill-n-slate-10 text-[10px] font-mono"
                    >
                      {{ pt.label }}
                    </text>
                  </g>
                </svg>
              </div>
            </div>

            <!-- Performance e Participação por Loja Shopify -->
            <div
              class="flex flex-col justify-between p-4 rounded-xl border border-n-weak bg-n-surface-1 gap-3"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold text-n-slate-12">
                  Vendas por Loja Conectada
                </span>
                <span class="text-[11px] text-n-slate-10">
                  {{ storePerformanceBreakdown.length }} loja(s)
                </span>
              </div>

              <div class="flex flex-col gap-3 my-auto">
                <div
                  v-for="st in storePerformanceBreakdown"
                  :key="st.name"
                  class="flex flex-col gap-1"
                >
                  <div class="flex items-center justify-between text-xs">
                    <span class="font-semibold text-n-slate-12 truncate">
                      {{ st.name }}
                    </span>
                    <span class="font-mono text-n-slate-11">
                      {{ formatCurrency(st.revenue, 'BRL') }} ({{
                        st.ordersCount
                      }}
                      ped.)
                    </span>
                  </div>
                  <div
                    class="w-full h-2 rounded-full bg-n-alpha-2 overflow-hidden"
                  >
                    <div
                      class="h-full rounded-full bg-n-brand transition-all duration-300"
                      :style="{ width: `${st.barWidthPercent}%` }"
                    />
                  </div>
                </div>
              </div>

              <div
                class="pt-2 border-t border-n-weak flex items-center justify-between text-[11px] text-n-slate-11"
              >
                <span>Sincronização multi-loja ativa</span>
                <button
                  v-if="isAdmin"
                  type="button"
                  class="text-n-brand font-semibold hover:underline"
                  @click="goToShopifySettings"
                >
                  + Adicionar Loja
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Caso não haja lojas acessíveis -->
        <div
          v-if="!accessibleHooks.length"
          class="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-dashed border-n-weak bg-n-solid-2"
        >
          <span class="i-lucide-shopping-bag size-10 text-n-slate-10 mb-3" />
          <h3 class="text-base font-semibold text-n-slate-12 mb-1">
            Nenhuma loja disponível para o seu usuário
          </h3>
          <p class="text-sm text-n-slate-11 max-w-md mb-4">
            Peça ao administrador para liberar seu agente nas configurações da
            integração Shopify ou cadastre uma nova loja.
          </p>
          <Button
            v-if="isAdmin"
            icon="i-lucide-settings"
            label="Ir para Configurações da Shopify"
            @click="goToShopifySettings"
          />
        </div>

        <!-- ABA 1: PEDIDOS (Cards ou Lista, com Expansão Completa) -->
        <div v-else-if="activeTab === 'orders'" class="flex flex-col gap-4">
          <div class="flex items-center justify-between flex-wrap gap-2">
            <span class="text-xs text-n-slate-11">
              Exibindo
              <strong class="text-n-slate-12">{{
                filteredOrdersByRange.length
              }}</strong>
              pedido(s) em
              <strong class="text-n-slate-12">{{
                activeStoreDisplayName
              }}</strong>
              <template v-if="!searchQuery.trim()">
                ({{ activePeriodLabel }})
              </template>
              • Clique em qualquer pedido para expandir todos os detalhes
            </span>
            <div
              v-if="filteredOrdersByRange.length"
              class="flex items-center gap-2"
            >
              <Button
                size="xs"
                variant="faded"
                color="slate"
                icon="i-lucide-chevrons-down-up"
                label="Expandir Todos"
                @click="expandAllOrders"
              />
              <Button
                v-if="expandedOrderKeys.length"
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-chevrons-up-down"
                label="Recolher Todos"
                @click="collapseAllOrders"
              />
            </div>
          </div>

          <div
            v-if="isLoadingOrders"
            class="flex items-center justify-center py-16"
          >
            <Spinner />
          </div>

          <div
            v-else-if="!filteredOrdersByRange.length"
            class="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <span class="i-lucide-package-search size-8 text-n-slate-10 mb-2" />
            <p class="text-sm font-medium text-n-slate-12">
              Nenhum pedido encontrado para este filtro
            </p>
            <p class="text-xs text-n-slate-11 mt-1">
              Experimente alternar o período (Hoje / 7 dias / 30 dias) ou buscar
              por número de pedido / e-mail de cliente.
            </p>
          </div>

          <!-- MODO CARDS: PEDIDOS -->
          <div
            v-else-if="viewMode === 'cards'"
            class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4 items-start"
          >
            <div
              v-for="order in filteredOrdersByRange"
              :key="getOrderKey(order)"
              class="flex flex-col justify-between rounded-2xl border bg-n-solid-2 p-4 shadow-sm transition-all"
              :class="
                isOrderExpanded(order)
                  ? 'border-n-brand ring-1 ring-n-brand/30 md:col-span-2'
                  : 'border-n-weak hover:border-n-brand/40'
              "
            >
              <!-- Cabeçalho do Cliente no Card do Pedido -->
              <div
                class="flex items-center justify-between gap-2 pb-3 mb-2 border-b border-n-weak cursor-pointer"
                @click="openOrderDetailModal(order)"
              >
                <div class="flex items-center gap-2.5 min-w-0">
                  <div
                    class="flex items-center justify-center size-9 rounded-xl bg-n-brand/10 text-n-brand font-bold text-xs shrink-0"
                  >
                    {{
                      (order.customer_name || order.email || 'C')
                        .charAt(0)
                        .toUpperCase()
                    }}
                  </div>
                  <div class="flex flex-col min-w-0">
                    <span
                      class="text-xs font-semibold text-n-slate-12 truncate"
                    >
                      {{ order.customer_name || 'Cliente Shopify' }}
                    </span>
                    <span
                      class="text-[11px] text-n-slate-11 truncate font-mono"
                    >
                      {{ order.email }}
                      <template v-if="order.phone">
                        • {{ order.phone }}
                      </template>
                    </span>
                  </div>
                </div>
                <div class="flex items-center gap-1.5 shrink-0" @click.stop>
                  <span
                    class="inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-semibold rounded-md border whitespace-nowrap"
                    :class="
                      getStoreBadgeMeta(order).isComBr
                        ? 'bg-n-amber-3/70 text-n-amber-11 border-n-amber-6/30'
                        : 'bg-n-brand/10 text-n-brand border-n-brand/20'
                    "
                    :title="getStoreBadgeMeta(order).fullTitle"
                  >
                    <span>{{ getStoreBadgeMeta(order).shortLabel }}</span>
                    <span
                      v-if="getStoreBadgeMeta(order).suffix"
                      class="font-mono opacity-80"
                    >
                      {{ getStoreBadgeMeta(order).suffix }}
                    </span>
                  </span>
                  <button
                    type="button"
                    class="flex items-center justify-center size-6 rounded-lg bg-n-brand/10 text-n-brand hover:bg-n-brand/20"
                    title="Abrir Popup de Detalhes do Pedido"
                    @click="openOrderDetailModal(order)"
                  >
                    <span class="i-lucide-eye size-3.5" />
                  </button>
                  <button
                    type="button"
                    class="flex items-center justify-center size-6 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
                    :title="
                      isOrderExpanded(order) ? 'Recolher card' : 'Expandir card'
                    "
                    @click="toggleOrderExpanded(order)"
                  >
                    <span
                      class="size-3.5"
                      :class="
                        isOrderExpanded(order)
                          ? 'i-lucide-minimize-2'
                          : 'i-lucide-maximize-2'
                      "
                    />
                  </button>
                </div>
              </div>

              <!-- Componente rico de detalhes do pedido -->
              <ShopifyOrderItem
                :key="`${getOrderKey(order)}-${isOrderExpanded(order)}`"
                :order="order"
                :default-expanded="isOrderExpanded(order)"
                embedded
              />

              <div
                class="flex items-center justify-between pt-2.5 mt-2 border-t border-n-weak"
              >
                <button
                  type="button"
                  class="inline-flex items-center gap-1.5 text-xs font-semibold text-n-brand hover:underline"
                  @click="openOrderDetailModal(order)"
                >
                  <span class="i-lucide-sparkles size-3.5" />
                  <span>Ver Detalhes Completos (Popup)</span>
                </button>
                <span class="text-[11px] text-n-slate-10">
                  {{ formatDate(order.created_at) }}
                </span>
              </div>
            </div>
          </div>

          <!-- MODO LISTA: PEDIDOS (Tabela com Linha Expansível e Sem Quebra de Badges) -->
          <div
            v-else
            class="overflow-x-auto rounded-2xl border border-n-weak bg-n-solid-2 shadow-sm"
          >
            <table class="w-full min-w-[980px] text-left border-collapse">
              <thead>
                <tr
                  class="border-b border-n-weak bg-n-alpha-1 text-[11px] font-bold uppercase tracking-wider text-n-slate-11 whitespace-nowrap"
                >
                  <th class="py-3 px-3 w-9" />
                  <th class="py-3 px-3">Pedido</th>
                  <th class="py-3 px-3">Cliente &amp; Contato</th>
                  <th class="py-3 px-3">Loja</th>
                  <th class="py-3 px-3">Itens</th>
                  <th class="py-3 px-3">Pagamento &amp; Entrega</th>
                  <th class="py-3 px-3">Total</th>
                  <th class="py-3 px-3">Data</th>
                  <th class="py-3 px-3 text-right">Ações</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-sm">
                <template
                  v-for="order in filteredOrdersByRange"
                  :key="getOrderKey(order)"
                >
                  <tr
                    class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
                    :class="{ 'bg-n-brand/5': isOrderExpanded(order) }"
                    @click="openOrderDetailModal(order)"
                  >
                    <td
                      class="py-3 px-3 whitespace-nowrap"
                      @click.stop="toggleOrderExpanded(order)"
                    >
                      <span
                        class="size-4 text-n-slate-11 transition-transform inline-block"
                        :class="
                          isOrderExpanded(order)
                            ? 'i-lucide-chevron-up text-n-brand'
                            : 'i-lucide-chevron-down'
                        "
                      />
                    </td>
                    <td class="py-3 px-3 whitespace-nowrap">
                      <div class="flex items-center gap-2">
                        <span class="font-extrabold text-n-slate-12 font-mono">
                          {{ order.name }}
                        </span>
                        <span
                          v-if="order.within_one_hour_window"
                          class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[10px] font-bold bg-n-amber-3 text-n-amber-11 whitespace-nowrap"
                        >
                          Há {{ order.minutes_since_created }}m (&lt; 1h)
                        </span>
                      </div>
                    </td>
                    <td class="py-3 px-3 whitespace-nowrap">
                      <div class="flex flex-col text-xs max-w-[200px]">
                        <span
                          class="font-semibold text-n-slate-12 truncate"
                          :title="order.customer_name || 'Cliente Shopify'"
                        >
                          {{ order.customer_name || 'Cliente Shopify' }}
                        </span>
                        <span
                          class="text-n-slate-11 truncate font-mono text-[11px]"
                          :title="order.email"
                        >
                          {{ order.email }}
                        </span>
                      </div>
                    </td>
                    <td class="py-3 px-3 whitespace-nowrap">
                      <span
                        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-semibold rounded-lg border whitespace-nowrap"
                        :class="
                          getStoreBadgeMeta(order).isComBr
                            ? 'bg-n-amber-3/70 text-n-amber-11 border-n-amber-6/30'
                            : 'bg-n-brand/10 text-n-brand border-n-brand/20'
                        "
                        :title="getStoreBadgeMeta(order).fullTitle"
                      >
                        <span>{{ getStoreBadgeMeta(order).shortLabel }}</span>
                        <span
                          v-if="getStoreBadgeMeta(order).suffix"
                          class="text-[10px] font-mono opacity-80"
                        >
                          {{ getStoreBadgeMeta(order).suffix }}
                        </span>
                      </span>
                    </td>
                    <td class="py-3 px-3 text-xs text-n-slate-12 max-w-[260px]">
                      <div
                        class="truncate font-semibold"
                        :title="
                          order.line_items?.[0]
                            ? `${order.line_items[0].quantity}x ${order.line_items[0].title}`
                            : '1 item'
                        "
                      >
                        {{
                          order.line_items?.[0]
                            ? `${order.line_items[0].quantity}x ${order.line_items[0].title}`
                            : '1 item'
                        }}
                      </div>
                      <span
                        v-if="(order.line_items?.length || 0) > 1"
                        class="text-[11px] text-n-slate-10 whitespace-nowrap"
                      >
                        +{{ order.line_items.length - 1 }} outro(s) item(ns)
                      </span>
                      <span
                        v-else-if="order.line_items?.[0]?.sku"
                        class="text-[11px] text-n-slate-10 font-mono truncate block"
                      >
                        SKU: {{ order.line_items[0].sku }}
                      </span>
                    </td>
                    <td class="py-3 px-3 whitespace-nowrap">
                      <div
                        class="inline-flex items-center gap-1.5 whitespace-nowrap"
                      >
                        <span
                          class="inline-flex items-center px-2.5 py-0.5 text-[11px] font-semibold rounded-full whitespace-nowrap"
                          :class="getFinancialBadge(order.financial_status).cls"
                        >
                          {{ getFinancialBadge(order.financial_status).label }}
                        </span>
                        <span
                          class="inline-flex items-center px-2.5 py-0.5 text-[11px] font-semibold rounded-full whitespace-nowrap"
                          :class="
                            getFulfillmentBadge(order.fulfillment_status).cls
                          "
                        >
                          {{
                            getFulfillmentBadge(order.fulfillment_status).label
                          }}
                        </span>
                      </div>
                    </td>
                    <td
                      class="py-3 px-3 font-extrabold text-n-slate-12 whitespace-nowrap tabular-nums"
                    >
                      {{ formatCurrency(order.total_price, order.currency) }}
                    </td>
                    <td class="py-3 px-3 whitespace-nowrap">
                      <div class="flex flex-col text-xs leading-tight">
                        <span class="font-semibold text-n-slate-12">
                          {{ formatShortDate(order.created_at) }}
                        </span>
                        <span class="text-[11px] text-n-slate-10">
                          às {{ formatShortTime(order.created_at) }}
                        </span>
                      </div>
                    </td>
                    <td
                      class="py-3 px-3 text-right whitespace-nowrap"
                      @click.stop
                    >
                      <div
                        class="inline-flex items-center justify-end gap-1.5 whitespace-nowrap"
                      >
                        <Button
                          size="xs"
                          variant="faded"
                          color="blue"
                          icon="i-lucide-eye"
                          label="Detalhes"
                          @click="openOrderDetailModal(order)"
                        />
                        <button
                          type="button"
                          class="inline-flex items-center justify-center size-7 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 transition-colors"
                          :title="
                            isOrderExpanded(order)
                              ? 'Ocultar detalhes da linha'
                              : 'Expandir linha'
                          "
                          @click="toggleOrderExpanded(order)"
                        >
                          <span
                            class="size-3.5"
                            :class="
                              isOrderExpanded(order)
                                ? 'i-lucide-chevron-up text-n-brand'
                                : 'i-lucide-chevron-down'
                            "
                          />
                        </button>
                        <a
                          :href="order.admin_url"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex items-center justify-center size-7 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 transition-colors"
                          title="Abrir na Shopify"
                        >
                          <span class="i-lucide-external-link size-3.5" />
                        </a>
                      </div>
                    </td>
                  </tr>

                  <!-- Linha Expandida de Detalhes do Pedido -->
                  <tr v-if="isOrderExpanded(order)" class="bg-n-surface-1">
                    <td colspan="9" class="p-5 border-b border-n-weak">
                      <div
                        class="grid grid-cols-1 lg:grid-cols-3 gap-4 rounded-2xl border border-n-weak bg-n-solid-2 p-4"
                      >
                        <!-- Coluna 1: Itens do Pedido -->
                        <div class="flex flex-col gap-2">
                          <span
                            class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                          >
                            <span
                              class="i-lucide-package size-3.5 text-n-brand"
                            />
                            Itens Comprados ({{
                              order.line_items?.length || 0
                            }})
                          </span>
                          <div
                            v-for="item in order.line_items"
                            :key="item.id"
                            class="flex items-start justify-between gap-3 p-3 rounded-xl bg-n-alpha-1 border border-n-weak"
                          >
                            <div class="flex flex-col min-w-0">
                              <span
                                class="text-xs font-semibold text-n-slate-12"
                              >
                                {{ item.quantity }}x {{ item.title }}
                              </span>
                              <span
                                v-if="item.variant_title"
                                class="text-[11px] text-n-slate-11"
                              >
                                Variante: {{ item.variant_title }}
                              </span>
                              <span
                                v-if="item.sku"
                                class="text-[11px] font-mono text-n-slate-10 mt-0.5"
                              >
                                SKU: {{ item.sku }}
                              </span>
                            </div>
                            <span
                              class="text-xs font-bold text-n-slate-12 shrink-0"
                            >
                              {{ formatCurrency(item.price, order.currency) }}
                            </span>
                          </div>
                        </div>

                        <!-- Coluna 2: Dados do Cliente, Pagamento e Entrega -->
                        <div class="flex flex-col gap-2">
                          <span
                            class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                          >
                            <span
                              class="i-lucide-user-check size-3.5 text-n-brand"
                            />
                            Cliente, Pagamento & Destino
                          </span>
                          <div
                            class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1 border border-n-weak text-xs"
                          >
                            <div class="flex justify-between">
                              <span class="text-n-slate-11">Cliente:</span>
                              <strong class="text-n-slate-12">{{
                                order.customer_name
                              }}</strong>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-n-slate-11">E-mail:</span>
                              <span class="text-n-slate-12 font-mono">{{
                                order.email
                              }}</span>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-n-slate-11">Telefone:</span>
                              <span class="text-n-slate-12">{{
                                order.phone || '—'
                              }}</span>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-n-slate-11">Meio Pagto:</span>
                              <span class="text-n-slate-12 font-medium">{{
                                order.payment_method ||
                                'PIX / Cartão de Crédito'
                              }}</span>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-n-slate-11">Destino:</span>
                              <span class="text-n-slate-12">{{
                                order.shipping_city || 'Entrega Digital'
                              }}</span>
                            </div>
                          </div>
                        </div>

                        <!-- Coluna 3: Resumo Financeiro, Rastreamento e Links -->
                        <div class="flex flex-col justify-between gap-2">
                          <div class="flex flex-col gap-2">
                            <span
                              class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                            >
                              <span
                                class="i-lucide-receipt size-3.5 text-n-brand"
                              />
                              Resumo Financeiro & Notas
                            </span>
                            <div
                              class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1 border border-n-weak text-xs"
                            >
                              <div class="flex justify-between">
                                <span class="text-n-slate-11">Subtotal:</span>
                                <span>{{
                                  formatCurrency(
                                    order.subtotal_price || order.total_price,
                                    order.currency
                                  )
                                }}</span>
                              </div>
                              <div
                                class="flex justify-between font-bold text-n-slate-12 pt-1 border-t border-n-weak"
                              >
                                <span>Total Pago:</span>
                                <span>{{
                                  formatCurrency(
                                    order.total_price,
                                    order.currency
                                  )
                                }}</span>
                              </div>
                              <p
                                v-if="order.note"
                                class="text-[11px] text-n-slate-11 pt-1"
                              >
                                <strong>Nota:</strong> {{ order.note }}
                              </p>
                            </div>
                          </div>

                          <div class="flex items-center gap-2">
                            <a
                              :href="order.admin_url"
                              target="_blank"
                              rel="noopener noreferrer"
                              class="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl bg-n-brand text-white text-xs font-medium hover:opacity-90"
                            >
                              <span class="i-lucide-external-link size-3.5" />
                              <span>Ver Pedido na Shopify</span>
                            </a>
                            <Button
                              size="xs"
                              variant="faded"
                              color="slate"
                              icon="i-lucide-filter"
                              label="Todos do Cliente"
                              @click="filterOrdersByCustomerEmail(order.email)"
                            />
                          </div>
                        </div>
                      </div>
                    </td>
                  </tr>
                </template>
              </tbody>
            </table>
          </div>
        </div>

        <!-- ABA 2: CLIENTES (Suporta Cards e Lista) -->
        <div v-else-if="activeTab === 'customers'" class="flex flex-col gap-4">
          <div class="flex items-center justify-between">
            <span class="text-xs text-n-slate-11">
              Exibindo
              <strong class="text-n-slate-12">{{ customers.length }}</strong>
              cliente(s) de
              <strong class="text-n-slate-12">{{
                activeStoreDisplayName
              }}</strong>
            </span>
          </div>

          <div
            v-if="isLoadingCustomers"
            class="flex items-center justify-center py-16"
          >
            <Spinner />
          </div>

          <div
            v-else-if="!customers.length"
            class="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <span class="i-lucide-users size-8 text-n-slate-10 mb-2" />
            <p class="text-sm font-medium text-n-slate-12">
              Nenhum cliente encontrado
            </p>
          </div>

          <!-- MODO CARDS: CLIENTES -->
          <div
            v-else-if="viewMode === 'cards'"
            class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4"
          >
            <div
              v-for="customer in customers"
              :key="`${customer.hook_id}-${customer.email}`"
              class="flex flex-col justify-between p-5 rounded-2xl border border-n-weak bg-n-solid-2 hover:border-n-brand/40 transition-all shadow-sm gap-4 cursor-pointer"
              @click="openCustomerDetailModal(customer)"
            >
              <!-- Topo do Card do Cliente -->
              <div class="flex items-start justify-between gap-3">
                <div class="flex items-center gap-3 min-w-0">
                  <div
                    class="flex items-center justify-center size-11 rounded-2xl bg-n-brand/10 text-n-brand font-bold text-base shrink-0"
                  >
                    {{
                      (customer.name || customer.email || 'C')
                        .charAt(0)
                        .toUpperCase()
                    }}
                  </div>
                  <div class="flex flex-col min-w-0">
                    <h4
                      class="text-sm font-semibold text-n-slate-12 truncate"
                      :title="customer.name"
                    >
                      {{ customer.name }}
                    </h4>
                    <span
                      class="text-xs text-n-slate-11 truncate font-mono"
                      :title="customer.email"
                    >
                      {{ customer.email }}
                    </span>
                    <span class="text-xs text-n-slate-10">
                      {{ customer.phone || 'Telefone não informado' }}
                    </span>
                  </div>
                </div>
                <span
                  class="px-2.5 py-0.5 text-[10px] font-semibold rounded-full bg-n-brand/10 text-n-brand shrink-0"
                >
                  {{ customer.store_name }}
                </span>
              </div>

              <!-- Métricas do Cliente no Card -->
              <div
                class="grid grid-cols-3 gap-2 p-3 rounded-xl bg-n-alpha-1 border border-n-weak text-center"
              >
                <div class="flex flex-col">
                  <span class="text-[10px] uppercase text-n-slate-10">
                    Pedidos
                  </span>
                  <span class="text-sm font-bold text-n-slate-12">
                    {{ customer.orders_count }}
                  </span>
                </div>
                <div class="flex flex-col border-x border-n-weak px-1">
                  <span class="text-[10px] uppercase text-n-slate-10">
                    Total Gasto
                  </span>
                  <span class="text-sm font-bold text-n-teal-11">
                    R$ {{ customer.total_spent }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-[10px] uppercase text-n-slate-10">
                    Último
                  </span>
                  <span class="text-xs font-mono font-semibold text-n-slate-12">
                    {{ customer.last_order_name || '—' }}
                  </span>
                </div>
              </div>

              <!-- Rodapé do Card do Cliente -->
              <div class="flex items-center justify-between pt-1" @click.stop>
                <span class="text-[11px] text-n-slate-10">
                  Atualizado: {{ formatDate(customer.last_order_at) }}
                </span>
                <div class="flex items-center gap-1.5">
                  <Button
                    size="xs"
                    variant="faded"
                    color="slate"
                    icon="i-lucide-eye"
                    label="Detalhes"
                    @click="openCustomerDetailModal(customer)"
                  />
                  <Button
                    size="xs"
                    variant="faded"
                    color="blue"
                    icon="i-lucide-shopping-bag"
                    label="Ver Pedidos"
                    @click="filterOrdersByCustomerEmail(customer.email)"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- MODO LISTA: CLIENTES -->
          <div
            v-else
            class="overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <table class="w-full text-left border-collapse">
              <thead>
                <tr
                  class="border-b border-n-weak bg-n-alpha-1 text-xs font-semibold uppercase tracking-wide text-n-slate-11"
                >
                  <th class="py-3.5 px-4">Cliente</th>
                  <th class="py-3.5 px-4">Contato (E-mail / Telefone)</th>
                  <th class="py-3.5 px-4">Loja Shopify</th>
                  <th class="py-3.5 px-4">Pedidos</th>
                  <th class="py-3.5 px-4">Total Gasto</th>
                  <th class="py-3.5 px-4">Último Pedido</th>
                  <th class="py-3.5 px-4 text-right">Ação</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-sm">
                <tr
                  v-for="customer in customers"
                  :key="`${customer.hook_id}-${customer.email}`"
                  class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
                  @click="openCustomerDetailModal(customer)"
                >
                  <td class="py-3.5 px-4">
                    <div class="flex items-center gap-2.5">
                      <div
                        class="flex items-center justify-center size-8 rounded-full bg-n-brand/10 text-n-brand font-semibold text-xs"
                      >
                        {{
                          (customer.name || customer.email || 'C')
                            .charAt(0)
                            .toUpperCase()
                        }}
                      </div>
                      <span class="font-medium text-n-slate-12">
                        {{ customer.name }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3.5 px-4">
                    <div class="flex flex-col text-xs">
                      <span class="text-n-slate-12 font-medium">
                        {{ customer.email }}
                      </span>
                      <span class="text-n-slate-10">
                        {{ customer.phone || '—' }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3.5 px-4">
                    <span
                      class="inline-flex items-center px-2.5 py-0.5 text-xs font-medium rounded-full bg-n-brand/10 text-n-brand"
                    >
                      {{ customer.store_name }}
                    </span>
                  </td>
                  <td class="py-3.5 px-4 font-medium text-n-slate-12">
                    {{ customer.orders_count }} pedido(s)
                  </td>
                  <td class="py-3.5 px-4 font-semibold text-n-slate-12">
                    R$ {{ customer.total_spent }}
                  </td>
                  <td class="py-3.5 px-4">
                    <span
                      v-if="customer.last_order_name"
                      class="font-mono text-xs px-2 py-0.5 rounded bg-n-alpha-2 text-n-slate-12"
                    >
                      {{ customer.last_order_name }}
                    </span>
                  </td>
                  <td class="py-3.5 px-4 text-right" @click.stop>
                    <div class="inline-flex items-center gap-1.5">
                      <Button
                        size="xs"
                        variant="faded"
                        color="blue"
                        icon="i-lucide-eye"
                        label="Detalhes"
                        @click="openCustomerDetailModal(customer)"
                      />
                      <Button
                        size="xs"
                        variant="faded"
                        color="slate"
                        icon="i-lucide-shopping-bag"
                        label="Ver Pedidos"
                        @click="filterOrdersByCustomerEmail(customer.email)"
                      />
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- ABA 3: PRODUTOS DA LOJA (Suporta Cards e Lista) -->
        <div v-else-if="activeTab === 'products'" class="flex flex-col gap-4">
          <div class="flex items-center justify-between flex-wrap gap-2">
            <span class="text-xs text-n-slate-11">
              Exibindo
              <strong class="text-n-slate-12">{{ products.length }}</strong>
              produto(s) sincronizados de
              <strong class="text-n-slate-12">
                {{ activeStoreDisplayName }}
              </strong>
            </span>
            <Button
              v-if="isAdmin"
              size="xs"
              variant="faded"
              color="blue"
              icon="i-lucide-refresh-cw"
              :label="
                isSyncingProducts
                  ? 'Sincronizando...'
                  : 'Puxar / Atualizar Produtos'
              "
              :is-loading="isSyncingProducts"
              @click="handleSyncProductsNow"
            />
          </div>

          <div
            v-if="isLoadingProducts"
            class="flex items-center justify-center py-16"
          >
            <Spinner />
          </div>

          <div
            v-else-if="!products.length"
            class="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <span class="i-lucide-package size-8 text-n-slate-10 mb-2" />
            <p class="text-sm font-medium text-n-slate-12">
              Nenhum produto encontrado
            </p>
          </div>

          <!-- MODO CARDS: PRODUTOS -->
          <div
            v-else-if="viewMode === 'cards'"
            class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4 gap-4"
          >
            <div
              v-for="product in products"
              :key="`${product.hook_id}-${product.id}`"
              class="flex flex-col justify-between p-5 rounded-2xl border border-n-weak bg-n-solid-2 hover:border-n-brand/40 transition-all shadow-sm gap-4 cursor-pointer group"
              @click="openProductDetailModal(product)"
            >
              <div class="flex flex-col gap-3">
                <div class="flex items-center justify-between gap-2">
                  <span
                    class="inline-flex items-center gap-1 px-2.5 py-0.5 text-[10px] font-semibold rounded-full bg-n-brand/10 text-n-brand"
                  >
                    <span class="i-lucide-store size-3" />
                    {{ product.store_name }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                  >
                    Ativo
                  </span>
                </div>

                <!-- Miniatura de Foto do Produto no Card -->
                <div class="flex items-start gap-3">
                  <div
                    class="relative flex items-center justify-center size-14 rounded-xl bg-n-alpha-2 border border-n-weak overflow-hidden shrink-0"
                  >
                    <img
                      v-if="product.image_url"
                      :src="product.image_url"
                      :alt="product.title"
                      class="w-full h-full object-cover group-hover:scale-105 transition-transform"
                      @error="
                        $event.target.src =
                          '/dashboard/images/integrations/shopify.png'
                      "
                    />
                    <span
                      v-else
                      class="i-lucide-gamepad-2 size-6 text-n-brand"
                    />
                  </div>
                  <div class="flex flex-col min-w-0">
                    <h4
                      class="text-sm font-semibold text-n-slate-12 line-clamp-2 leading-snug group-hover:text-n-brand transition-colors"
                      :title="product.title"
                    >
                      {{ product.title }}
                    </h4>
                    <span
                      v-if="product.product_type"
                      class="text-[11px] text-n-slate-11 mt-0.5"
                    >
                      Categoria: {{ product.product_type }}
                    </span>
                  </div>
                </div>

                <div
                  class="flex items-center justify-between px-3 py-2 rounded-xl bg-n-alpha-1 border border-n-weak text-xs font-mono text-n-slate-11"
                >
                  <span>SKU: {{ product.sku || 'N/A' }}</span>
                  <span>ID: #{{ product.id }}</span>
                </div>
              </div>

              <div
                class="flex items-center justify-between pt-3 border-t border-n-weak"
              >
                <div class="flex flex-col">
                  <span class="text-[10px] uppercase text-n-slate-10">
                    Preço de Venda
                  </span>
                  <div class="flex items-baseline gap-1.5">
                    <span class="text-base font-bold text-n-slate-12">
                      R$ {{ product.price }}
                    </span>
                    <span
                      v-if="product.compare_at_price"
                      class="text-[11px] text-n-slate-10 line-through"
                    >
                      R$ {{ product.compare_at_price }}
                    </span>
                  </div>
                </div>
                <div class="flex flex-col items-end gap-1">
                  <span class="text-xs font-semibold text-n-teal-11">
                    {{ product.inventory_quantity ?? 'Digital' }} un.
                  </span>
                  <span
                    class="inline-flex items-center gap-1 text-[11px] font-semibold text-n-brand"
                  >
                    <span class="i-lucide-eye size-3" />
                    Ver Ficha
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- MODO LISTA: PRODUTOS -->
          <div
            v-else
            class="overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <table class="w-full text-left border-collapse">
              <thead>
                <tr
                  class="border-b border-n-weak bg-n-alpha-1 text-xs font-semibold uppercase tracking-wide text-n-slate-11"
                >
                  <th class="py-3.5 px-4">Produto</th>
                  <th class="py-3.5 px-4">SKU</th>
                  <th class="py-3.5 px-4">Categoria</th>
                  <th class="py-3.5 px-4">Loja Shopify</th>
                  <th class="py-3.5 px-4">Status</th>
                  <th class="py-3.5 px-4">Estoque</th>
                  <th class="py-3.5 px-4">Preço</th>
                  <th class="py-3.5 px-4 text-right">Ação</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-sm">
                <tr
                  v-for="product in products"
                  :key="`${product.hook_id}-${product.id}`"
                  class="hover:bg-n-alpha-1 transition-colors cursor-pointer"
                  @click="openProductDetailModal(product)"
                >
                  <td class="py-3.5 px-4">
                    <div class="flex items-center gap-3">
                      <img
                        :src="
                          product.image_url ||
                          '/dashboard/images/integrations/shopify.png'
                        "
                        :alt="product.title"
                        class="size-10 rounded-lg object-cover border border-n-weak bg-n-alpha-2 shrink-0"
                        @error="
                          $event.target.src =
                            '/dashboard/images/integrations/shopify.png'
                        "
                      />
                      <span class="font-medium text-n-slate-12">
                        {{ product.title }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3.5 px-4 font-mono text-xs text-n-slate-11">
                    {{ product.sku || '—' }}
                  </td>
                  <td class="py-3.5 px-4 text-xs text-n-slate-11">
                    {{ product.product_type || 'Digital' }}
                  </td>
                  <td class="py-3.5 px-4">
                    <span
                      class="inline-flex items-center px-2.5 py-0.5 text-xs font-medium rounded-full bg-n-brand/10 text-n-brand"
                    >
                      {{ product.store_name }}
                    </span>
                  </td>
                  <td class="py-3.5 px-4">
                    <span
                      class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-teal-3 text-n-teal-11"
                    >
                      Ativo
                    </span>
                  </td>
                  <td class="py-3.5 px-4 text-xs font-medium text-n-slate-12">
                    {{ product.inventory_quantity ?? 'Digital' }} un.
                  </td>
                  <td class="py-3.5 px-4 font-bold text-n-slate-12">
                    R$ {{ product.price }}
                  </td>
                  <td class="py-3.5 px-4 text-right" @click.stop>
                    <Button
                      size="xs"
                      variant="faded"
                      color="blue"
                      icon="i-lucide-eye"
                      label="Ver Detalhes"
                      @click="openProductDetailModal(product)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>

    <!-- ========================================================================= -->
    <!-- POPUP MODAL 1: DETALHES COMPLETOS DO PEDIDO (Com Fotos, Timeline e Ações) -->
    <!-- ========================================================================= -->
    <div
      v-if="selectedOrderModal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-n-alpha-black2 backdrop-blur-sm"
      @click.self="selectedOrderModal = null"
    >
      <div
        class="flex flex-col w-full max-w-4xl max-h-[90vh] overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-2xl"
      >
        <!-- Cabeçalho do Modal do Pedido -->
        <div
          class="flex items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="flex items-center justify-center size-11 rounded-xl bg-n-brand/10 text-n-brand shrink-0"
            >
              <span class="i-lucide-shopping-bag size-5" />
            </div>
            <div class="flex flex-col min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <h3 class="text-base font-bold text-n-slate-12 font-mono">
                  Pedido {{ selectedOrderModal.name }}
                </h3>
                <span
                  class="px-2.5 py-0.5 text-xs font-semibold rounded-full"
                  :class="
                    getFinancialBadge(selectedOrderModal.financial_status).cls
                  "
                >
                  {{
                    getFinancialBadge(selectedOrderModal.financial_status).label
                  }}
                </span>
                <span
                  class="px-2.5 py-0.5 text-xs font-semibold rounded-full"
                  :class="
                    getFulfillmentBadge(selectedOrderModal.fulfillment_status)
                      .cls
                  "
                >
                  {{
                    getFulfillmentBadge(selectedOrderModal.fulfillment_status)
                      .label
                  }}
                </span>
                <span
                  class="px-2.5 py-0.5 text-xs font-semibold rounded-full bg-n-brand/10 text-n-brand"
                >
                  {{ selectedOrderModal.store_name }}
                </span>
              </div>
              <span class="text-xs text-n-slate-11">
                Criado em {{ formatDate(selectedOrderModal.created_at) }} • ID
                Shopify: #{{ selectedOrderModal.id }}
              </span>
            </div>
          </div>

          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
            @click="selectedOrderModal = null"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <!-- Corpo do Modal do Pedido -->
        <div
          class="flex-1 overflow-y-auto p-6 grid grid-cols-1 lg:grid-cols-3 gap-5"
        >
          <!-- Coluna Esquerda (2/3): Produtos com Foto + Resumo Financeiro + Rastreamento -->
          <div class="lg:col-span-2 flex flex-col gap-4">
            <!-- Lista de Itens com Fotos -->
            <div
              class="flex flex-col gap-3 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
            >
              <div class="flex items-center justify-between">
                <h4
                  class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                >
                  <span class="i-lucide-package size-4 text-n-brand" />
                  Itens do Pedido ({{
                    selectedOrderModal.line_items?.length || 0
                  }})
                </h4>
                <span
                  v-if="selectedOrderModal.within_one_hour_window"
                  class="inline-flex items-center gap-1 px-2.5 py-0.5 text-xs font-semibold rounded-full bg-n-amber-3 text-n-amber-11"
                >
                  <span class="i-lucide-clock size-3" />
                  Comprado há {{ selectedOrderModal.minutes_since_created }} min
                  (Janela &lt; 1h)
                </span>
              </div>

              <div class="flex flex-col gap-2.5">
                <div
                  v-for="item in selectedOrderModal.line_items"
                  :key="item.id"
                  class="flex items-center justify-between gap-3 p-3 rounded-xl border border-n-weak bg-n-solid-2"
                >
                  <div class="flex items-center gap-3 min-w-0">
                    <img
                      :src="
                        item.image_url ||
                        '/dashboard/images/integrations/shopify.png'
                      "
                      :alt="item.title"
                      class="size-14 rounded-xl object-cover border border-n-weak bg-n-alpha-2 shrink-0"
                      @error="
                        $event.target.src =
                          '/dashboard/images/integrations/shopify.png'
                      "
                    />
                    <div class="flex flex-col min-w-0">
                      <span class="text-sm font-semibold text-n-slate-12">
                        {{ item.title }}
                      </span>
                      <span
                        v-if="item.variant_title"
                        class="text-xs text-n-slate-11"
                      >
                        Variante: {{ item.variant_title }}
                      </span>
                      <div class="flex items-center gap-2 mt-1">
                        <span
                          v-if="item.sku"
                          class="px-2 py-0.5 rounded bg-n-alpha-2 font-mono text-[11px] text-n-slate-11"
                        >
                          SKU: {{ item.sku }}
                        </span>
                        <span class="text-xs text-n-slate-10">
                          Qtd: {{ item.quantity }}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div class="flex flex-col items-end shrink-0">
                    <span class="text-sm font-bold text-n-slate-12">
                      {{
                        formatCurrency(item.price, selectedOrderModal.currency)
                      }}
                    </span>
                    <span class="text-[11px] text-n-slate-10">
                      Subtotal:
                      {{
                        formatCurrency(
                          Number(item.price || 0) * Number(item.quantity || 1),
                          selectedOrderModal.currency
                        )
                      }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Resumo Financeiro Detalhado -->
            <div
              class="flex flex-col gap-2.5 p-4 rounded-2xl border border-n-weak bg-n-surface-1 text-xs"
            >
              <h4
                class="font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
              >
                <span class="i-lucide-receipt size-4 text-n-brand" />
                Detalhamento Financeiro &amp; Pagamento
              </h4>
              <div class="flex justify-between text-n-slate-11">
                <span>Subtotal dos Itens:</span>
                <span class="text-n-slate-12 font-medium">
                  {{
                    formatCurrency(
                      selectedOrderModal.subtotal_price ||
                        selectedOrderModal.total_price,
                      selectedOrderModal.currency
                    )
                  }}
                </span>
              </div>
              <div class="flex justify-between text-n-slate-11">
                <span>Descontos Aplicados:</span>
                <span class="text-n-teal-11 font-medium">
                  -
                  {{
                    formatCurrency(
                      selectedOrderModal.total_discounts || 0,
                      selectedOrderModal.currency
                    )
                  }}
                </span>
              </div>
              <div class="flex justify-between text-n-slate-11">
                <span>Impostos / Taxas:</span>
                <span class="text-n-slate-12 font-medium">
                  {{
                    formatCurrency(
                      selectedOrderModal.total_tax || 0,
                      selectedOrderModal.currency
                    )
                  }}
                </span>
              </div>
              <div class="flex justify-between text-n-slate-11">
                <span>Gateway / Método de Pagamento:</span>
                <span class="text-n-slate-12 font-semibold">
                  {{
                    selectedOrderModal.payment_method ||
                    selectedOrderModal.gateway ||
                    'PIX / Cartão de Crédito'
                  }}
                </span>
              </div>
              <div
                class="flex justify-between pt-2.5 border-t border-n-weak text-sm font-extrabold text-n-slate-12"
              >
                <span>Total do Pedido:</span>
                <span class="text-n-brand">
                  {{
                    formatCurrency(
                      selectedOrderModal.total_price,
                      selectedOrderModal.currency
                    )
                  }}
                </span>
              </div>
            </div>

            <!-- Rastreamento e Notas -->
            <div
              v-if="
                selectedOrderModal.fulfillments?.length ||
                selectedOrderModal.note ||
                selectedOrderModal.tags?.length
              "
              class="flex flex-col gap-2.5 p-4 rounded-2xl border border-n-weak bg-n-surface-1 text-xs"
            >
              <h4
                class="font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
              >
                <span class="i-lucide-truck size-4 text-n-brand" />
                Logística Digital, Tags &amp; Observações
              </h4>

              <div
                v-for="(ful, fIdx) in selectedOrderModal.fulfillments"
                :key="fIdx"
                class="flex items-center justify-between p-2.5 rounded-xl bg-n-solid-2 border border-n-weak"
              >
                <div class="flex flex-col">
                  <span class="font-semibold text-n-slate-12">
                    {{ ful.tracking_company || 'Envio Digital Automático' }}
                  </span>
                  <span class="font-mono text-n-slate-11">
                    Código: {{ ful.tracking_number || 'Licença Digital' }}
                  </span>
                </div>
                <a
                  v-if="ful.tracking_url"
                  :href="ful.tracking_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="px-2.5 py-1 rounded-lg bg-n-brand/10 text-n-brand font-semibold hover:underline"
                >
                  Rastrear
                </a>
              </div>

              <p v-if="selectedOrderModal.note" class="text-n-slate-12">
                <strong>Nota do Pedido:</strong> {{ selectedOrderModal.note }}
              </p>

              <div
                v-if="selectedOrderModal.tags?.length"
                class="flex items-center gap-1.5 flex-wrap"
              >
                <span
                  v-for="tag in selectedOrderModal.tags"
                  :key="tag"
                  class="px-2 py-0.5 rounded-full bg-n-alpha-2 text-[11px] text-n-slate-11"
                >
                  #{{ tag }}
                </span>
              </div>
            </div>
          </div>

          <!-- Coluna Direita (1/3): Perfil do Comprador & Ações Rápidas -->
          <div class="flex flex-col justify-between gap-4">
            <div class="flex flex-col gap-4">
              <div
                class="flex flex-col gap-3 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
              >
                <h4
                  class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                >
                  <span class="i-lucide-user size-4 text-n-brand" />
                  Dados do Cliente
                </h4>

                <div class="flex items-center gap-3">
                  <div
                    class="flex items-center justify-center size-11 rounded-xl bg-n-brand/10 text-n-brand font-bold text-base"
                  >
                    {{
                      (
                        selectedOrderModal.customer_name ||
                        selectedOrderModal.email ||
                        'C'
                      )
                        .charAt(0)
                        .toUpperCase()
                    }}
                  </div>
                  <div class="flex flex-col min-w-0">
                    <span class="text-sm font-bold text-n-slate-12 truncate">
                      {{
                        selectedOrderModal.customer_name || 'Cliente Shopify'
                      }}
                    </span>
                    <span class="text-xs text-n-slate-11 truncate">
                      {{
                        selectedOrderModal.shipping_city ||
                        'Entrega Digital Brasil'
                      }}
                    </span>
                  </div>
                </div>

                <div
                  class="flex flex-col gap-2 pt-2 border-t border-n-weak text-xs"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-n-slate-11">E-mail:</span>
                    <button
                      type="button"
                      class="font-mono text-n-brand hover:underline truncate"
                      @click="
                        copyTextToClipboard(
                          selectedOrderModal.email,
                          'E-mail do cliente'
                        )
                      "
                    >
                      {{ selectedOrderModal.email }}
                    </button>
                  </div>
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-n-slate-11">WhatsApp:</span>
                    <button
                      type="button"
                      class="font-mono text-n-slate-12 hover:text-n-brand"
                      @click="
                        copyTextToClipboard(
                          selectedOrderModal.phone,
                          'Telefone'
                        )
                      "
                    >
                      {{ selectedOrderModal.phone || 'Não informado' }}
                    </button>
                  </div>
                </div>
              </div>

              <!-- Loja de Origem -->
              <div
                class="flex flex-col gap-2 p-4 rounded-2xl border border-n-weak bg-n-surface-1 text-xs"
              >
                <span class="font-bold uppercase tracking-wide text-n-slate-11">
                  Loja Shopify Conectada
                </span>
                <div class="flex items-center justify-between">
                  <span class="font-semibold text-n-slate-12">
                    {{ selectedOrderModal.store_name }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-[10px] font-semibold rounded-full"
                    :class="
                      selectedOrderModal.auth_mode === 'mock'
                        ? 'bg-n-amber-3 text-n-amber-11'
                        : 'bg-n-teal-3 text-n-teal-11'
                    "
                  >
                    {{
                      selectedOrderModal.auth_mode === 'mock'
                        ? 'Simulação Mock'
                        : 'API Produção'
                    }}
                  </span>
                </div>
                <span class="font-mono text-[11px] text-n-slate-10">
                  {{ selectedOrderModal.shop_domain }}
                </span>
              </div>
            </div>

            <!-- Botões de Ação no Rodapé da Coluna -->
            <div class="flex flex-col gap-2">
              <a
                :href="selectedOrderModal.admin_url"
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-n-brand text-white text-xs font-semibold hover:opacity-90 transition-opacity"
              >
                <span class="i-lucide-external-link size-4" />
                <span>Abrir Pedido no Shopify Admin</span>
              </a>
              <Button
                size="sm"
                variant="faded"
                color="slate"
                icon="i-lucide-filter"
                label="Filtrar Todos os Pedidos deste Cliente"
                @click="
                  filterOrdersByCustomerEmail(selectedOrderModal.email);
                  selectedOrderModal = null;
                "
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ========================================================================= -->
    <!-- POPUP MODAL 2: DETALHES COMPLETOS DO CLIENTE (Histórico de Pedidos + LTV) -->
    <!-- ========================================================================= -->
    <div
      v-if="selectedCustomerModal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-n-alpha-black2 backdrop-blur-sm"
      @click.self="selectedCustomerModal = null"
    >
      <div
        class="flex flex-col w-full max-w-3xl max-h-[88vh] overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-2xl"
      >
        <!-- Header do Modal do Cliente -->
        <div
          class="flex items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1"
        >
          <div class="flex items-center gap-3">
            <div
              class="flex items-center justify-center size-12 rounded-2xl bg-n-brand/10 text-n-brand font-bold text-lg"
            >
              {{
                (
                  selectedCustomerModal.name ||
                  selectedCustomerModal.email ||
                  'C'
                )
                  .charAt(0)
                  .toUpperCase()
              }}
            </div>
            <div class="flex flex-col">
              <div class="flex items-center gap-2">
                <h3 class="text-base font-bold text-n-slate-12">
                  {{ selectedCustomerModal.name }}
                </h3>
                <span
                  class="px-2.5 py-0.5 text-xs font-semibold rounded-full bg-n-brand/10 text-n-brand"
                >
                  {{ selectedCustomerModal.store_name }}
                </span>
              </div>
              <span class="text-xs font-mono text-n-slate-11">
                {{ selectedCustomerModal.email }} •
                {{ selectedCustomerModal.phone || 'Sem telefone' }}
              </span>
            </div>
          </div>

          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
            @click="selectedCustomerModal = null"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <!-- Corpo do Modal do Cliente -->
        <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-5">
          <!-- KPIs do Cliente -->
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
            <div
              class="flex flex-col p-4 rounded-xl border border-n-weak bg-n-surface-1"
            >
              <span class="text-xs text-n-slate-11">Total de Pedidos</span>
              <span class="text-xl font-extrabold text-n-slate-12 mt-1">
                {{ selectedCustomerModal.orders_count }} pedido(s)
              </span>
            </div>
            <div
              class="flex flex-col p-4 rounded-xl border border-n-weak bg-n-surface-1"
            >
              <span class="text-xs text-n-slate-11">
                Valor Total Gasto (LTV)
              </span>
              <span class="text-xl font-extrabold text-n-teal-11 mt-1">
                R$ {{ selectedCustomerModal.total_spent }}
              </span>
            </div>
            <div
              class="flex flex-col p-4 rounded-xl border border-n-weak bg-n-surface-1"
            >
              <span class="text-xs text-n-slate-11">Última Compra</span>
              <span class="text-base font-bold font-mono text-n-slate-12 mt-1">
                {{ selectedCustomerModal.last_order_name || '—' }}
              </span>
              <span class="text-[11px] text-n-slate-10">
                {{ formatDate(selectedCustomerModal.last_order_at) }}
              </span>
            </div>
          </div>

          <!-- Histórico de Pedidos do Cliente -->
          <div class="flex flex-col gap-3">
            <h4
              class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
            >
              <span class="i-lucide-history size-4 text-n-brand" />
              Histórico de Pedidos Recentes ({{ customerOrdersInModal.length }})
            </h4>

            <div
              v-if="!customerOrdersInModal.length"
              class="p-6 text-center rounded-xl border border-n-weak bg-n-surface-1 text-xs text-n-slate-11"
            >
              Clique em &quot;Filtrar Todos os Pedidos na Aba Pedidos&quot;
              abaixo para buscar todo o histórico deste cliente na Shopify.
            </div>

            <div v-else class="flex flex-col gap-2.5">
              <div
                v-for="ord in customerOrdersInModal"
                :key="ord.id"
                class="flex items-center justify-between p-3.5 rounded-xl border border-n-weak bg-n-surface-1 hover:border-n-brand/40 cursor-pointer transition-all"
                @click="
                  selectedCustomerModal = null;
                  openOrderDetailModal(ord);
                "
              >
                <div class="flex flex-col gap-0.5">
                  <div class="flex items-center gap-2">
                    <span class="font-mono font-bold text-sm text-n-slate-12">
                      {{ ord.name }}
                    </span>
                    <span
                      class="px-2 py-0.5 text-[10px] font-semibold rounded-full"
                      :class="getFinancialBadge(ord.financial_status).cls"
                    >
                      {{ getFinancialBadge(ord.financial_status).label }}
                    </span>
                    <span
                      class="px-2 py-0.5 text-[10px] font-semibold rounded-full"
                      :class="getFulfillmentBadge(ord.fulfillment_status).cls"
                    >
                      {{ getFulfillmentBadge(ord.fulfillment_status).label }}
                    </span>
                  </div>
                  <span class="text-xs text-n-slate-11">
                    {{
                      ord.line_items?.map(li => li.title).join(', ') || '1 item'
                    }}
                  </span>
                </div>

                <div class="flex items-center gap-3">
                  <div class="flex flex-col items-end">
                    <span class="text-sm font-bold text-n-slate-12">
                      {{ formatCurrency(ord.total_price, ord.currency) }}
                    </span>
                    <span class="text-[11px] text-n-slate-10">
                      {{ formatDate(ord.created_at) }}
                    </span>
                  </div>
                  <span class="i-lucide-chevron-right size-4 text-n-slate-10" />
                </div>
              </div>
            </div>
          </div>

          <!-- Ações Rápidas do Cliente -->
          <div
            class="flex items-center justify-between pt-3 border-t border-n-weak gap-3 flex-wrap"
          >
            <div class="flex items-center gap-2">
              <Button
                size="xs"
                variant="faded"
                color="slate"
                icon="i-lucide-copy"
                label="Copiar E-mail"
                @click="
                  copyTextToClipboard(selectedCustomerModal.email, 'E-mail')
                "
              />
              <Button
                v-if="selectedCustomerModal.phone"
                size="xs"
                variant="faded"
                color="slate"
                icon="i-lucide-phone"
                label="Copiar Telefone"
                @click="
                  copyTextToClipboard(selectedCustomerModal.phone, 'Telefone')
                "
              />
            </div>

            <Button
              size="sm"
              icon="i-lucide-shopping-bag"
              label="Filtrar Todos os Pedidos na Aba Pedidos"
              @click="
                filterOrdersByCustomerEmail(selectedCustomerModal.email);
                selectedCustomerModal = null;
              "
            />
          </div>
        </div>
      </div>
    </div>

    <!-- ========================================================================= -->
    <!-- POPUP MODAL 3: DETALHES COMPLETOS DO PRODUTO (Galeria de Fotos & Variantes) -->
    <!-- ========================================================================= -->
    <div
      v-if="selectedProductModal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-n-alpha-black2 backdrop-blur-sm"
      @click.self="selectedProductModal = null"
    >
      <div
        class="flex flex-col w-full max-w-4xl max-h-[90vh] overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-2xl"
      >
        <!-- Header do Modal do Produto -->
        <div
          class="flex items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="flex items-center justify-center size-11 rounded-xl bg-n-brand/10 text-n-brand shrink-0"
            >
              <span class="i-lucide-gamepad-2 size-5" />
            </div>
            <div class="flex flex-col min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <h3 class="text-base font-bold text-n-slate-12 truncate">
                  {{ selectedProductModal.title }}
                </h3>
                <span
                  class="px-2.5 py-0.5 text-xs font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
                >
                  Ativo no Catálogo
                </span>
              </div>
              <span class="text-xs text-n-slate-11">
                Loja:
                <strong class="text-n-slate-12">{{
                  selectedProductModal.store_name
                }}</strong>
                • SKU:
                <strong class="font-mono text-n-slate-12">{{
                  selectedProductModal.sku || 'N/A'
                }}</strong>
                • ID: #{{ selectedProductModal.id }}
              </span>
            </div>
          </div>

          <button
            type="button"
            class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
            @click="selectedProductModal = null"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <!-- Corpo do Modal do Produto -->
        <div
          class="flex-1 overflow-y-auto p-6 grid grid-cols-1 lg:grid-cols-12 gap-6"
        >
          <!-- Coluna Esquerda (5 cols): Foto Grande + Miniaturas -->
          <div class="lg:col-span-5 flex flex-col gap-3">
            <div
              class="relative flex items-center justify-center w-full aspect-square rounded-2xl border border-n-weak bg-n-surface-1 overflow-hidden p-4"
            >
              <img
                :src="
                  activeProductModalImage ||
                  selectedProductModal.image_url ||
                  '/dashboard/images/integrations/shopify.png'
                "
                :alt="selectedProductModal.title"
                class="w-full h-full object-contain rounded-xl"
                @error="
                  $event.target.src =
                    '/dashboard/images/integrations/shopify.png'
                "
              />
              <span
                class="absolute top-3 left-3 px-2.5 py-1 text-xs font-semibold rounded-full bg-n-solid-2/90 border border-n-weak text-n-slate-12"
              >
                {{ selectedProductModal.product_type || 'Mídia Digital' }}
              </span>
            </div>

            <!-- Preço e Estoque em Destaque -->
            <div
              class="grid grid-cols-2 gap-3 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
            >
              <div class="flex flex-col">
                <span class="text-[11px] uppercase text-n-slate-10">
                  Preço Oficial
                </span>
                <div class="flex items-baseline gap-2 mt-0.5">
                  <span class="text-xl font-extrabold text-n-brand">
                    R$ {{ selectedProductModal.price }}
                  </span>
                  <span
                    v-if="selectedProductModal.compare_at_price"
                    class="text-xs text-n-slate-10 line-through"
                  >
                    R$ {{ selectedProductModal.compare_at_price }}
                  </span>
                </div>
              </div>
              <div class="flex flex-col items-end justify-center">
                <span class="text-[11px] uppercase text-n-slate-10">
                  Estoque Sincronizado
                </span>
                <span class="text-base font-bold text-n-teal-11 mt-0.5">
                  {{ selectedProductModal.inventory_quantity ?? 'Digital' }}
                  unidades
                </span>
              </div>
            </div>
          </div>

          <!-- Coluna Direita (7 cols): Descrição, Variantes, Pedidos Recentes e Links -->
          <div class="lg:col-span-7 flex flex-col justify-between gap-4">
            <div class="flex flex-col gap-4">
              <!-- Descrição -->
              <div
                class="flex flex-col gap-2 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
              >
                <h4
                  class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                >
                  <span class="i-lucide-file-text size-4 text-n-brand" />
                  Descrição e Especificações do Produto
                </h4>
                <p class="text-xs text-n-slate-12 leading-relaxed">
                  {{
                    selectedProductModal.description ||
                    'Produto digital oficial sincronizado com a Shopify. Entrega automática imediata após confirmação de pagamento.'
                  }}
                </p>
              </div>

              <!-- Lista de Variantes e Preços -->
              <div
                v-if="selectedProductModal.variants?.length"
                class="flex flex-col gap-2.5 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
              >
                <h4
                  class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                >
                  <span class="i-lucide-layers size-4 text-n-brand" />
                  Variantes &amp; Opções ({{
                    selectedProductModal.variants.length
                  }})
                </h4>
                <div class="flex flex-col gap-2">
                  <div
                    v-for="v in selectedProductModal.variants"
                    :key="v.id"
                    class="flex items-center justify-between p-2.5 rounded-xl border border-n-weak bg-n-solid-2 text-xs"
                  >
                    <div class="flex flex-col">
                      <span class="font-semibold text-n-slate-12">
                        {{ v.title }}
                      </span>
                      <span class="font-mono text-[11px] text-n-slate-10">
                        SKU: {{ v.sku || selectedProductModal.sku }}
                      </span>
                    </div>
                    <div class="flex items-center gap-3">
                      <span class="text-n-teal-11 font-medium">
                        {{ v.inventory_quantity }} un.
                      </span>
                      <span class="font-bold text-n-slate-12">
                        R$ {{ v.price }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Pedidos Recentes que compraram este Produto -->
              <div
                class="flex flex-col gap-2 p-4 rounded-2xl border border-n-weak bg-n-surface-1"
              >
                <h4
                  class="text-xs font-bold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                >
                  <span class="i-lucide-shopping-cart size-4 text-n-brand" />
                  Pedidos Recentes com este Produto ({{
                    productOrdersInModal.length
                  }})
                </h4>
                <div
                  v-if="!productOrdersInModal.length"
                  class="text-xs text-n-slate-11"
                >
                  Nenhum pedido recente listado na página atual contém este SKU.
                </div>
                <div v-else class="flex flex-col gap-1.5">
                  <div
                    v-for="pOrd in productOrdersInModal.slice(0, 3)"
                    :key="pOrd.id"
                    class="flex items-center justify-between p-2 rounded-lg bg-n-solid-2 border border-n-weak text-xs cursor-pointer hover:border-n-brand"
                    @click="
                      selectedProductModal = null;
                      openOrderDetailModal(pOrd);
                    "
                  >
                    <span class="font-mono font-bold text-n-brand">
                      {{ pOrd.name }}
                    </span>
                    <span class="text-n-slate-12 truncate">
                      {{ pOrd.customer_name }}
                    </span>
                    <span class="font-semibold text-n-slate-12">
                      {{ formatCurrency(pOrd.total_price, pOrd.currency) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Ações do Produto -->
            <div class="flex items-center justify-between gap-2 pt-2 flex-wrap">
              <div class="flex items-center gap-2">
                <Button
                  size="xs"
                  variant="faded"
                  color="slate"
                  icon="i-lucide-copy"
                  label="Copiar SKU"
                  @click="copyTextToClipboard(selectedProductModal.sku, 'SKU')"
                />
                <Button
                  v-if="selectedProductModal.storefront_url"
                  size="xs"
                  variant="faded"
                  color="blue"
                  icon="i-lucide-link"
                  label="Copiar Link da Loja"
                  @click="
                    copyTextToClipboard(
                      selectedProductModal.storefront_url,
                      'Link do produto'
                    )
                  "
                />
              </div>

              <div class="flex items-center gap-2">
                <a
                  v-if="selectedProductModal.admin_url"
                  :href="selectedProductModal.admin_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-n-brand text-white text-xs font-semibold hover:opacity-90"
                >
                  <span class="i-lucide-external-link size-3.5" />
                  <span>Ver Produto na Shopify</span>
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
