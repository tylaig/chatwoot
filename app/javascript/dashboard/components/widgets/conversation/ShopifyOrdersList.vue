<script setup>
import { ref, watch, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShopifyAPI from '../../../api/integrations/shopify';
import ShopifyOrderItem from './ShopifyOrderItem.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: [Number, String],
    default: undefined,
  },
});

const store = useStore();
const contact = useFunctionGetter('contacts/getContact', props.contactId);
const currentChat = useMapGetter('getSelectedChat');
const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);

const hooks = computed(() => shopifyIntegration.value?.hooks || []);

const effectiveInboxId = computed(
  () => props.inboxId || currentChat.value?.inbox_id
);

const hasSearchableInfo = computed(
  () => !!contact.value?.email || !!contact.value?.phone_number
);

const hasMockStores = computed(() =>
  hooks.value.some(h => h.settings?.auth_mode === 'mock')
);

const selectedHookId = ref('');
const searchQuery = ref('');
const syncEmailToContact = ref(true);
const orders = ref([]);
const loading = ref(false);
const error = ref('');

const formatHookOptionLabel = hook => {
  const baseName = hook.settings?.store_name || hook.reference_id;
  return hook.settings?.auth_mode === 'mock' ? `${baseName} [Mock]` : baseName;
};

const fetchOrders = async (manualQuery = '') => {
  const queryToUse = manualQuery.trim() || searchQuery.value.trim();
  if (!queryToUse && !hasSearchableInfo.value && !hasMockStores.value) {
    orders.value = [];
    loading.value = false;
    return;
  }

  try {
    loading.value = true;
    error.value = '';
    const shouldSync =
      syncEmailToContact.value &&
      !contact.value?.email &&
      queryToUse.includes('@');

    const response = await ShopifyAPI.getOrders({
      contactId: props.contactId,
      query: queryToUse || undefined,
      inboxId: effectiveInboxId.value,
      hookId: selectedHookId.value || undefined,
      syncContactEmail: shouldSync,
    });
    orders.value = response.data.orders || [];

    if (shouldSync && orders.value.length > 0) {
      store.dispatch('contacts/show', { id: props.contactId });
    }
  } catch (e) {
    error.value =
      e.response?.data?.error || 'CONVERSATION_SIDEBAR.SHOPIFY.ERROR';
  } finally {
    loading.value = false;
  }
};

const handleSearchSubmit = () => {
  fetchOrders(searchQuery.value);
};

const handleStoreFilterChange = () => {
  fetchOrders(searchQuery.value);
};

const clearSearch = () => {
  searchQuery.value = '';
  fetchOrders('');
};

onMounted(() => {
  if (!hooks.value.length) {
    store.dispatch('integrations/get', 'shopify');
  }
});

watch(
  () => [
    props.contactId,
    contact.value?.email,
    contact.value?.phone_number,
    hasMockStores.value,
  ],
  () => {
    if (
      hasSearchableInfo.value ||
      searchQuery.value.trim() ||
      hasMockStores.value
    ) {
      fetchOrders();
    } else {
      orders.value = [];
    }
  },
  { immediate: true }
);
</script>

<!-- eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template -->
<template>
  <div class="px-4 py-2 text-n-slate-12 flex flex-col gap-3">
    <!-- Resumo automático do e-mail/telefone do usuário na conversa -->
    <div
      v-if="contact?.email || contact?.phone_number"
      class="flex items-center justify-between gap-2 px-2.5 py-1.5 rounded-lg bg-n-alpha-1 border border-n-weak text-[11px]"
    >
      <div class="flex items-center gap-1.5 min-w-0">
        <span class="i-lucide-mail size-3.5 text-n-brand shrink-0" />
        <span class="text-n-slate-11 truncate">
          Pedidos vinculados a:
          <strong class="text-n-slate-12 font-medium">
            {{ contact.email || contact.phone_number }}
          </strong>
        </span>
      </div>
      <span
        v-if="orders.length"
        class="px-1.5 py-0.5 rounded-full bg-n-brand/10 text-n-brand font-semibold text-[10px] shrink-0"
      >
        {{ orders.length }} recente(s)
      </span>
    </div>

    <form class="flex flex-col gap-2" @submit.prevent="handleSearchSubmit">
      <div v-if="hooks.length > 1" class="flex items-center gap-1.5">
        <select
          v-model="selectedHookId"
          class="reset-base no-margin w-full h-8 text-xs px-2.5 py-1 rounded-lg border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
          @change="handleStoreFilterChange"
        >
          <option value="">
            {{
              `${$t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ALL_STORES')} (${hooks.length})`
            }}
          </option>
          <option v-for="hook in hooks" :key="hook.id" :value="hook.id">
            {{ formatHookOptionLabel(hook) }}
          </option>
        </select>
      </div>

      <div class="flex items-center gap-1.5">
        <div
          class="flex items-center gap-1.5 flex-1 h-8 px-2.5 rounded-lg border border-n-weak bg-n-solid-2 focus-within:border-n-brand transition-colors"
        >
          <span class="i-lucide-search size-3.5 text-n-slate-10 shrink-0" />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="$t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_PLACEHOLDER')"
            class="reset-base no-margin flex-1 min-w-0 h-full bg-transparent border-0 outline-none focus:outline-none text-xs text-n-slate-12 placeholder:text-n-slate-10"
          />
          <button
            v-if="searchQuery"
            type="button"
            :aria-label="$t('CONVERSATION_SIDEBAR.SHOPIFY.CLEAR_BUTTON')"
            class="flex items-center justify-center size-4 rounded text-n-slate-10 hover:text-n-slate-12 !p-0 shrink-0"
            @click="clearSearch"
          >
            <i class="i-lucide-x text-xs" />
          </button>
        </div>
        <button
          type="submit"
          class="h-8 text-xs px-3 rounded-lg bg-n-brand text-white font-medium hover:opacity-90 shrink-0"
        >
          {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_BUTTON') }}
        </button>
      </div>
      <label
        v-if="!contact?.email && searchQuery.includes('@')"
        class="flex items-center gap-1.5 text-xs text-n-slate-11 cursor-pointer"
      >
        <input v-model="syncEmailToContact" type="checkbox" />
        <span>{{ $t('CONVERSATION_SIDEBAR.SHOPIFY.SYNC_EMAIL_LABEL') }}</span>
      </label>
    </form>

    <div
      v-if="
        !hasSearchableInfo && !searchQuery.trim() && !hasMockStores && !loading
      "
      class="text-center text-xs text-n-slate-11 py-2"
    >
      {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_HINT') }}
    </div>
    <div v-else-if="loading" class="flex justify-center items-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="error" class="text-center text-xs text-n-ruby-12 py-2">
      {{ error }}
    </div>
    <div
      v-else-if="!orders.length"
      class="text-center text-xs text-n-slate-11 py-2"
    >
      {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.NO_SHOPIFY_ORDERS') }}
    </div>
    <div v-else class="flex flex-col">
      <ShopifyOrderItem
        v-for="order in orders"
        :key="`${order.hook_id || 'default'}-${order.id}`"
        :order="order"
      />
    </div>
  </div>
</template>
