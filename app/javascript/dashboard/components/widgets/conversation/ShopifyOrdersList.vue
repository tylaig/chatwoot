<script setup>
import { ref, watch, computed } from 'vue';
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

const effectiveInboxId = computed(
  () => props.inboxId || currentChat.value?.inbox_id
);

const hasSearchableInfo = computed(
  () => !!contact.value?.email || !!contact.value?.phone_number
);

const searchQuery = ref('');
const syncEmailToContact = ref(true);
const orders = ref([]);
const loading = ref(false);
const error = ref('');

const fetchOrders = async (manualQuery = '') => {
  const queryToUse = manualQuery.trim() || searchQuery.value.trim();
  if (!queryToUse && !hasSearchableInfo.value) {
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

const clearSearch = () => {
  searchQuery.value = '';
  fetchOrders('');
};

watch(
  () => [props.contactId, contact.value?.email, contact.value?.phone_number],
  () => {
    if (hasSearchableInfo.value || searchQuery.value.trim()) {
      fetchOrders();
    } else {
      orders.value = [];
    }
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12 flex flex-col gap-3">
    <form class="flex flex-col gap-2" @submit.prevent="handleSearchSubmit">
      <div class="flex items-center gap-1.5">
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="$t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_PLACEHOLDER')"
          class="flex-1 min-w-0 text-xs px-2.5 py-1.5 rounded border border-n-weak bg-n-alpha-1 text-n-slate-12 focus:outline-none focus:border-n-brand"
        />
        <button
          v-if="searchQuery"
          type="button"
          :aria-label="$t('CONVERSATION_SIDEBAR.SHOPIFY.CLEAR_BUTTON')"
          class="text-xs px-2 py-1.5 rounded bg-n-solid-3 text-n-slate-11 hover:text-n-slate-12 flex items-center justify-center"
          @click="clearSearch"
        >
          <i class="i-lucide-x text-xs" />
        </button>
        <button
          type="submit"
          class="text-xs px-2.5 py-1.5 rounded bg-n-brand text-white font-medium hover:opacity-90"
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
      v-if="!hasSearchableInfo && !searchQuery.trim() && !loading"
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
