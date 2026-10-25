<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';
import ReferralCard from './ReferralCard.vue';
import CaptainGenerationDetails from '../CaptainGenerationDetails.vue';
import Avatar from 'next/avatar/Avatar.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_VARIANTS, ORIENTATION, SENDER_TYPES } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const {
  variant,
  orientation,
  inReplyTo,
  shouldGroupWithNext,
  groupWithPrevious,
  id,
  sender,
  senderType,
  additionalAttributes,
  contentAttributes,
} = useMessageContext();
const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');

// Click-to-WhatsApp ad metadata attached to the first message after an ad click.
const referral = computed(() => contentAttributes.value?.referral);

// The contact deleted/revoked this message on WhatsApp. We keep the content
// readable but mute the bubble and add a dashed border to signal the deletion.
const deletedByContact = computed(
  () => contentAttributes.value?.deletedByContact === true
);

const isCaptainMessage = computed(
  () =>
    (sender.value?.type ?? senderType.value) === SENDER_TYPES.CAPTAIN_ASSISTANT
);

const rawSenderName = computed(
  () =>
    sender.value?.name ||
    additionalAttributes.value?.senderName ||
    contentAttributes.value?.externalSenderName ||
    ''
);

const isAISender = computed(() => {
  const sType = (sender.value?.type ?? senderType.value ?? '').toLowerCase();
  if (
    sType === SENDER_TYPES.AGENT_BOT ||
    sType === SENDER_TYPES.CAPTAIN_ASSISTANT ||
    variant.value === MESSAGE_VARIANTS.BOT
  ) {
    return true;
  }
  const name = rawSenderName.value.toLowerCase();
  return (
    /\b(ia|ai|bot|sofia|assistente|copiloto|captain)\b/i.test(name) ||
    name.includes('(agente')
  );
});

const shouldShowSenderHeader = computed(() => {
  if (props.hideMeta) return false;
  if (groupWithPrevious?.value) return false;
  if (orientation.value !== ORIENTATION.RIGHT) return false;
  return [
    MESSAGE_VARIANTS.AGENT,
    MESSAGE_VARIANTS.BOT,
    MESSAGE_VARIANTS.TEMPLATE,
    MESSAGE_VARIANTS.PRIVATE,
  ].includes(variant.value);
});

const cleanSenderName = computed(() => {
  const name = rawSenderName.value;
  if (!name) {
    return isAISender.value ? 'Sofia IA' : 'Atendente';
  }
  return name.replace(/\s*\([^)]*\)\s*/g, '').trim() || name;
});

const senderRoleBadge = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.PRIVATE) {
    return 'Nota Interna';
  }
  if (isAISender.value) {
    return 'Agente IA';
  }
  const teamName = currentChat.value?.meta?.team?.name;
  if (teamName) return teamName;
  return 'Comercial';
});

const senderAvatarSrc = computed(
  () => sender.value?.thumbnail || sender.value?.avatarUrl || ''
);

const metaColorClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.PRIVATE
    ? 'text-amber-800/75 dark:text-amber-200/75'
    : 'text-slate-500 dark:text-slate-400'
);

const emailMetaClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : ''
);

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]:
    'bg-emerald-50/95 dark:bg-emerald-950/55 border border-emerald-200/90 dark:border-emerald-500/30 text-slate-900 dark:text-slate-100 shadow-2xs msc-bubble-agent',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-amber-50/95 dark:bg-amber-950/45 border border-amber-200/90 dark:border-amber-500/30 text-amber-950 dark:text-amber-100 shadow-2xs [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]:
    'bg-white dark:bg-[#0D1826] border border-slate-200/95 dark:border-white/10 text-slate-900 dark:text-slate-100 shadow-2xs msc-bubble-user',
  [MESSAGE_VARIANTS.ACTIVITY]:
    'bg-slate-100/95 dark:bg-[#0B1522]/90 border border-slate-200/80 dark:border-white/10 text-slate-600 dark:text-slate-300 text-xs font-medium shadow-2xs msc-bubble-activity',
  [MESSAGE_VARIANTS.BOT]:
    'bg-emerald-50/90 dark:bg-emerald-950/45 border border-emerald-200/85 dark:border-emerald-500/30 text-slate-900 dark:text-slate-100 shadow-2xs msc-bubble-bot',
  [MESSAGE_VARIANTS.TEMPLATE]:
    'bg-emerald-50/90 dark:bg-emerald-950/45 border border-emerald-200/85 dark:border-emerald-500/30 text-slate-900 dark:text-slate-100 shadow-2xs msc-bubble-template',
  [MESSAGE_VARIANTS.ERROR]:
    'bg-rose-50 dark:bg-rose-950/50 border border-rose-200 dark:border-rose-500/30 text-rose-900 dark:text-rose-200',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-amber-50/80 dark:bg-amber-950/40 border border-dashed border-amber-400/70 text-amber-900 dark:text-amber-200',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-2xl ltr:rounded-bl-md rtl:rounded-br-md',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-2xl ltr:rounded-br-md rtl:rounded-bl-md',
  [ORIENTATION.CENTER]: 'rounded-full',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const isScheduledMessage = computed(
  () => !!additionalAttributes.value?.scheduledMessageId
);

const scheduledMessageClass = computed(() => {
  if (!isScheduledMessage.value) return '';
  if (variant.value === MESSAGE_VARIANTS.AGENT) return 'bg-n-solid-iris';
  return '';
});

const messageClass = computed(() => {
  const classToApply = [varaintBaseMap[variant.value]];

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-full');
  }

  if (scheduledMessageClass.value) {
    classToApply.push(scheduledMessageClass.value);
  }

  if (deletedByContact.value) {
    classToApply.push('border-2 border-dashed border-n-slate-7 opacity-75');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    class="text-sm min-w-0"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
      },
    ]"
  >
    <ReferralCard v-if="referral" :referral="referral" />
    <div
      v-if="shouldShowSenderHeader"
      class="flex items-center gap-2 mb-1.5 pb-1 border-b border-emerald-200/50 dark:border-emerald-500/20"
      :class="{
        'border-amber-300/50 dark:border-amber-500/25':
          variant === MESSAGE_VARIANTS.PRIVATE,
      }"
    >
      <div
        v-if="isAISender"
        class="size-5 rounded-full bg-emerald-500/15 dark:bg-emerald-500/25 border border-emerald-500/40 flex items-center justify-center shrink-0"
      >
        <span
          class="i-lucide-bot size-3 text-emerald-600 dark:text-emerald-300"
        />
      </div>
      <Avatar
        v-else
        :name="cleanSenderName"
        :src="senderAvatarSrc"
        :size="20"
        rounded-full
        hide-offline-status
      />
      <div class="flex items-center gap-1.5 min-w-0 flex-wrap leading-none">
        <span
          v-if="isAISender"
          class="i-ph-sparkle-fill size-3 text-amber-500 dark:text-amber-400 shrink-0"
        />
        <span
          class="text-[12.5px] font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate"
        >
          {{ cleanSenderName }}
        </span>
        <span class="text-slate-300 dark:text-slate-600 text-[11px]">•</span>
        <span
          class="text-[11px] font-semibold px-1.5 py-0.5 rounded-full"
          :class="
            isAISender
              ? 'bg-emerald-500/15 text-emerald-800 dark:text-emerald-300 border border-emerald-500/25'
              : variant === MESSAGE_VARIANTS.PRIVATE
                ? 'bg-amber-500/15 text-amber-800 dark:text-amber-300 border border-amber-500/25'
                : 'bg-white/80 dark:bg-white/10 text-emerald-700 dark:text-emerald-300 border border-emerald-200/80 dark:border-white/10'
          "
        >
          {{ senderRoleBadge }}
        </span>
      </div>
    </div>
    <div
      v-if="inReplyTo"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <template v-if="shouldShowMeta">
      <CaptainGenerationDetails
        v-if="isCaptainMessage"
        :message-id="id"
        class="mt-2"
      >
        <template #meta>
          <MessageMeta :class="[emailMetaClass, metaColorClass]" />
        </template>
      </CaptainGenerationDetails>
      <MessageMeta
        v-else
        :class="[flexOrientationClass, emailMetaClass, metaColorClass]"
        class="mt-2"
      />
    </template>
  </div>
</template>
