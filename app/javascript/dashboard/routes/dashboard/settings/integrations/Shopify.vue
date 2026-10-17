<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import integrationAPI from 'dashboard/api/integrations';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const integrationLoaded = ref(false);

const editingHookId = ref(null);
const storeName = ref('');
const storeUrl = ref('');
const shopifyAdminKey = ref('');
const selectedInboxIds = ref([]);
const selectedAgentIds = ref([]);
const isSubmitting = ref(false);
const formError = ref('');

const testingHookId = ref(null);
const syncingHookId = ref(null);
const expandedProductsHookIds = ref([]);
const storesViewMode = ref('cards'); // 'cards' | 'list'
const catalogViewMode = ref('cards'); // 'cards' | 'list'

const integration = useFunctionGetter('integrations/getIntegration', 'shopify');
const uiFlags = useMapGetter('integrations/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

const hooks = computed(() => integration.value?.hooks || []);

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

const resetForm = () => {
  editingHookId.value = null;
  storeName.value = '';
  storeUrl.value = '';
  shopifyAdminKey.value = '';
  selectedInboxIds.value = [];
  selectedAgentIds.value = [];
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
  shopifyAdminKey.value = '';
  selectedInboxIds.value = Array.isArray(hook.settings?.inbox_ids)
    ? hook.settings.inbox_ids.map(Number)
    : [];
  selectedAgentIds.value = Array.isArray(hook.settings?.agent_ids)
    ? hook.settings.agent_ids.map(Number)
    : [];
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const handleDialogClose = () => {
  resetForm();
};

const toggleInbox = inboxId => {
  const id = Number(inboxId);
  if (selectedInboxIds.value.includes(id)) {
    selectedInboxIds.value = selectedInboxIds.value.filter(i => i !== id);
  } else {
    selectedInboxIds.value = [...selectedInboxIds.value, id];
  }
};

const toggleAgent = agentId => {
  const id = Number(agentId);
  if (selectedAgentIds.value.includes(id)) {
    selectedAgentIds.value = selectedAgentIds.value.filter(i => i !== id);
  } else {
    selectedAgentIds.value = [...selectedAgentIds.value, id];
  }
};

const selectAllAgents = () => {
  selectedAgentIds.value = (agents.value || []).map(a => Number(a.id));
};

const clearAllAgents = () => {
  selectedAgentIds.value = [];
};

const toggleProductsAccordion = hookId => {
  const id = Number(hookId);
  if (expandedProductsHookIds.value.includes(id)) {
    expandedProductsHookIds.value = expandedProductsHookIds.value.filter(
      i => i !== id
    );
  } else {
    expandedProductsHookIds.value = [...expandedProductsHookIds.value, id];
  }
};

const isProductsExpanded = hookId => {
  return expandedProductsHookIds.value.includes(Number(hookId));
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

    if (editingHookId.value) {
      await integrationAPI.updateShopifyHook({
        hookId: editingHookId.value,
        storeName:
          trimmedName || cleanDomain.replace(/\.myshopify\.(com|io)$/i, ''),
        shopDomain: cleanDomain,
        shopifyAdminKey: shopifyAdminKey.value.trim(),
        inboxIds: selectedInboxIds.value,
        agentIds: selectedAgentIds.value,
      });
      await store.dispatch('integrations/get', 'shopify');
      useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.UPDATED_SUCCESS'));
    } else {
      await integrationAPI.connectShopifyToken({
        storeName:
          trimmedName || cleanDomain.replace(/\.myshopify\.(com|io)$/i, ''),
        shopDomain: cleanDomain,
        shopifyAdminKey: shopifyAdminKey.value.trim(),
        inboxIds: selectedInboxIds.value,
        agentIds: selectedAgentIds.value,
      });
      await store.dispatch('integrations/get', 'shopify');
      useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.CONNECTED_SUCCESS'));
    }

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

const handleTestConnection = async hook => {
  try {
    testingHookId.value = hook.id;
    await integrationAPI.testShopifyConnection(hook.id);
    await store.dispatch('integrations/get', 'shopify');
    useAlert('Conexão com a loja testada e validada com sucesso!');
  } catch (err) {
    useAlert(
      err.response?.data?.error ||
        err.message ||
        'Falha ao testar conexão com a loja.'
    );
  } finally {
    testingHookId.value = null;
  }
};

const handleSyncProducts = async hook => {
  try {
    syncingHookId.value = hook.id;
    const { data } = await integrationAPI.syncShopifyProducts(hook.id);
    await store.dispatch('integrations/get', 'shopify');
    if (!expandedProductsHookIds.value.includes(Number(hook.id))) {
      expandedProductsHookIds.value = [
        ...expandedProductsHookIds.value,
        Number(hook.id),
      ];
    }
    const count = data?.products_count ?? (data?.products || []).length;
    useAlert(`${count} produtos sincronizados da loja com sucesso!`);
  } catch (err) {
    useAlert(
      err.response?.data?.error ||
        err.message ||
        'Falha ao sincronizar produtos da loja.'
    );
  } finally {
    syncingHookId.value = null;
  }
};

const handleRemoveStore = async hook => {
  try {
    await integrationAPI.deleteShopifyHook(hook.id);
    await store.dispatch('integrations/get', 'shopify');
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.MULTI_STORE.REMOVED_SUCCESS'));
  } catch (err) {
    useAlert(
      err.response?.data?.error ||
        err.message ||
        t('INTEGRATION_SETTINGS.SHOPIFY.ERROR')
    );
  }
};

const getInboxName = inboxId => {
  const found = (inboxes.value || []).find(
    i => Number(i.id) === Number(inboxId)
  );
  return found ? found.name : `#${inboxId}`;
};

const getAgentName = agentId => {
  const found = (agents.value || []).find(
    a => Number(a.id) === Number(agentId)
  );
  return found ? found.name || found.email : `Agente #${agentId}`;
};

const getStoreProducts = hook => {
  return Array.isArray(hook?.settings?.products) ? hook.settings.products : [];
};

const formatDateTime = isoStr => {
  if (!isoStr) return 'Nunca';
  try {
    return new Date(isoStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return isoStr;
  }
};

const initializeShopifyIntegration = async () => {
  await Promise.all([
    store.dispatch('integrations/get', 'shopify'),
    store.dispatch('inboxes/get'),
    store.dispatch('agents/get'),
  ]);
  if (hooks.value.length > 0) {
    expandedProductsHookIds.value = [Number(hooks.value[0].id)];
  }
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeShopifyIntegration();
});
</script>

<!-- eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template -->
<template>
  <SettingsLayout
    :is-loading="!integrationLoaded || uiFlags.isCreatingShopify"
    class="w-full max-w-none"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.SHOPIFY.HEADER')"
        description="Gerencie as lojas Shopify conectadas, teste conexões, sincronize o catálogo de produtos e defina quais agentes têm acesso aos pedidos de cada loja."
        feature-name="shopify"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template #actions>
          <div class="flex items-center gap-3">
            <!-- Toggle Visualização das Lojas: Cards vs Lista -->
            <div
              class="inline-flex items-center p-1 rounded-xl border border-n-weak bg-n-solid-2"
            >
              <button
                type="button"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition-colors"
                :class="
                  storesViewMode === 'cards'
                    ? 'bg-n-brand text-white shadow-sm'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                @click="storesViewMode = 'cards'"
              >
                <span class="i-lucide-layout-grid size-3.5" />
                <span>Cards</span>
              </button>
              <button
                type="button"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium transition-colors"
                :class="
                  storesViewMode === 'list'
                    ? 'bg-n-brand text-white shadow-sm'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                @click="storesViewMode = 'list'"
              >
                <span class="i-lucide-list size-3.5" />
                <span>Lista</span>
              </button>
            </div>

            <Button
              icon="i-lucide-plus"
              label="Adicionar Loja Shopify"
              @click="openCreateDialog"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-5">
        <!-- Empty state -->
        <div
          v-if="!hooks.length"
          class="flex flex-col items-center justify-center p-10 text-center rounded-2xl border border-dashed border-n-weak bg-n-solid-2"
        >
          <Avatar
            src="/dashboard/images/integrations/shopify.png"
            name="Shopify"
            :size="56"
            rounded-full
            class="mb-3"
          />
          <h4 class="text-base font-semibold text-n-slate-12 mb-1">
            Nenhuma loja Shopify cadastrada
          </h4>
          <p class="text-sm text-n-slate-11 max-w-lg mb-4">
            Cadastre suas lojas Shopify (com Admin API Token ou em Modo Mock de
            teste), sincronize os produtos e escolha quais agentes terão acesso.
          </p>
          <Button
            icon="i-lucide-plus"
            label="Adicionar Primeira Loja"
            @click="openCreateDialog"
          />
        </div>

        <!-- MODO LISTA: TABELA DE LOJAS CONFIGURADAS -->
        <div
          v-else-if="storesViewMode === 'list'"
          class="overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-sm"
        >
          <table class="w-full text-left border-collapse">
            <thead>
              <tr
                class="border-b border-n-weak bg-n-alpha-1 text-xs font-semibold uppercase tracking-wide text-n-slate-11"
              >
                <th class="py-3.5 px-4">Loja Shopify</th>
                <th class="py-3.5 px-4">Domínio (.myshopify.com)</th>
                <th class="py-3.5 px-4">Status / Modo</th>
                <th class="py-3.5 px-4">Agentes com Acesso</th>
                <th class="py-3.5 px-4">Caixas de Entrada</th>
                <th class="py-3.5 px-4">Produtos</th>
                <th class="py-3.5 px-4 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak text-sm">
              <template v-for="hook in hooks" :key="`list-${hook.id}`">
                <tr class="hover:bg-n-alpha-1 transition-colors">
                  <td class="py-3.5 px-4">
                    <div class="flex items-center gap-2.5">
                      <Avatar
                        src="/dashboard/images/integrations/shopify.png"
                        :name="hook.settings?.store_name || hook.reference_id"
                        :size="32"
                        rounded-full
                      />
                      <div class="flex flex-col">
                        <span class="font-semibold text-n-slate-12">
                          {{ hook.settings?.store_name || hook.reference_id }}
                        </span>
                        <span class="text-[11px] text-n-slate-10">
                          Testado:
                          {{ formatDateTime(hook.settings?.last_tested_at) }}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td class="py-3.5 px-4 font-mono text-xs text-n-slate-11">
                    {{ hook.reference_id }}
                  </td>
                  <td class="py-3.5 px-4">
                    <div class="flex items-center gap-1.5 flex-wrap">
                      <span
                        class="px-2 py-0.5 text-[11px] font-medium rounded-full"
                        :class="
                          hook.settings?.connection_status === 'failed'
                            ? 'bg-n-ruby-3 text-n-ruby-11'
                            : 'bg-n-teal-3 text-n-teal-11'
                        "
                      >
                        {{
                          hook.settings?.connection_status === 'failed'
                            ? 'Falha'
                            : 'Conectada'
                        }}
                      </span>
                      <span
                        class="px-2 py-0.5 text-[11px] font-medium rounded-full"
                        :class="
                          isMockStore(hook)
                            ? 'bg-n-amber-3 text-n-amber-11'
                            : 'bg-n-brand/15 text-n-brand'
                        "
                      >
                        {{ isMockStore(hook) ? 'Mock' : 'Live' }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3.5 px-4">
                    <div
                      v-if="hook.settings?.agent_ids?.length"
                      class="flex flex-wrap gap-1"
                    >
                      <span
                        v-for="agentId in hook.settings.agent_ids"
                        :key="agentId"
                        class="px-2 py-0.5 text-xs font-medium rounded bg-n-brand/10 text-n-brand"
                      >
                        {{ getAgentName(agentId) }}
                      </span>
                    </div>
                    <span v-else class="text-xs text-n-slate-11">
                      Todos os agentes
                    </span>
                  </td>
                  <td class="py-3.5 px-4">
                    <div
                      v-if="hook.settings?.inbox_ids?.length"
                      class="flex flex-wrap gap-1"
                    >
                      <span
                        v-for="inboxId in hook.settings.inbox_ids"
                        :key="inboxId"
                        class="px-2 py-0.5 text-xs rounded bg-n-alpha-2 text-n-slate-12"
                      >
                        {{ getInboxName(inboxId) }}
                      </span>
                    </div>
                    <span v-else class="text-xs text-n-slate-11">Todas</span>
                  </td>
                  <td class="py-3.5 px-4">
                    <button
                      type="button"
                      class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-n-alpha-2 text-xs font-medium text-n-slate-12 hover:bg-n-brand/10 hover:text-n-brand"
                      @click="toggleProductsAccordion(hook.id)"
                    >
                      <span class="i-lucide-package size-3.5" />
                      <span>{{ getStoreProducts(hook).length }} itens</span>
                      <span
                        class="size-3.5"
                        :class="
                          isProductsExpanded(hook.id)
                            ? 'i-lucide-chevron-up'
                            : 'i-lucide-chevron-down'
                        "
                      />
                    </button>
                  </td>
                  <td class="py-3.5 px-4 text-right">
                    <div class="inline-flex items-center gap-1.5">
                      <Button
                        size="xs"
                        variant="faded"
                        color="teal"
                        icon="i-lucide-plug-zap"
                        label="Testar"
                        :is-loading="testingHookId === hook.id"
                        @click="handleTestConnection(hook)"
                      />
                      <Button
                        size="xs"
                        variant="faded"
                        color="blue"
                        icon="i-lucide-package-check"
                        label="Puxar"
                        :is-loading="syncingHookId === hook.id"
                        @click="handleSyncProducts(hook)"
                      />
                      <Button
                        size="xs"
                        variant="faded"
                        color="slate"
                        icon="i-lucide-user-check"
                        label="Agentes"
                        @click="openEditDialog(hook)"
                      />
                      <Button
                        size="xs"
                        variant="ghost"
                        color="ruby"
                        icon="i-lucide-trash-2"
                        @click="handleRemoveStore(hook)"
                      />
                    </div>
                  </td>
                </tr>

                <!-- Linha de Catálogo Expandido da Loja -->
                <tr v-if="isProductsExpanded(hook.id)" class="bg-n-surface-1">
                  <td colspan="7" class="p-4 border-b border-n-weak">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                      <div
                        v-for="product in getStoreProducts(hook)"
                        :key="product.id"
                        class="flex items-center justify-between p-3 rounded-xl border border-n-weak bg-n-solid-2"
                      >
                        <div class="flex flex-col min-w-0">
                          <span
                            class="text-xs font-semibold text-n-slate-12 truncate"
                          >
                            {{ product.title }}
                          </span>
                          <span class="text-[11px] font-mono text-n-slate-10">
                            SKU: {{ product.sku }}
                          </span>
                        </div>
                        <span
                          class="text-xs font-bold text-n-slate-12 shrink-0"
                        >
                          R$ {{ product.price }}
                        </span>
                      </div>
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>

        <!-- MODO CARDS: Lista de Lojas Configuradas (Sem Dropdown Switcher) -->
        <div v-else class="flex flex-col gap-5">
          <div
            v-for="hook in hooks"
            :key="hook.id"
            class="flex flex-col rounded-2xl border border-n-weak bg-n-solid-2 overflow-hidden shadow-sm"
          >
            <!-- Cabeçalho do Card da Loja -->
            <div
              class="flex flex-col lg:flex-row lg:items-center justify-between gap-4 p-5 border-b border-n-weak bg-n-alpha-1"
            >
              <div class="flex items-start sm:items-center gap-3.5 min-w-0">
                <Avatar
                  src="/dashboard/images/integrations/shopify.png"
                  :name="hook.settings?.store_name || hook.reference_id"
                  :size="44"
                  rounded-full
                />
                <div class="flex flex-col min-w-0">
                  <div class="flex items-center gap-2 flex-wrap">
                    <h3
                      class="text-base font-semibold text-n-slate-12 truncate"
                    >
                      {{ hook.settings?.store_name || hook.reference_id }}
                    </h3>
                    <span
                      class="inline-flex items-center gap-1 px-2 py-0.5 text-[11px] font-medium rounded-full"
                      :class="
                        hook.settings?.connection_status === 'failed'
                          ? 'bg-n-ruby-3 text-n-ruby-11'
                          : 'bg-n-teal-3 text-n-teal-11'
                      "
                    >
                      <span
                        class="size-1.5 rounded-full"
                        :class="
                          hook.settings?.connection_status === 'failed'
                            ? 'bg-n-ruby-9'
                            : 'bg-n-teal-9'
                        "
                      />
                      {{
                        hook.settings?.connection_status === 'failed'
                          ? 'Falha na Conexão'
                          : 'Conectada'
                      }}
                    </span>
                    <span
                      class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium rounded-full"
                      :class="
                        isMockStore(hook)
                          ? 'bg-n-amber-3 text-n-amber-11'
                          : 'bg-n-brand/15 text-n-brand'
                      "
                    >
                      {{
                        isMockStore(hook)
                          ? 'Modo Mock / Simulação'
                          : 'API Real (shpat_)'
                      }}
                    </span>
                  </div>
                  <div
                    class="flex items-center gap-3 text-xs text-n-slate-11 mt-1 flex-wrap"
                  >
                    <span class="font-mono">{{ hook.reference_id }}</span>
                    <span v-if="hook.settings?.domain">
                      • Domínio: {{ hook.settings.domain }}
                    </span>
                    <span>
                      • Último teste:
                      {{ formatDateTime(hook.settings?.last_tested_at) }}
                    </span>
                    <span>
                      • Produtos sincronizados:
                      <strong class="text-n-slate-12">
                        {{ getStoreProducts(hook).length }}
                      </strong>
                    </span>
                  </div>
                </div>
              </div>

              <!-- Botões de Ação da Loja: Testar Conexão, Puxar Produtos, Editar/Agentes, Remover -->
              <div class="flex items-center gap-2 flex-wrap shrink-0">
                <Button
                  size="sm"
                  variant="faded"
                  color="teal"
                  icon="i-lucide-plug-zap"
                  :label="
                    testingHookId === hook.id ? 'Testando...' : 'Testar Conexão'
                  "
                  :is-loading="testingHookId === hook.id"
                  @click="handleTestConnection(hook)"
                />
                <Button
                  size="sm"
                  variant="faded"
                  color="blue"
                  icon="i-lucide-package-check"
                  :label="
                    syncingHookId === hook.id
                      ? 'Sincronizando...'
                      : 'Puxar Produtos'
                  "
                  :is-loading="syncingHookId === hook.id"
                  @click="handleSyncProducts(hook)"
                />
                <Button
                  size="sm"
                  variant="faded"
                  color="slate"
                  icon="i-lucide-user-check"
                  label="Editar & Agentes"
                  @click="openEditDialog(hook)"
                />
                <Button
                  size="sm"
                  variant="ghost"
                  color="ruby"
                  icon="i-lucide-trash-2"
                  @click="handleRemoveStore(hook)"
                />
              </div>
            </div>

            <!-- Corpo do Card: Permissões de Agentes e Caixas de Entrada -->
            <div
              class="grid grid-cols-1 md:grid-cols-2 gap-4 p-5 border-b border-n-weak"
            >
              <!-- Agentes com Acesso -->
              <div class="flex flex-col gap-2">
                <div class="flex items-center justify-between">
                  <span
                    class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                  >
                    <span class="i-lucide-users size-3.5 text-n-brand" />
                    Agentes com Acesso à Loja
                  </span>
                  <button
                    type="button"
                    class="text-xs text-n-brand hover:underline"
                    @click="openEditDialog(hook)"
                  >
                    Gerenciar agentes
                  </button>
                </div>
                <div
                  v-if="hook.settings?.agent_ids?.length"
                  class="flex flex-wrap gap-1.5"
                >
                  <span
                    v-for="agentId in hook.settings.agent_ids"
                    :key="agentId"
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-md bg-n-brand/10 text-n-brand border border-n-brand/20"
                  >
                    <span class="i-lucide-user-check size-3" />
                    {{ getAgentName(agentId) }}
                  </span>
                </div>
                <div v-else class="flex items-center gap-1.5">
                  <span
                    class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-md bg-n-alpha-2 text-n-slate-11"
                  >
                    <span class="i-lucide-globe size-3" />
                    Todos os agentes da conta possuem acesso
                  </span>
                </div>
              </div>

              <!-- Caixas de Entrada Vinculadas -->
              <div class="flex flex-col gap-2">
                <div class="flex items-center justify-between">
                  <span
                    class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
                  >
                    <span class="i-lucide-inbox size-3.5 text-n-slate-10" />
                    Caixas de Entrada Vinculadas
                  </span>
                  <button
                    type="button"
                    class="text-xs text-n-brand hover:underline"
                    @click="openEditDialog(hook)"
                  >
                    Alterar caixas
                  </button>
                </div>
                <div
                  v-if="hook.settings?.inbox_ids?.length"
                  class="flex flex-wrap gap-1.5"
                >
                  <span
                    v-for="inboxId in hook.settings.inbox_ids"
                    :key="inboxId"
                    class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-md bg-n-alpha-2 text-n-slate-12 border border-n-weak"
                  >
                    <span class="i-lucide-inbox size-3 text-n-slate-10" />
                    {{ getInboxName(inboxId) }}
                  </span>
                </div>
                <div v-else>
                  <span class="text-xs text-n-slate-10">
                    Disponível em todas as caixas de entrada
                  </span>
                </div>
              </div>
            </div>

            <!-- Seção de Produtos Sincronizados da Loja -->
            <div class="flex flex-col bg-n-surface-1">
              <button
                type="button"
                class="flex items-center justify-between px-5 py-3 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
                @click="toggleProductsAccordion(hook.id)"
              >
                <span class="flex items-center gap-2">
                  <span class="i-lucide-package size-4 text-n-brand" />
                  <span>
                    Catálogo de Produtos Sincronizados ({{
                      getStoreProducts(hook).length
                    }})
                  </span>
                  <span
                    v-if="hook.settings?.last_synced_at"
                    class="text-n-slate-10 font-normal"
                  >
                    • Atualizado em
                    {{ formatDateTime(hook.settings.last_synced_at) }}
                  </span>
                </span>
                <span
                  class="size-4 text-n-slate-10 transition-transform"
                  :class="
                    isProductsExpanded(hook.id)
                      ? 'i-lucide-chevron-up'
                      : 'i-lucide-chevron-down'
                  "
                />
              </button>

              <div
                v-if="isProductsExpanded(hook.id)"
                class="px-5 pb-4 pt-1 border-t border-n-weak"
              >
                <div
                  v-if="!getStoreProducts(hook).length"
                  class="flex items-center justify-between py-4 px-4 rounded-xl bg-n-solid-2 border border-n-weak"
                >
                  <span class="text-xs text-n-slate-11">
                    Nenhum produto sincronizado ainda nesta loja. Clique em
                    "Puxar Produtos" para importar o catálogo.
                  </span>
                  <Button
                    size="xs"
                    variant="faded"
                    icon="i-lucide-refresh-cw"
                    label="Puxar Produtos Agora"
                    :is-loading="syncingHookId === hook.id"
                    @click="handleSyncProducts(hook)"
                  />
                </div>

                <div v-else class="flex flex-col gap-3 mt-2">
                  <div class="flex items-center justify-between">
                    <span class="text-xs text-n-slate-11">
                      Visualização do catálogo sincronizado desta loja:
                    </span>
                    <div
                      class="inline-flex items-center p-0.5 rounded-lg border border-n-weak bg-n-surface-1"
                    >
                      <button
                        type="button"
                        class="flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium"
                        :class="
                          catalogViewMode === 'cards'
                            ? 'bg-n-brand text-white'
                            : 'text-n-slate-11'
                        "
                        @click="catalogViewMode = 'cards'"
                      >
                        <span class="i-lucide-layout-grid size-3" />
                        <span>Cards</span>
                      </button>
                      <button
                        type="button"
                        class="flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium"
                        :class="
                          catalogViewMode === 'list'
                            ? 'bg-n-brand text-white'
                            : 'text-n-slate-11'
                        "
                        @click="catalogViewMode = 'list'"
                      >
                        <span class="i-lucide-list size-3" />
                        <span>Lista</span>
                      </button>
                    </div>
                  </div>

                  <!-- Produtos em Cards -->
                  <div
                    v-if="catalogViewMode === 'cards'"
                    class="grid grid-cols-1 md:grid-cols-3 2xl:grid-cols-4 gap-3"
                  >
                    <div
                      v-for="product in getStoreProducts(hook)"
                      :key="product.id"
                      class="flex flex-col justify-between p-3.5 rounded-xl border border-n-weak bg-n-solid-2 hover:border-n-brand/40 transition-colors gap-2.5"
                    >
                      <div>
                        <div class="flex items-start justify-between gap-2">
                          <span
                            class="text-xs font-semibold text-n-slate-12 line-clamp-2"
                          >
                            {{ product.title }}
                          </span>
                          <span
                            class="px-1.5 py-0.5 text-[10px] font-medium rounded bg-n-teal-3 text-n-teal-11 shrink-0"
                          >
                            Ativo
                          </span>
                        </div>
                        <div
                          class="flex items-center gap-2 text-[11px] text-n-slate-10 mt-1"
                        >
                          <span v-if="product.sku" class="font-mono">
                            SKU: {{ product.sku }}
                          </span>
                          <span v-if="product.product_type">
                            • {{ product.product_type }}
                          </span>
                        </div>
                      </div>
                      <div
                        class="flex items-center justify-between pt-2 border-t border-n-weak text-xs"
                      >
                        <span class="font-bold text-n-slate-12">
                          R$ {{ product.price }}
                        </span>
                        <span class="text-[11px] text-n-slate-10">
                          Estoque: {{ product.inventory_quantity ?? 'Digital' }}
                        </span>
                      </div>
                    </div>
                  </div>

                  <!-- Produtos em Lista -->
                  <div
                    v-else
                    class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-2"
                  >
                    <table class="w-full text-left border-collapse text-xs">
                      <thead>
                        <tr
                          class="border-b border-n-weak bg-n-alpha-1 text-[11px] font-semibold uppercase text-n-slate-11"
                        >
                          <th class="py-2.5 px-3">Produto</th>
                          <th class="py-2.5 px-3">SKU</th>
                          <th class="py-2.5 px-3">Categoria</th>
                          <th class="py-2.5 px-3">Estoque</th>
                          <th class="py-2.5 px-3 text-right">Preço</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-n-weak">
                        <tr
                          v-for="product in getStoreProducts(hook)"
                          :key="`tbl-${product.id}`"
                        >
                          <td class="py-2.5 px-3 font-medium text-n-slate-12">
                            {{ product.title }}
                          </td>
                          <td class="py-2.5 px-3 font-mono text-n-slate-11">
                            {{ product.sku || '—' }}
                          </td>
                          <td class="py-2.5 px-3 text-n-slate-11">
                            {{ product.product_type || 'Digital' }}
                          </td>
                          <td class="py-2.5 px-3 text-n-slate-12">
                            {{ product.inventory_quantity ?? 'Digital' }} un.
                          </td>
                          <td
                            class="py-2.5 px-3 text-right font-bold text-n-slate-12"
                          >
                            R$ {{ product.price }}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Modal Adicionar / Editar Loja + Agentes com Acesso -->
      <Dialog
        ref="dialogRef"
        :title="
          editingHookId
            ? 'Editar Loja Shopify e Permissões de Agentes'
            : 'Adicionar Nova Loja Shopify'
        "
        :is-loading="isSubmitting"
        @confirm="handleStoreSubmit"
        @close="handleDialogClose"
      >
        <form class="flex flex-col gap-4" @submit.prevent="handleStoreSubmit">
          <Input
            v-model="storeName"
            label="Nome de identificação da Loja"
            placeholder="Ex: Games Safari, Barba Games, GameBox Brasil"
          />

          <Input
            v-model="storeUrl"
            label="Domínio .myshopify.com"
            placeholder="Ex: gamessafari.myshopify.com"
            :message="
              formError ||
              'Você pode informar o domínio .myshopify.com ou apenas o nome da loja'
            "
            :message-type="formError ? 'error' : 'info'"
          />

          <Input
            v-model="shopifyAdminKey"
            type="password"
            label="Admin API Access Token (shpat_...)"
            :placeholder="
              editingHookId
                ? 'Deixe em branco para manter o token/modo atual'
                : 'Opcional: deixe em branco para usar em Modo Mock de teste'
            "
            message="Se deixado em branco no cadastro, a loja funcionará em Modo Mock com catálogo e pedidos simulados."
            message-type="info"
          />

          <!-- Seleção de Agentes com Acesso -->
          <div class="flex flex-col gap-2">
            <div class="flex items-center justify-between">
              <label class="text-sm font-medium text-n-slate-12">
                Quais agentes terão acesso à integração desta loja?
              </label>
              <div class="flex items-center gap-2 text-xs">
                <button
                  type="button"
                  class="text-n-brand hover:underline"
                  @click="selectAllAgents"
                >
                  Marcar todos
                </button>
                <span class="text-n-slate-9">•</span>
                <button
                  type="button"
                  class="text-n-slate-11 hover:underline"
                  @click="clearAllAgents"
                >
                  Liberar para todos
                </button>
              </div>
            </div>
            <p class="text-xs text-n-slate-11">
              Selecione os agentes específicos que poderão ver e consultar esta
              loja na tela de Pedidos Shopify. (Se nenhum for marcado, todos os
              agentes terão acesso).
            </p>
            <div
              class="max-h-40 overflow-y-auto rounded-lg border border-n-weak p-2 flex flex-col gap-1 bg-n-alpha-1"
            >
              <label
                v-for="agent in agents"
                :key="agent.id"
                class="flex items-center justify-between gap-2 px-2 py-1.5 rounded hover:bg-n-alpha-2 cursor-pointer text-sm text-n-slate-12"
              >
                <div class="flex items-center gap-2 min-w-0">
                  <input
                    type="checkbox"
                    class="rounded border-n-weak text-n-brand focus:ring-n-brand"
                    :checked="selectedAgentIds.includes(Number(agent.id))"
                    @change="toggleAgent(agent.id)"
                  />
                  <span class="truncate font-medium">{{ agent.name }}</span>
                  <span class="text-xs text-n-slate-10 truncate">
                    ({{ agent.email }})
                  </span>
                </div>
                <span
                  class="text-[10px] uppercase px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-11 shrink-0"
                >
                  {{ agent.role }}
                </span>
              </label>
            </div>
          </div>

          <!-- Seleção de Caixas de Entrada -->
          <div v-if="inboxes && inboxes.length" class="flex flex-col gap-2">
            <label class="text-sm font-medium text-n-slate-12">
              Caixas de entrada vinculadas a esta loja
            </label>
            <div
              class="max-h-36 overflow-y-auto rounded-lg border border-n-weak p-2 flex flex-col gap-1 bg-n-alpha-1"
            >
              <label
                v-for="inbox in inboxes"
                :key="inbox.id"
                class="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-n-alpha-2 cursor-pointer text-sm text-n-slate-12"
              >
                <input
                  type="checkbox"
                  class="rounded border-n-weak text-n-brand focus:ring-n-brand"
                  :checked="selectedInboxIds.includes(Number(inbox.id))"
                  @change="toggleInbox(inbox.id)"
                />
                <span class="truncate">{{ inbox.name }}</span>
              </label>
            </div>
          </div>
        </form>
      </Dialog>
    </template>
  </SettingsLayout>
</template>
