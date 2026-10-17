<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Integration from './Integration.vue';
import integrationAPI from 'dashboard/api/integrations';
import ShopifyAPI from 'dashboard/api/integrations/shopify';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShopifyOrderItem from 'dashboard/components/widgets/conversation/ShopifyOrderItem.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const integrationLoaded = ref(false);

const showStoreSwitcherDropdown = ref(false);
const selectedHookId = ref(null);

const editingHookId = ref(null);
const storeName = ref('');
const storeUrl = ref('');
const shopifyAdminKey = ref('');
const selectedInboxIds = ref([]);
const isSubmitting = ref(false);
const formError = ref('');

const activeStoreName = ref('');
const activeStoreUrl = ref('');
const activeShopifyAdminKey = ref('');
const activeSelectedInboxIds = ref([]);
const isUpdatingActiveStore = ref(false);
const activeStoreError = ref('');

const previewOrders = ref([]);
const previewSearchQuery = ref('');
const isLoadingPreview = ref(false);

const integration = useFunctionGetter('integrations/getIntegration', 'shopify');
const uiFlags = useMapGetter('integrations/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');

const hooks = computed(() => integration.value?.hooks || []);

const activeHook = computed(() => {
  if (!hooks.value.length) return null;
  return (
    hooks.value.find(h => Number(h.id) === Number(selectedHookId.value)) ||
    hooks.value[0]
  );
});

const activeHookDisplayName = computed(() => {
  if (!activeHook.value) {
    return t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.NEW_STORE');
  }
  return (
    activeHook.value.settings?.store_name ||
    activeHook.value.reference_id ||
    t('INTEGRATION_SETTINGS.SHOPIFY.HEADER')
  );
});

const isMockStore = hook => {
  return hook?.settings?.auth_mode === 'mock';
};

const normalizeStoreDomain = rawUrl => {
  const cleaned = (rawUrl || '')
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//i, '')
    .replace(/\/.*$/, '');
  if (!cleaned) return '';
  if (
    /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.myshopify\.(?:com|io)$/i.test(cleaned)
  ) {
    return cleaned;
  }
  const slug = cleaned
    .replace(/\.(com\.br|com|net|org|io|store|shop)$/i, '')
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug ? `${slug}.myshopify.com` : '';
};

const syncActiveStoreForm = hook => {
  if (!hook) return;
  activeStoreName.value = hook.settings?.store_name || hook.reference_id || '';
  activeStoreUrl.value = hook.reference_id || '';
  activeShopifyAdminKey.value = '';
  activeSelectedInboxIds.value = Array.isArray(hook.settings?.inbox_ids)
    ? hook.settings.inbox_ids.map(Number)
    : [];
  activeStoreError.value = '';
};

const fetchPreviewOrders = async () => {
  if (!activeHook.value) {
    previewOrders.value = [];
    return;
  }
  try {
    isLoadingPreview.value = true;
    const response = await ShopifyAPI.getOrders({
      hookId: activeHook.value.id,
      query: previewSearchQuery.value.trim() || undefined,
    });
    previewOrders.value = response.data?.orders || [];
  } catch {
    previewOrders.value = [];
  } finally {
    isLoadingPreview.value = false;
  }
};

watch(
  activeHook,
  newHook => {
    if (newHook) {
      selectedHookId.value = newHook.id;
      syncActiveStoreForm(newHook);
      fetchPreviewOrders();
    } else {
      previewOrders.value = [];
    }
  },
  { immediate: true }
);

const toggleStoreSwitcher = () => {
  showStoreSwitcherDropdown.value = !showStoreSwitcherDropdown.value;
};

const selectStoreFromDropdown = hook => {
  selectedHookId.value = hook.id;
  showStoreSwitcherDropdown.value = false;
};

const resetForm = () => {
  editingHookId.value = null;
  storeName.value = '';
  storeUrl.value = '';
  shopifyAdminKey.value = '';
  selectedInboxIds.value = [];
  formError.value = '';
  isSubmitting.value = false;
};

const openCreateDialog = () => {
  showStoreSwitcherDropdown.value = false;
  resetForm();
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const toggleInbox = inboxId => {
  const id = Number(inboxId);
  if (selectedInboxIds.value.includes(id)) {
    selectedInboxIds.value = selectedInboxIds.value.filter(i => i !== id);
  } else {
    selectedInboxIds.value = [...selectedInboxIds.value, id];
  }
};

const toggleActiveStoreInbox = inboxId => {
  const id = Number(inboxId);
  if (activeSelectedInboxIds.value.includes(id)) {
    activeSelectedInboxIds.value = activeSelectedInboxIds.value.filter(
      i => i !== id
    );
  } else {
    activeSelectedInboxIds.value = [...activeSelectedInboxIds.value, id];
  }
};

const handleStoreSubmit = async () => {
  try {
    formError.value = '';
    const trimmedName = storeName.value.trim();
    const cleanDomain = normalizeStoreDomain(
      storeUrl.value.trim() || trimmedName
    );

    if (!cleanDomain) {
      formError.value = t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.INVALID_URL');
      return;
    }

    storeUrl.value = cleanDomain;
    isSubmitting.value = true;

    const { data } = await integrationAPI.connectShopifyToken({
      storeName:
        trimmedName || cleanDomain.replace(/\.myshopify\.(com|io)$/i, ''),
      shopDomain: cleanDomain,
      shopifyAdminKey: shopifyAdminKey.value.trim(),
      inboxIds: selectedInboxIds.value,
    });

    await store.dispatch('integrations/get', 'shopify');
    if (data?.hook?.id) {
      selectedHookId.value = data.hook.id;
    }
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONNECTED_SUCCESS'));
    dialogRef.value?.close();
    resetForm();
  } catch (err) {
    formError.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.SHOPIFY.ERROR');
  } finally {
    isSubmitting.value = false;
  }
};

const handleActiveStoreSave = async () => {
  if (!activeHook.value) return;
  try {
    activeStoreError.value = '';
    isUpdatingActiveStore.value = true;
    const cleanDomain = normalizeStoreDomain(
      activeStoreUrl.value.trim() || activeStoreName.value.trim()
    );

    await integrationAPI.updateShopifyHook({
      hookId: activeHook.value.id,
      storeName: activeStoreName.value.trim(),
      shopDomain: cleanDomain || activeHook.value.reference_id,
      shopifyAdminKey: activeShopifyAdminKey.value.trim(),
      inboxIds: activeSelectedInboxIds.value,
    });
    await store.dispatch('integrations/get', 'shopify');
    activeShopifyAdminKey.value = '';
    await fetchPreviewOrders();
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.UPDATED_SUCCESS'));
  } catch (err) {
    activeStoreError.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.SHOPIFY.ERROR');
  } finally {
    isUpdatingActiveStore.value = false;
  }
};

const handleDeleteHook = async hook => {
  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONFIRM_DELETE', {
      store: hook.settings?.store_name || hook.reference_id,
    })
  );
  if (!confirmed) return;

  try {
    await integrationAPI.deleteShopifyHook(hook.id);
    await store.dispatch('integrations/get', 'shopify');
    if (selectedHookId.value === hook.id) {
      selectedHookId.value = hooks.value[0]?.id || null;
    }
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.DELETED_SUCCESS'));
  } catch (err) {
    useAlert(
      err.response?.data?.error ||
        err.message ||
        t('INTEGRATION_SETTINGS.SHOPIFY.ERROR')
    );
  }
};

const initializeShopifyIntegration = async () => {
  await Promise.all([
    store.dispatch('integrations/get', 'shopify'),
    store.dispatch('inboxes/get'),
  ]);
  if (hooks.value.length && !selectedHookId.value) {
    selectedHookId.value = hooks.value[0].id;
  }
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeShopifyIntegration();
});
</script>

<template>
  <SettingsLayout :is-loading="!integrationLoaded || uiFlags.isCreatingShopify">
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.SHOPIFY.HEADER')"
        description=""
        feature-name="shopify_integration"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template #title>
          <div class="flex flex-wrap items-center justify-between w-full gap-4">
            <div class="flex items-center gap-3">
              <!-- Store Switcher Dropdown (Exact same pattern as Captain Assistant Switcher) -->
              <div class="flex items-center gap-2">
                <Avatar
                  :name="activeHookDisplayName"
                  :size="28"
                  icon-name="i-lucide-shopping-bag"
                  rounded-full
                />
                <span class="text-xl font-medium truncate text-n-slate-12">
                  {{ activeHookDisplayName }}
                </span>
                <div class="relative group">
                  <OnClickOutside @trigger="showStoreSwitcherDropdown = false">
                    <Button
                      icon="i-lucide-chevron-down"
                      :variant="showStoreSwitcherDropdown ? 'faded' : 'ghost'"
                      color="slate"
                      size="xs"
                      class="rounded-md group-hover:bg-n-slate-3 hover:bg-n-slate-3 [&>span]:size-4"
                      @click="toggleStoreSwitcher"
                    />

                    <!-- Dropdown Popover -->
                    <div
                      v-if="showStoreSwitcherDropdown"
                      class="pt-5 bg-n-alpha-3 backdrop-blur-[100px] outline outline-n-container outline-1 z-50 absolute ltr:left-0 rtl:right-0 top-9 w-[28rem] max-h-96 rounded-xl shadow-md flex flex-col gap-4"
                    >
                      <div
                        class="flex items-center justify-between gap-4 px-6 pb-3 border-b border-n-alpha-2"
                      >
                        <div class="flex flex-col gap-1">
                          <div class="flex items-center gap-2">
                            <h2
                              class="text-base font-medium text-n-slate-12 w-fit"
                            >
                              {{
                                `${t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONNECTED_STORES')} (${hooks.length})`
                              }}
                            </h2>
                          </div>
                          <p class="text-sm text-n-slate-11">
                            {{
                              t(
                                'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.SWITCH_STORE'
                              )
                            }}
                          </p>
                        </div>
                        <Button
                          :label="
                            t(
                              'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.NEW_STORE'
                            )
                          "
                          color="slate"
                          icon="i-lucide-plus"
                          size="sm"
                          class="!bg-n-alpha-2 hover:!bg-n-alpha-3"
                          @click="openCreateDialog"
                        />
                      </div>

                      <div
                        v-if="hooks.length > 0"
                        class="flex flex-col flex-1 min-h-0 gap-1.5 px-4 pb-3 overflow-y-auto overscroll-contain"
                      >
                        <Button
                          v-for="hook in hooks"
                          :key="hook.id"
                          :label="
                            hook.settings?.store_name || hook.reference_id
                          "
                          variant="ghost"
                          color="slate"
                          trailing-icon
                          :icon="
                            activeHook?.id === hook.id ? 'i-lucide-check' : ''
                          "
                          class="!justify-end !px-2.5 !py-2 hover:!bg-n-alpha-2 [&>.i-lucide-check]:text-n-teal-10 h-10"
                          size="sm"
                          @click="selectStoreFromDropdown(hook)"
                        >
                          <div
                            class="flex items-center justify-between flex-1 min-w-0 gap-2 mr-2"
                          >
                            <span
                              class="text-sm font-medium truncate text-n-slate-12"
                            >
                              {{
                                hook.settings?.store_name || hook.reference_id
                              }}
                            </span>
                            <span
                              class="text-[11px] px-1.5 py-0.5 rounded font-medium shrink-0"
                              :class="
                                isMockStore(hook)
                                  ? 'bg-n-amber-3 text-n-amber-11'
                                  : 'bg-n-teal-3 text-n-teal-11'
                              "
                            >
                              {{
                                isMockStore(hook)
                                  ? t(
                                      'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.MOCK_SHORT'
                                    )
                                  : hook.reference_id
                              }}
                            </span>
                          </div>
                          <Avatar
                            :name="
                              hook.settings?.store_name || hook.reference_id
                            "
                            :size="20"
                            icon-name="i-lucide-shopping-bag"
                            rounded-full
                          />
                        </Button>
                      </div>
                      <div
                        v-else
                        class="flex flex-col items-center gap-2 px-4 py-3"
                      >
                        <p class="text-sm text-n-slate-11">
                          {{
                            t(
                              'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.EMPTY_LIST'
                            )
                          }}
                        </p>
                      </div>
                    </div>
                  </OnClickOutside>
                </div>
              </div>

              <div class="w-0.5 h-4 rounded-2xl bg-n-weak" />
              <span class="text-xl font-medium text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.SHOPIFY.HEADER') }}
              </span>

              <span
                v-if="activeHook"
                class="text-xs px-2.5 py-1 rounded-full font-medium"
                :class="
                  isMockStore(activeHook)
                    ? 'bg-n-amber-3 text-n-amber-11'
                    : 'bg-n-teal-3 text-n-teal-11'
                "
              >
                {{
                  isMockStore(activeHook)
                    ? t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.MOCK_BADGE')
                    : t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.LIVE_BADGE')
                }}
              </span>
            </div>

            <div class="flex items-center gap-2">
              <Button
                teal
                icon="i-lucide-plus"
                size="sm"
                :label="
                  t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ADD_BUTTON')
                "
                @click="openCreateDialog"
              />
            </div>
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-6">
        <Integration
          v-if="!hooks.length"
          :integration-id="integration.id"
          :integration-logo="integration.logo"
          :integration-name="integration.name"
          :integration-description="integration.description"
          :integration-enabled="integration.enabled"
          integration-action="connect"
          :delete-confirmation-text="{
            title: t('INTEGRATION_SETTINGS.SHOPIFY.DELETE.TITLE'),
            message: t('INTEGRATION_SETTINGS.SHOPIFY.DELETE.MESSAGE'),
          }"
        >
          <template #action>
            <Button
              teal
              icon="i-lucide-plus"
              :label="t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ADD_BUTTON')"
              @click="openCreateDialog"
            />
          </template>
        </Integration>

        <div
          v-if="activeHook"
          class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start"
        >
          <div
            class="lg:col-span-7 flex flex-col gap-5 outline outline-n-container outline-1 bg-n-alpha-3 rounded-xl shadow-sm p-6"
          >
            <div
              class="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-n-weak"
            >
              <div class="flex flex-col gap-1">
                <div class="flex items-center gap-2">
                  <h3 class="text-base font-semibold text-n-slate-12">
                    {{ activeHookDisplayName }}
                  </h3>
                  <span
                    class="text-xs px-2 py-0.5 rounded bg-n-solid-3 text-n-slate-11 font-mono"
                  >
                    {{ activeHook.reference_id }}
                  </span>
                </div>
                <p class="text-xs text-n-slate-11">
                  {{
                    t(
                      'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.STORE_CONFIG_DESC'
                    )
                  }}
                </p>
              </div>

              <Button
                faded
                ruby
                xs
                icon="i-lucide-trash-2"
                :label="t('INTEGRATION_SETTINGS.DELETE.BUTTON_TEXT')"
                @click="handleDeleteHook(activeHook)"
              />
            </div>

            <div class="flex flex-col gap-4">
              <Input
                v-model="activeStoreName"
                :label="
                  t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.STORE_NAME_LABEL')
                "
                :placeholder="
                  t(
                    'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.STORE_NAME_PLACEHOLDER'
                  )
                "
              />

              <Input
                v-model="activeStoreUrl"
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.LABEL')"
                :placeholder="
                  t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.PLACEHOLDER')
                "
                :message="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.HELP')"
                message-type="info"
              />

              <Input
                v-model="activeShopifyAdminKey"
                type="password"
                :label="
                  t(
                    'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_LABEL'
                  )
                "
                :placeholder="
                  t(
                    'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_KEEP_PLACEHOLDER'
                  )
                "
                :message="
                  t(
                    'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_HELP'
                  )
                "
                message-type="info"
              />

              <div class="flex flex-col gap-1.5">
                <label class="text-sm font-medium text-n-slate-12">
                  {{
                    t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.INBOXES_LABEL')
                  }}
                </label>
                <p class="text-xs text-n-slate-11 mb-1">
                  {{
                    t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.INBOXES_HELP')
                  }}
                </p>
                <div
                  class="max-h-44 overflow-y-auto border border-n-weak rounded-lg p-2.5 grid grid-cols-1 sm:grid-cols-2 gap-1.5 bg-n-alpha-1"
                >
                  <label
                    v-for="inbox in inboxes"
                    :key="inbox.id"
                    class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer hover:bg-n-alpha-2 px-2 py-1.5 rounded"
                  >
                    <input
                      type="checkbox"
                      :checked="
                        activeSelectedInboxIds.includes(Number(inbox.id))
                      "
                      @change="toggleActiveStoreInbox(inbox.id)"
                    />
                    <span class="truncate">{{ inbox.name }}</span>
                  </label>
                </div>
              </div>

              <p
                v-if="activeStoreError"
                class="text-xs text-n-ruby-9 font-medium"
              >
                {{ activeStoreError }}
              </p>

              <div class="flex items-center justify-end gap-2 pt-2">
                <Button
                  teal
                  :is-loading="isUpdatingActiveStore"
                  :label="
                    t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.SAVE_CHANGES')
                  "
                  @click="handleActiveStoreSave"
                />
              </div>
            </div>
          </div>

          <div
            class="lg:col-span-5 flex flex-col gap-4 outline outline-n-container outline-1 bg-n-alpha-3 rounded-xl shadow-sm p-5"
          >
            <div class="flex flex-col gap-1 pb-3 border-b border-n-weak">
              <div class="flex items-center justify-between gap-2">
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{
                    t(
                      'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.PREVIEW_ORDERS_TITLE',
                      { store: activeHookDisplayName }
                    )
                  }}
                </h3>
                <span
                  class="text-[11px] px-2 py-0.5 rounded font-medium"
                  :class="
                    isMockStore(activeHook)
                      ? 'bg-n-amber-3 text-n-amber-11'
                      : 'bg-n-teal-3 text-n-teal-11'
                  "
                >
                  {{ previewOrders.length }}
                </span>
              </div>
              <p class="text-xs text-n-slate-11">
                {{
                  t(
                    'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.PREVIEW_ORDERS_DESC'
                  )
                }}
              </p>
            </div>

            <form
              class="flex items-center gap-1.5"
              @submit.prevent="fetchPreviewOrders"
            >
              <input
                v-model="previewSearchQuery"
                type="text"
                :placeholder="
                  $t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_PLACEHOLDER')
                "
                class="flex-1 min-w-0 text-xs px-2.5 py-1.5 rounded border border-n-weak bg-n-alpha-1 text-n-slate-12 focus:outline-none focus:border-n-brand"
              />
              <Button
                type="submit"
                size="xs"
                teal
                :label="$t('CONVERSATION_SIDEBAR.SHOPIFY.SEARCH_BUTTON')"
              />
            </form>

            <div
              v-if="isLoadingPreview"
              class="flex justify-center items-center py-8"
            >
              <Spinner size="28" class="text-n-brand" />
            </div>
            <div
              v-else-if="!previewOrders.length"
              class="text-center text-xs text-n-slate-11 py-6"
            >
              {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.NO_SHOPIFY_ORDERS') }}
            </div>
            <div
              v-else
              class="flex flex-col max-h-[28rem] overflow-y-auto pr-1"
            >
              <ShopifyOrderItem
                v-for="order in previewOrders"
                :key="`${order.hook_id}-${order.id}`"
                :order="order"
              />
            </div>
          </div>
        </div>

        <Dialog
          ref="dialogRef"
          :title="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.TITLE')"
          :is-loading="isSubmitting"
          @confirm="handleStoreSubmit"
          @close="resetForm"
        >
          <div class="flex flex-col gap-4">
            <Input
              v-model="storeName"
              :label="
                t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.STORE_NAME_LABEL')
              "
              :placeholder="
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.STORE_NAME_PLACEHOLDER'
                )
              "
            />

            <Input
              v-model="storeUrl"
              :label="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.LABEL')"
              :placeholder="
                t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.PLACEHOLDER')
              "
              :message="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.HELP')"
              message-type="info"
            />

            <Input
              v-model="shopifyAdminKey"
              type="password"
              :label="
                t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_LABEL')
              "
              :placeholder="
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_PLACEHOLDER'
                )
              "
              :message="
                t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_HELP')
              "
              message-type="info"
            />

            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-slate-12">
                {{
                  t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.INBOXES_LABEL')
                }}
              </label>
              <p class="text-xs text-n-slate-11 mb-1">
                {{ t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.INBOXES_HELP') }}
              </p>
              <div
                class="max-h-40 overflow-y-auto border border-n-weak rounded-md p-2 flex flex-col gap-1.5"
              >
                <label
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer hover:bg-n-alpha-2 px-1.5 py-1 rounded"
                >
                  <input
                    type="checkbox"
                    :checked="selectedInboxIds.includes(Number(inbox.id))"
                    @change="toggleInbox(inbox.id)"
                  />
                  <span>{{ inbox.name }}</span>
                </label>
              </div>
            </div>

            <p v-if="formError" class="text-xs text-n-ruby-9 font-medium">
              {{ formError }}
            </p>
          </div>
        </Dialog>
      </div>
    </template>
  </SettingsLayout>
</template>
