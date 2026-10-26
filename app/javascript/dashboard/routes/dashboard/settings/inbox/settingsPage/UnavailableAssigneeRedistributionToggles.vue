<script setup>
import { ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const resolveFlag = (inbox, key) => {
  if (typeof inbox[key] === 'boolean') return inbox[key];
  if (typeof inbox.auto_assignment_config?.[key] === 'boolean') {
    return inbox.auto_assignment_config[key];
  }
  return !!inbox.enable_auto_assignment;
};

const unassignOnReopenOffline = ref(
  resolveFlag(props.inbox, 'unassign_on_reopen_when_offline')
);
const unassignOnReopenBusy = ref(
  resolveFlag(props.inbox, 'unassign_on_reopen_when_busy')
);
const redistributeOpenOffline = ref(
  resolveFlag(props.inbox, 'redistribute_open_on_reply_when_offline')
);
const redistributeOpenBusy = ref(
  resolveFlag(props.inbox, 'redistribute_open_on_reply_when_busy')
);

const syncFromInbox = () => {
  unassignOnReopenOffline.value = resolveFlag(
    props.inbox,
    'unassign_on_reopen_when_offline'
  );
  unassignOnReopenBusy.value = resolveFlag(
    props.inbox,
    'unassign_on_reopen_when_busy'
  );
  redistributeOpenOffline.value = resolveFlag(
    props.inbox,
    'redistribute_open_on_reply_when_offline'
  );
  redistributeOpenBusy.value = resolveFlag(
    props.inbox,
    'redistribute_open_on_reply_when_busy'
  );
};

watch(
  () => [
    props.inbox.id,
    props.inbox.enable_auto_assignment,
    props.inbox.unassign_on_reopen_when_offline,
    props.inbox.unassign_on_reopen_when_busy,
    props.inbox.redistribute_open_on_reply_when_offline,
    props.inbox.redistribute_open_on_reply_when_busy,
  ],
  syncFromInbox
);

const updateSetting = async (field, value) => {
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      [field]: value,
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    syncFromInbox();
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <SettingsToggleSection
      v-model="unassignOnReopenOffline"
      compact
      :header="$t('INBOX_MGMT.ASSIGNMENT.REOPEN_OFFLINE.TITLE')"
      :description="$t('INBOX_MGMT.ASSIGNMENT.REOPEN_OFFLINE.DESCRIPTION')"
      @update:model-value="
        val => updateSetting('unassign_on_reopen_when_offline', val)
      "
    />

    <SettingsToggleSection
      v-model="unassignOnReopenBusy"
      compact
      :header="$t('INBOX_MGMT.ASSIGNMENT.REOPEN_BUSY.TITLE')"
      :description="$t('INBOX_MGMT.ASSIGNMENT.REOPEN_BUSY.DESCRIPTION')"
      @update:model-value="
        val => updateSetting('unassign_on_reopen_when_busy', val)
      "
    />

    <SettingsToggleSection
      v-model="redistributeOpenOffline"
      compact
      :header="$t('INBOX_MGMT.ASSIGNMENT.REPLY_OPEN_OFFLINE.TITLE')"
      :description="$t('INBOX_MGMT.ASSIGNMENT.REPLY_OPEN_OFFLINE.DESCRIPTION')"
      @update:model-value="
        val => updateSetting('redistribute_open_on_reply_when_offline', val)
      "
    />

    <SettingsToggleSection
      v-model="redistributeOpenBusy"
      compact
      :header="$t('INBOX_MGMT.ASSIGNMENT.REPLY_OPEN_BUSY.TITLE')"
      :description="$t('INBOX_MGMT.ASSIGNMENT.REPLY_OPEN_BUSY.DESCRIPTION')"
      @update:model-value="
        val => updateSetting('redistribute_open_on_reply_when_busy', val)
      "
    />
  </div>
</template>
