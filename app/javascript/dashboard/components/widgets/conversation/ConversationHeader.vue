<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize, useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import MultiselectDropdownItems from 'shared/components/ui/MultiselectDropdownItems.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert, useAssignmentError } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
    conversation_through_awaiting_resolution: 'awaiting_resolution',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);
const isAwaitingResolution = computed(
  () =>
    currentChat.value.status === wootConstants.STATUS_TYPE.AWAITING_RESOLUTION
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const { agentsList } = useAgentsList(true, { includeAIAssignees: true });
const [showAssigneeDropdown, toggleAssigneeDropdown] = useToggle(false);
const closeAssigneeDropdown = () => toggleAssigneeDropdown(false);

const assignedAgent = computed(() => {
  const assignee = currentChat.value?.meta?.assignee;
  if (!assignee) return null;
  return {
    ...assignee,
    assignee_type: currentChat.value?.meta?.assignee_type || 'User',
  };
});

const assignedAgentThumbnail = computed(
  () => assignedAgent.value?.thumbnail || assignedAgent.value?.avatar_url || ''
);

const onSelectHeaderAssignee = async selectedItem => {
  closeAssigneeDropdown();
  const isUnassign =
    !selectedItem ||
    selectedItem.id === 0 ||
    (assignedAgent.value?.id === selectedItem.id &&
      (assignedAgent.value?.assignee_type || 'User') ===
        (selectedItem.assignee_type || 'User'));
  const nextAgent = isUnassign ? null : selectedItem;
  const assigneeType = nextAgent ? nextAgent.assignee_type || 'User' : null;
  try {
    await store.dispatch('assignAgent', {
      conversationId: currentChat.value.id,
      assignee: nextAgent,
      assigneeType,
    });
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAssignmentError(error, t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const { uiSettings, updateUISettings } = useUISettings();
const isContactSidebarOpen = computed(
  () => uiSettings.value?.is_contact_sidebar_open
);
const toggleContactSidebar = () => {
  updateUISettings({
    is_contact_sidebar_open: !isContactSidebarOpen.value,
    is_copilot_panel_open: false,
  });
};

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="relative z-30 overflow-visible flex flex-col gap-2.5 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-4 py-2.5 h-auto xl:h-[64px] bg-white dark:bg-[#060C14] msc-conversation-header"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="me-2"
      />
      <Avatar
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="38"
        :status="currentContact.availability_status"
        hide-offline-status
      />
      <div class="flex flex-col items-start min-w-0 ms-2.5 overflow-hidden">
        <div class="flex flex-row items-center max-w-full gap-1.5 p-0 m-0">
          <span
            class="text-[15px] font-bold tracking-tight truncate leading-tight text-slate-900 dark:text-slate-50"
          >
            {{ currentContact.name }}
          </span>
          <span
            v-if="isHMACVerified"
            class="i-lucide-badge-check size-4 text-emerald-500 flex-shrink-0"
            :title="$t('CONVERSATION.VERIFIED_SESSION')"
          />
          <fluent-icon
            v-else
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
          <span
            v-if="
              currentChat.can_reply && (!isContactSidebarOpen || width >= 720)
            "
            class="hidden sm:inline-flex items-center gap-1 ms-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 dark:bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-200/90 dark:border-emerald-500/30 flex-shrink-0 whitespace-nowrap"
          >
            <span
              class="i-lucide-clock size-3 text-emerald-600 dark:text-emerald-400 shrink-0"
            />
            <span>Janela 24h ativa</span>
          </span>
        </div>

        <div
          class="flex items-center gap-1.5 mt-0.5 overflow-hidden text-xs font-medium conversation--header--actions text-slate-600 dark:text-slate-400 text-ellipsis whitespace-nowrap"
        >
          <button
            type="button"
            class="truncate text-label-small text-slate-500 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 !p-0 cursor-pointer font-semibold"
            @click="copyConversationId"
          >
            {{ `#${chat.id}` }}
          </button>
          <span v-if="inbox?.name" class="text-slate-300 dark:text-slate-600">
            •
          </span>
          <InboxName v-if="inbox?.name" :inbox="inbox" class="!mx-0" />
          <span
            v-if="chat.meta?.team?.name"
            class="text-slate-300 dark:text-slate-600"
          >
            •
          </span>
          <span
            v-if="chat.meta?.team?.name"
            class="truncate text-slate-600 dark:text-slate-300"
          >
            {{ chat.meta.team.name }}
          </span>
          <span v-if="isSnoozed" class="text-slate-300 dark:text-slate-600">
            •
          </span>
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
          <span v-if="isAwaitingResolution">•</span>
          <span
            v-if="isAwaitingResolution"
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-semibold bg-amber-500/20 text-amber-600 dark:text-amber-400 border border-amber-500/40"
          >
            {{ t('CONVERSATION.HEADER.AWAITING_RESOLUTION_BADGE') }}
          </span>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <div
        v-on-click-outside="closeAssigneeDropdown"
        class="relative hidden sm:block"
      >
        <button
          type="button"
          class="h-8 px-2.5 rounded-lg border border-slate-200/95 dark:border-white/10 bg-white dark:bg-[#0B1522] hover:bg-slate-50 dark:hover:bg-[#112033] flex items-center gap-2 text-[13px] font-medium text-slate-700 dark:text-slate-200 shadow-2xs transition-colors"
          @click="toggleAssigneeDropdown()"
        >
          <Avatar
            v-if="assignedAgent"
            :name="assignedAgent.name"
            :src="assignedAgentThumbnail"
            :size="20"
            rounded-full
            hide-offline-status
          />
          <span
            v-else
            class="i-lucide-user-plus size-3.5 text-slate-400 dark:text-slate-500"
          />
          <span class="max-w-[110px] 2xl:max-w-[140px] truncate font-semibold">
            {{
              assignedAgent?.name || $t('CONVERSATION.ASSIGNMENT.SELECT_AGENT')
            }}
          </span>
          <span
            class="i-lucide-chevron-down size-3.5 text-slate-400 dark:text-slate-500"
          />
        </button>
        <div
          v-if="showAssigneeDropdown"
          class="absolute ltr:right-0 rtl:left-0 top-full mt-1.5 w-64 rounded-xl bg-white dark:bg-[#0B1522] border border-slate-200 dark:border-white/10 shadow-xl p-2 z-[9999]"
          @click.stop
        >
          <MultiselectDropdownItems
            :options="agentsList"
            :selected-items="assignedAgent ? [assignedAgent] : []"
            has-thumbnail
            :input-placeholder="
              $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
            "
            :no-search-result="
              $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
            "
            @select="onSelectHeaderAssignee"
          />
        </div>
      </div>
      <MoreActions :conversation-id="currentChat.id" />
      <button
        v-tooltip.bottom="$t('CONVERSATION.SIDEBAR.CONTACT')"
        type="button"
        class="h-8 w-8 rounded-lg border border-slate-200/95 dark:border-white/10 bg-white dark:bg-[#0B1522] hover:bg-slate-50 dark:hover:bg-[#112033] flex items-center justify-center text-slate-600 dark:text-slate-300 shadow-2xs transition-colors shrink-0"
        :class="{
          '!border-emerald-500/50 !bg-emerald-50/80 dark:!bg-emerald-500/15 !text-emerald-600 dark:!text-emerald-400':
            isContactSidebarOpen,
        }"
        @click="toggleContactSidebar"
      >
        <span class="i-lucide-panel-right size-4" />
      </button>
    </div>
  </div>
</template>
