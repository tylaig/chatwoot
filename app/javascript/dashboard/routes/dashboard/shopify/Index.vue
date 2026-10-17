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
const searchQuery = ref('');

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
  router.push(
    accountScopedRoute('settings_integrations_integration', {
      integration_id: 'shopify',
    })
  );
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

watch(selectedHookId, () => {
  refreshAllData();
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
      <div class="w-full max-w-[78rem] mx-auto">
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
          <div class="flex items-center gap-2 w-full lg:w-auto">
            <form
              class="flex items-center gap-1.5 flex-1 lg:w-96"
              @submit.prevent="handleSearchSubmit"
            >
              <div class="relative flex-1">
                <input
                  v-model="searchQuery"
                  type="text"
                  placeholder="Buscar por #pedido, cliente, e-mail, telefone ou SKU..."
                  class="w-full h-9 pl-8 pr-7 text-xs rounded-lg border border-n-weak bg-n-solid-2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
                />
                <span
                  class="i-lucide-search size-3.5 text-n-slate-10 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none"
                />
                <button
                  v-if="searchQuery"
                  type="button"
                  class="i-lucide-x size-3.5 text-n-slate-10 hover:text-n-slate-12 absolute right-2 top-1/2 -translate-y-1/2"
                  @click="clearSearch"
                />
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

          <!-- Resumo rápido de status -->
          <div
            class="hidden md:flex items-center gap-4 text-xs text-n-slate-11"
          >
            <span class="flex items-center gap-1.5">
              <span class="size-2 rounded-full bg-n-amber-9" />
              Em janela &lt; 1h:
              <strong class="text-n-slate-12">{{ pendingUnder1hCount }}</strong>
            </span>
            <span class="flex items-center gap-1.5">
              <span class="size-2 rounded-full bg-n-teal-9" />
              Concluídos:
              <strong class="text-n-slate-12">{{ fulfilledCount }}</strong>
            </span>
          </div>
        </div>
      </div>
    </header>

    <!-- Conteúdo Principal -->
    <main class="flex-1 overflow-y-auto px-6 py-6">
      <div class="w-full max-w-[78rem] mx-auto">
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

        <!-- ABA 1: LISTA DE PEDIDOS -->
        <div v-else-if="activeTab === 'orders'" class="flex flex-col gap-4">
          <div
            v-if="isLoadingOrders"
            class="flex items-center justify-center py-16"
          >
            <Spinner />
          </div>

          <div
            v-else-if="!orders.length"
            class="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-n-weak bg-n-solid-2"
          >
            <span class="i-lucide-package-search size-8 text-n-slate-10 mb-2" />
            <p class="text-sm font-medium text-n-slate-12">
              Nenhum pedido encontrado para este filtro
            </p>
            <p class="text-xs text-n-slate-11 mt-1">
              Experimente buscar por outro número de pedido (ex: #31652) ou
              e-mail de cliente.
            </p>
          </div>

          <div
            v-else
            class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4"
          >
            <div
              v-for="order in orders"
              :key="`${order.hook_id}-${order.id}`"
              class="flex flex-col justify-between rounded-2xl border border-n-weak bg-n-solid-2 p-4 shadow-sm hover:border-n-brand/40 transition-colors"
            >
              <!-- Cabeçalho do Cliente no Card do Pedido -->
              <div
                class="flex items-center justify-between gap-2 pb-3 mb-1 border-b border-n-weak"
              >
                <div class="flex items-center gap-2.5 min-w-0">
                  <div
                    class="flex items-center justify-center size-8 rounded-full bg-n-brand/10 text-n-brand font-semibold text-xs shrink-0"
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
                    <span class="text-[11px] text-n-slate-11 truncate">
                      {{ order.email }}
                      <template v-if="order.phone">
                        • {{ order.phone }}
                      </template>
                    </span>
                  </div>
                </div>
                <span
                  class="px-2 py-0.5 text-[10px] font-medium rounded-full shrink-0"
                  :class="
                    order.auth_mode === 'mock'
                      ? 'bg-n-amber-3 text-n-amber-11'
                      : 'bg-n-teal-3 text-n-teal-11'
                  "
                >
                  {{ order.store_name }}
                </span>
              </div>

              <!-- Componente de detalhes do pedido -->
              <ShopifyOrderItem :order="order" />
            </div>
          </div>
        </div>

        <!-- ABA 2: LISTA DE CLIENTES -->
        <div v-else-if="activeTab === 'customers'" class="flex flex-col gap-4">
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
                  class="hover:bg-n-alpha-1 transition-colors"
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
                  <td class="py-3.5 px-4 text-right">
                    <Button
                      size="xs"
                      variant="faded"
                      color="slate"
                      icon="i-lucide-shopping-bag"
                      label="Ver Pedidos"
                      @click="filterOrdersByCustomerEmail(customer.email)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- ABA 3: PRODUTOS DA LOJA -->
        <div v-else-if="activeTab === 'products'" class="flex flex-col gap-4">
          <div class="flex items-center justify-between">
            <span class="text-xs text-n-slate-11">
              Exibindo produtos sincronizados de
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

          <div
            v-else
            class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
          >
            <div
              v-for="product in products"
              :key="`${product.hook_id}-${product.id}`"
              class="flex flex-col justify-between p-4 rounded-2xl border border-n-weak bg-n-solid-2 gap-3"
            >
              <div class="flex flex-col gap-1.5">
                <div class="flex items-center justify-between gap-2">
                  <span
                    class="px-2 py-0.5 text-[10px] font-medium rounded-full bg-n-brand/10 text-n-brand"
                  >
                    {{ product.store_name }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-[10px] font-medium rounded-full bg-n-teal-3 text-n-teal-11"
                  >
                    Ativo
                  </span>
                </div>
                <h4 class="text-sm font-semibold text-n-slate-12">
                  {{ product.title }}
                </h4>
                <div
                  class="flex items-center gap-2 text-xs text-n-slate-10 font-mono"
                >
                  <span v-if="product.sku">SKU: {{ product.sku }}</span>
                  <span v-if="product.product_type">
                    • {{ product.product_type }}
                  </span>
                </div>
              </div>
              <div
                class="flex items-center justify-between pt-3 border-t border-n-weak"
              >
                <span class="text-base font-bold text-n-slate-12">
                  R$ {{ product.price }}
                </span>
                <span class="text-xs text-n-slate-11">
                  Estoque:
                  <strong class="text-n-slate-12">
                    {{ product.inventory_quantity ?? 'Digital' }}
                  </strong>
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </section>
</template>
