<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Integration from './Integration.vue';
import integrationAPI from 'dashboard/api/integrations';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

defineProps({
  error: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const integrationLoaded = ref(false);

const editingHookId = ref(null);
const storeName = ref('');
const storeUrl = ref('');
const shopifyAdminKey = ref('');
const selectedInboxIds = ref([]);
const isSubmitting = ref(false);
const formError = ref('');

const integration = useFunctionGetter('integrations/getIntegration', 'shopify');
const uiFlags = useMapGetter('integrations/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');

const hooks = computed(() => integration.value?.hooks || []);

const validateStoreUrl = url => {
  const pattern =
    /^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.myshopify\.(?:com|io)$/i;
  return pattern.test(url.trim());
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
  resetForm();
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const openEditDialog = hook => {
  resetForm();
  editingHookId.value = hook.id;
  storeName.value = hook.settings?.store_name || hook.reference_id || '';
  storeUrl.value = hook.reference_id || '';
  selectedInboxIds.value = Array.isArray(hook.settings?.inbox_ids)
    ? hook.settings.inbox_ids.map(Number)
    : [];
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

const getInboxName = inboxId => {
  const found = (inboxes.value || []).find(
    inbox => Number(inbox.id) === Number(inboxId)
  );
  return found ? found.name : `#${inboxId}`;
};

const handleStoreSubmit = async () => {
  try {
    formError.value = '';

    if (editingHookId.value) {
      isSubmitting.value = true;
      await integrationAPI.updateShopifyHook({
        hookId: editingHookId.value,
        storeName: storeName.value.trim(),
        shopifyAdminKey: shopifyAdminKey.value.trim(),
        inboxIds: selectedInboxIds.value,
      });
      await store.dispatch('integrations/get', 'shopify');
      useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.UPDATED_SUCCESS'));
      dialogRef.value?.close();
      resetForm();
      return;
    }

    const cleanDomain = storeUrl.value
      .trim()
      .replace(/^https?:\/\//i, '')
      .replace(/\/.*$/, '');
    storeUrl.value = cleanDomain;

    if (!validateStoreUrl(cleanDomain)) {
      formError.value = t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.INVALID_URL');
      return;
    }

    isSubmitting.value = true;

    if (shopifyAdminKey.value.trim()) {
      await integrationAPI.connectShopifyToken({
        storeName: storeName.value.trim(),
        shopDomain: cleanDomain,
        shopifyAdminKey: shopifyAdminKey.value.trim(),
        inboxIds: selectedInboxIds.value,
      });
      await store.dispatch('integrations/get', 'shopify');
      useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONNECTED_SUCCESS'));
      dialogRef.value?.close();
      resetForm();
      return;
    }

    const { data } = await integrationAPI.connectShopify({
      shopDomain: cleanDomain,
    });

    if (data.redirect_url) {
      window.location.href = data.redirect_url;
    }
  } catch (err) {
    formError.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.SHOPIFY.ERROR');
  } finally {
    isSubmitting.value = false;
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
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <Integration
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
              :label="t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ADD_BUTTON')"
              @click="openCreateDialog"
            />
          </template>
        </Integration>

        <div
          v-if="hooks.length"
          class="flex flex-col gap-3 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow p-5"
        >
          <div class="flex items-center justify-between">
            <h3 class="text-base font-semibold text-n-slate-12">
              {{
                `${t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONNECTED_STORES')} (${hooks.length})`
              }}
            </h3>
          </div>

          <div class="divide-y divide-n-weak">
            <div
              v-for="hook in hooks"
              :key="hook.id"
              class="py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <div class="flex flex-col gap-1">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-n-slate-12">
                    {{ hook.settings?.store_name || hook.reference_id }}
                  </span>
                  <span
                    class="text-xs px-2 py-0.5 rounded bg-n-teal-3 text-n-teal-11 font-mono"
                  >
                    {{ hook.reference_id }}
                  </span>
                </div>
                <div class="flex flex-wrap items-center gap-1.5 mt-1">
                  <span class="text-xs text-n-slate-11">
                    {{
                      `${t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.LINKED_INBOXES')}:`
                    }}
                  </span>
                  <template v-if="hook.settings?.inbox_ids?.length">
                    <span
                      v-for="inboxId in hook.settings.inbox_ids"
                      :key="inboxId"
                      class="text-xs px-2 py-0.5 rounded bg-n-solid-3 text-n-slate-12"
                    >
                      {{ getInboxName(inboxId) }}
                    </span>
                  </template>
                  <span v-else class="text-xs text-n-slate-11 italic">
                    {{
                      t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ALL_INBOXES')
                    }}
                  </span>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <Button
                  faded
                  slate
                  xs
                  :label="t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.EDIT')"
                  @click="openEditDialog(hook)"
                />
                <Button
                  faded
                  ruby
                  xs
                  :label="t('INTEGRATION_SETTINGS.DELETE.BUTTON_TEXT')"
                  @click="handleDeleteHook(hook)"
                />
              </div>
            </div>
          </div>
        </div>

        <div
          v-if="error"
          class="flex items-center justify-center flex-1 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow p-6"
        >
          <p class="text-n-ruby-9">
            {{ t('INTEGRATION_SETTINGS.SHOPIFY.ERROR') }}
          </p>
        </div>

        <Dialog
          ref="dialogRef"
          :title="
            editingHookId
              ? t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.EDIT_TITLE')
              : t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.TITLE')
          "
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
              :disabled="!!editingHookId"
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
                editingHookId
                  ? t(
                      'INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.ACCESS_TOKEN_KEEP_PLACEHOLDER'
                    )
                  : t(
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
