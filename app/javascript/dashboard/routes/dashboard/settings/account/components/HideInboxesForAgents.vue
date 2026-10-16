<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const isEnabled = ref(false);

const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { hide_inboxes_for_agents: hideInboxesForAgents } =
      currentAccount.value?.settings || {};
    isEnabled.value = !!hideInboxesForAgents;
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    await updateAccount(settings);
    useAlert(t('GENERAL_SETTINGS.FORM.HIDE_INBOXES_FOR_AGENTS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.HIDE_INBOXES_FOR_AGENTS.API.ERROR'));
  }
};

const toggleHideInboxesForAgents = async () => {
  return updateAccountSettings({
    hide_inboxes_for_agents: isEnabled.value,
  });
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.HIDE_INBOXES_FOR_AGENTS.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.HIDE_INBOXES_FOR_AGENTS.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleHideInboxesForAgents" />
      </div>
    </template>
  </SectionLayout>
</template>
