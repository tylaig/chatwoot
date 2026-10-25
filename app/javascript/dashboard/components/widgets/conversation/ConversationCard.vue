<script setup>
import { computed, ref, watch } from 'vue';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from './conversationCardComponents/CardLabels.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';
import CardPinIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPinIcon.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  showAssignee: { type: Boolean, default: false },
  showInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
  typingPreview: { type: String, default: '' },
  hasGroupActivity: { type: Boolean, default: false },
  isPinned: { type: Boolean, default: false },
});

const emit = defineEmits([
  'click',
  'contextmenu',
  'selectConversation',
  'deSelectConversation',
]);

const hovered = ref(false);

const unreadCount = computed(() => props.chat.unread_count);
const hasUnread = computed(
  () => unreadCount.value > 0 || props.hasGroupActivity
);
const isAnyoneTyping = computed(() => !!props.typingPreview);
const lastMessageInChat = computed(() => getLastMessage(props.chat));

const voiceCallData = computed(() => ({
  status: props.chat.additional_attributes?.call_status,
  direction: props.chat.additional_attributes?.call_direction,
}));

const inboxColor = computed(() => props.inbox?.inbox_color || '');
const shouldShowInboxBadge = computed(
  () =>
    props.showInboxName ||
    Boolean(props.inbox?.inbox_color || props.inbox?.inbox_badge_label)
);

const showMetaSection = computed(() => {
  return (
    shouldShowInboxBadge.value ||
    (props.showAssignee && props.assignee.name) ||
    props.chat.priority
  );
});

const isAIAssignee = computed(() =>
  ['AgentBot', 'Captain::Assistant'].includes(props.chat?.meta?.assignee_type)
);

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !props.currentContact?.blocked
);

const showLabelsSection = computed(() => {
  return props.chat.labels?.length > 0 || hasSlaPolicyId.value;
});

const messagePreviewPaddingClass = computed(() => [
  !props.compact && hasUnread.value ? 'ltr:pr-4 rtl:pl-4' : '',
  props.compact && hasUnread.value ? 'ltr:pr-6 rtl:pl-6' : '',
]);

const messagePreviewClass = computed(() => [
  hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
  ...messagePreviewPaddingClass.value,
]);

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, props.inbox.id);
  } else {
    emit('deSelectConversation', props.chat.id);
  }
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => onSelectConversation(value),
});

watch(
  () => props.chat.id,
  () => {
    hovered.value = false;
  }
);
</script>

<template>
  <div
    class="relative flex items-start gap-3 flex-grow-0 flex-shrink-0 w-auto max-w-full cursor-pointer conversation msc-conv-card mx-2 my-1.5 rounded-xl border transition-all duration-150 group"
    :class="[
      isActiveChat
        ? 'active animate-card-select bg-emerald-50/80 dark:bg-emerald-500/12 border-emerald-200/90 dark:border-emerald-500/35 border-l-4 !border-l-emerald-500 dark:!border-l-emerald-400 shadow-xs'
        : selected
          ? 'selected bg-emerald-50/50 dark:bg-emerald-500/10 border-emerald-300 dark:border-emerald-500/40'
          : 'bg-white dark:bg-white/[0.015] border-slate-200/75 dark:border-white/[0.06] hover:bg-slate-50/90 dark:hover:bg-white/[0.035] hover:border-slate-300/80 dark:hover:border-emerald-500/25',
      compact ? 'px-2.5 py-2.5' : 'px-3.5 py-3',
    ]"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <span
      v-if="inboxColor && !isActiveChat"
      class="absolute inset-y-2 ltr:left-0 rtl:right-0 w-1 rounded-r-sm pointer-events-none z-10"
      :style="{ backgroundColor: inboxColor }"
    />
    <div
      class="relative shrink-0 mt-0.5"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="38"
        :status="currentContact.availability_status"
        hide-offline-status
      >
        <template #overlay="{ size }">
          <label
            v-if="hovered || selected"
            class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px]"
            :style="{ width: `${size}px`, height: `${size}px` }"
            @click.stop
          >
            <Checkbox v-model="selectedModel" />
          </label>
        </template>
      </Avatar>
    </div>
    <div class="p-0 flex-1 min-w-0 border-line">
      <div class="flex items-center justify-between gap-2 min-w-0">
        <h4
          class="conversation--user text-[15px] leading-snug my-0 capitalize text-ellipsis overflow-hidden whitespace-nowrap flex-1 min-w-0 text-slate-900 dark:text-slate-100"
          :class="hasUnread || isActiveChat ? 'font-bold' : 'font-semibold'"
        >
          {{ currentContact.name }}
        </h4>
        <div class="flex items-center gap-1.5 flex-shrink-0">
          <CardPriorityIcon
            :priority="chat.priority"
            class="flex-shrink-0 !size-3.5"
          />
          <CardPinIcon v-if="isPinned" class="flex-shrink-0" />
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
          />
        </div>
      </div>

      <div
        v-if="showMetaSection"
        class="flex items-center min-w-0 gap-1.5 mt-0.5 text-[12.5px] font-medium text-slate-600 dark:text-slate-400"
      >
        <InboxName
          v-if="shouldShowInboxBadge"
          :inbox="inbox"
          class="!mx-0 min-w-0 truncate"
        />
        <span
          v-if="shouldShowInboxBadge && showAssignee && assignee.name"
          class="text-slate-300 dark:text-slate-600 flex-shrink-0"
        >
          •
        </span>
        <span
          v-if="showAssignee && assignee.name"
          class="text-slate-600 dark:text-slate-400 text-xs font-medium leading-4 py-0 px-0 inline-flex items-center gap-1 truncate"
        >
          <Icon
            :icon="isAIAssignee ? 'i-lucide-bot' : 'i-lucide-user-round'"
            class="size-3 flex-shrink-0"
            :class="
              isAIAssignee
                ? 'text-emerald-600 dark:text-emerald-400'
                : 'text-slate-500 dark:text-slate-400'
            "
          />
          <span class="truncate">{{ assignee.name }}</span>
        </span>
      </div>

      <div class="flex items-center justify-between gap-2 mt-1 min-w-0">
        <VoiceCallStatus
          v-if="voiceCallData.status"
          key="voice-status-row"
          :status="voiceCallData.status"
          :direction="voiceCallData.direction"
          :message-preview-class="messagePreviewClass"
        />
        <p
          v-else-if="isAnyoneTyping"
          key="typing-preview"
          class="text-emerald-600 dark:text-emerald-400 text-[13.5px] font-medium my-0 !mx-0 leading-5 h-5 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
        >
          {{ typingPreview }}
        </p>
        <MessagePreview
          v-else-if="lastMessageInChat"
          key="message-preview"
          :message="lastMessageInChat"
          class="my-0 !mx-0 leading-5 h-5 flex-1 min-w-0 text-[13.5px]"
          :class="
            hasUnread
              ? 'font-semibold text-slate-900 dark:text-slate-100'
              : 'text-slate-600 dark:text-slate-400'
          "
        />
        <p
          v-else
          key="no-messages"
          class="text-slate-500 dark:text-slate-400 text-[13.5px] my-0 !mx-0 leading-5 h-5 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
        >
          <fluent-icon
            size="15"
            class="-mt-0.5 align-middle inline-block text-slate-400"
            icon="info"
          />
          <span class="mx-0.5">
            {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
          </span>
        </p>

        <UnreadBadge
          v-if="unreadCount > 0"
          :count="unreadCount"
          class="flex-shrink-0 !bg-emerald-500 !text-white font-bold"
        />
        <span
          v-else-if="hasGroupActivity"
          class="shadow-sm rounded-full flex-shrink-0 size-2 bg-emerald-500"
        />
      </div>

      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mt-2 !mx-0 mb-0"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
  </div>
</template>
