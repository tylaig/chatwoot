<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER } from 'dashboard/composables/useUISettings';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const MAIN_SIDEBAR_MODULES = [
  { key: 'InternalChat', label: 'Chat Interno (Equipe)' },
  { key: 'Kanban', label: 'Kanban de Atendimento' },
  { key: 'Captain', label: 'Captain AI (Assistentes, FAQs e Cenários)' },
  { key: 'Calls', label: 'Ligações / Chamadas de Voz' },
  { key: 'Contacts', label: 'Contatos & Segmentos' },
  { key: 'Companies', label: 'Empresas (B2B)' },
  { key: 'Reports', label: 'Relatórios & CSAT' },
  { key: 'CalendarSchedules', label: 'Agendamentos (Calendário)' },
  { key: 'ShopifyOrders', label: 'Pedidos & Lojas (Shopify)' },
  { key: 'Workflows', label: 'Workflows (Fluxos Visuais)' },
  { key: 'Templates', label: 'Templates de WhatsApp' },
  { key: 'Webhooks', label: 'Webhooks & Disparos' },
  { key: 'Campaigns', label: 'Campanhas (Live Chat, SMS, WhatsApp)' },
  { key: 'Portals', label: 'Central de Ajuda (Artigos & Portais)' },
];

const SIDEBAR_MODULES = [
  {
    key: 'conversation_info',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO',
  },
  {
    key: 'shopify_orders',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.SHOPIFY_ORDERS',
  },
  {
    key: 'calendar_appointments',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.CALENDAR_APPOINTMENTS',
  },
  {
    key: 'scheduled_messages',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.SCHEDULED_MESSAGES',
  },
  {
    key: 'conversation_actions',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS',
  },
  {
    key: 'macros',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.MACROS',
  },
  {
    key: 'conversation_participants',
    labelKey: 'CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE',
  },
  {
    key: 'contact_attributes',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES',
  },
  {
    key: 'contact_notes',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.CONTACT_NOTES',
  },
  {
    key: 'shared_files',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.SHARED_FILES',
  },
  {
    key: 'previous_conversation',
    labelKey: 'CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION',
  },
];

const allDefaultMainKeys = MAIN_SIDEBAR_MODULES.map(item => item.key);
const allDefaultKeys = DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER.map(
  item => item.name
);

const enabledMainItems = computed(() => {
  const configured =
    currentAccount.value?.settings?.main_sidebar_visible_items;
  if (!Array.isArray(configured)) return allDefaultMainKeys;
  return configured;
});

const enabledItems = computed(() => {
  const configured =
    currentAccount.value?.settings?.conversation_sidebar_visible_items;
  if (!Array.isArray(configured)) return allDefaultKeys;
  return configured;
});

const isMainItemEnabled = key => enabledMainItems.value.includes(key);
const isItemEnabled = key => enabledItems.value.includes(key);

const toggleMainModule = async (key, checked) => {
  const current = new Set(enabledMainItems.value);
  if (checked) {
    current.add(key);
  } else {
    current.delete(key);
  }
  try {
    await updateAccount({
      main_sidebar_visible_items: Array.from(current),
    });
    useAlert(t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.API.ERROR'));
  }
};

const toggleModule = async (key, checked) => {
  const current = new Set(enabledItems.value);
  if (checked) {
    current.add(key);
  } else {
    current.delete(key);
  }
  try {
    await updateAccount({
      conversation_sidebar_visible_items: Array.from(current),
    });
    useAlert(t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.API.ERROR'));
  }
};
</script>

<template>
  <SectionLayout
    title="Módulos do Menu Principal (Barra Lateral Esquerda)"
    description="Ative ou oculte os módulos exibidos no menu principal de navegação desta conta (ex: Agendamentos, Pedidos Shopify, Workflows, Kanban, Campanhas)."
    with-border
  >
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
      <div
        v-for="mod in MAIN_SIDEBAR_MODULES"
        :key="mod.key"
        class="flex items-center justify-between rounded-xl border border-n-weak bg-n-solid-1 px-3.5 py-2.5"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ mod.label }}
        </span>
        <Switch
          :model-value="isMainItemEnabled(mod.key)"
          @change="val => toggleMainModule(mod.key, val)"
        />
      </div>
    </div>
  </SectionLayout>

  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.SIDEBAR_MODULES.NOTE')"
    with-border
  >
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
      <div
        v-for="mod in SIDEBAR_MODULES"
        :key="mod.key"
        class="flex items-center justify-between rounded-xl border border-n-weak bg-n-solid-1 px-3.5 py-2.5"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t(mod.labelKey) }}
        </span>
        <Switch
          :model-value="isItemEnabled(mod.key)"
          @change="val => toggleModule(mod.key, val)"
        />
      </div>
    </div>
  </SectionLayout>
</template>
