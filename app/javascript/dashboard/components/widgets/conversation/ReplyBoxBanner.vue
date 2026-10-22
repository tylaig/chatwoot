<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert, useAssignmentError } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';

import Banner from 'dashboard/components/ui/Banner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const currentInbox = computed(() => {
  const inboxId = currentChat.value?.inbox_id;
  if (!inboxId) return null;
  return store.getters['inboxes/getInbox'](inboxId);
});

const whatsappServiceQuota = computed(() => {
  if (
    currentInbox.value?.channel_type !== 'Channel::Whatsapp' ||
    currentInbox.value?.provider !== 'whatsapp_cloud'
  ) {
    return null;
  }
  return currentInbox.value?.monthly_service_quota || null;
});

const showQuotaBlockedBanner = computed(() => {
  if (props.isOnPrivateNote) return false;
  return Boolean(whatsappServiceQuota.value?.blocked);
});

const showQuotaWarningBanner = computed(() => {
  if (props.isOnPrivateNote || showQuotaBlockedBanner.value) return false;
  const q = whatsappServiceQuota.value;
  if (!q || !q.enabled) return false;
  if (q.allow_exceed && q.used >= q.safe_cap) return true;
  return q.used >= Math.floor(q.safe_cap * 0.85);
});

const toggleAllowExceedQuota = async allowExceed => {
  if (!currentInbox.value?.id) return;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: currentInbox.value.id,
      formData: false,
      channel: {
        provider_config: {
          ...(currentInbox.value.provider_config || {}),
          allow_exceed_service_limit: allowExceed,
        },
      },
    });
    useAlert(
      allowExceed
        ? 'Uso além do limite mensal liberado nesta caixa de entrada.'
        : 'Trava de segurança da franquia mensal reativada nesta caixa de entrada.'
    );
  } catch (error) {
    useAlert('Não foi possível atualizar a configuração de limite desta caixa.');
  }
};

const assignedAgent = computed(() => currentChat.value?.meta?.assignee);

const assignAgent = agent =>
  store.dispatch('assignAgent', {
    conversationId: currentChat.value?.id,
    assignee: agent,
  });

const hasMessage = computed(() => props.message !== '');
const isUserTyping = computed(() => hasMessage.value && !props.isOnPrivateNote);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => assignedAgent.value?.id !== currentUser.value?.id
);

const showSelfAssignBanner = computed(() => {
  return (
    isUserTyping.value && (isUnassigned.value || isAssignedToOtherAgent.value)
  );
});

const isPendingConversation = computed(
  () => currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

const showBotHandoffBanner = computed(() => {
  return isPendingConversation.value && isAgentBotOwned.value;
});

const botAssigneeName = computed(() => {
  if (isAgentBotOwned.value && assignedAgent.value?.name) {
    return assignedAgent.value.name;
  }

  return t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE');
});

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  await assignAgent({ ...rest, thumbnail: avatar_url });
};

const needsAssignmentToCurrentUser = computed(() => {
  return isUnassigned.value || isAssignedToOtherAgent.value;
});

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAssignmentError(error, t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: 'open',
  });
};

const onClickBotHandoff = async () => {
  try {
    const shouldAssignToCurrentUser =
      isAgentBotOwned.value || needsAssignmentToCurrentUser.value;

    await reopenConversation();

    if (shouldAssignToCurrentUser) {
      await selfAssignConversation();
    }

    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAssignmentError(error, t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};
</script>

<template>
  <Banner
    v-if="showQuotaBlockedBanner"
    action-button-variant="solid"
    color-scheme="alert"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="`Trava da API Oficial atingida (${whatsappServiceQuota.used}/${whatsappServiceQuota.safe_cap} respostas no mês — franquia gratuita: ${whatsappServiceQuota.limit}). Envios pausados para evitar cobrança da Meta.`"
    has-action-button
    action-button-label="Usar além do limite"
    @primary-action="toggleAllowExceedQuota(true)"
  />
  <Banner
    v-else-if="showQuotaWarningBanner"
    action-button-variant="ghost"
    color-scheme="warning"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      whatsappServiceQuota.allow_exceed
        ? `Franquia mensal liberada acima da trava (${whatsappServiceQuota.used}/${whatsappServiceQuota.limit} respostas enviadas no mês).`
        : `Atenção: franquia mensal da API Oficial em ${whatsappServiceQuota.used}/${whatsappServiceQuota.limit} respostas (trava automática em ${whatsappServiceQuota.safe_cap}).`
    "
    has-action-button
    :action-button-label="
      whatsappServiceQuota.allow_exceed
        ? 'Reativar trava'
        : 'Liberar além do limite'
    "
    @primary-action="toggleAllowExceedQuota(!whatsappServiceQuota.allow_exceed)"
  />
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      $t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
        assigneeName: botAssigneeName,
      })
    "
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="onClickBotHandoff"
  />
</template>
