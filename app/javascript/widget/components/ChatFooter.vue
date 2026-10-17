<script>
import { mapActions, mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import CustomButton from 'shared/components/Button.vue';
import FooterReplyTo from 'widget/components/FooterReplyTo.vue';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { sendEmailTranscript } from 'widget/api/conversation';
import { useRouter } from 'vue-router';
import { IFrameHelper } from '../helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';
import { emitter } from 'shared/helpers/mitt';

const TRANSCRIPT_COOLDOWN_MS = 15000;

export default {
  components: {
    ChatInputWrap,
    CustomButton,
    FooterReplyTo,
  },
  setup() {
    const router = useRouter();
    return { router };
  },
  data() {
    return {
      inReplyTo: null,
      isSendingTranscript: false,
      transcriptCooldown: false,
      transcriptCooldownTimer: null,
      sentTimestamps: [],
      antiSpamLockedUntil: 0,
      antiSpamRemainingSeconds: 0,
      antiSpamTimer: null,
      lastKnownOutgoingCount: 0,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      widgetColor: 'appConfig/getWidgetColor',
      conversationSize: 'conversation/getConversationSize',
      conversationMessages: 'conversation/getConversation',
      currentUser: 'contacts/getCurrentUser',
      isWidgetStyleFlat: 'appConfig/isWidgetStyleFlat',
    }),
    antiSpamConfig() {
      const cfg = window.chatwootWebChannel?.antiSpamConfig || {};
      return {
        enabled: Boolean(cfg.enabled),
        maxMessages: Number(cfg.maxMessages) || 10,
        windowSeconds: Number(cfg.windowSeconds) || 60,
        cooldownSeconds: Number(cfg.cooldownSeconds) || 120,
        warningMessage:
          cfg.warningMessage ||
          '⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens para não atrasar seu atendimento.',
      };
    },
    isAntiSpamLocked() {
      return this.antiSpamConfig.enabled && this.antiSpamRemainingSeconds > 0;
    },
    formattedAntiSpamTimer() {
      const mins = Math.floor(this.antiSpamRemainingSeconds / 60);
      const secs = this.antiSpamRemainingSeconds % 60;
      return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    },
    antiSpamStorageKey() {
      const token = window.chatwootWebChannel?.websiteToken || 'default';
      return `cw_anti_spam_lock_${token}`;
    },
    outgoingMessagesCount() {
      return Object.values(this.conversationMessages || {}).filter(
        m => m.message_type === 1 || m.message_type === 'outgoing'
      ).length;
    },
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    hideReplyBox() {
      const { allowMessagesAfterResolved } = window.chatwootWebChannel;
      const { status } = this.conversationAttributes;
      return !allowMessagesAfterResolved && status === 'resolved';
    },
    showEmailTranscriptButton() {
      return this.hasEmail;
    },
    hasEmail() {
      return this.currentUser && this.currentUser.has_email;
    },
    hasReplyTo() {
      return (
        this.inReplyTo && (this.inReplyTo.content || this.inReplyTo.attachments)
      );
    },
  },
  watch: {
    outgoingMessagesCount(newCount, oldCount) {
      if (newCount > oldCount && this.antiSpamRemainingSeconds > 0) {
        this.clearAntiSpamLock();
      }
    },
  },
  mounted() {
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.toggleReplyTo);
    this.restoreAntiSpamLock();
  },
  beforeUnmount() {
    clearTimeout(this.transcriptCooldownTimer);
    clearInterval(this.antiSpamTimer);
  },
  methods: {
    ...mapActions('conversation', ['sendMessage', 'sendAttachment']),
    ...mapActions('conversationAttributes', ['getAttributes']),
    restoreAntiSpamLock() {
      if (!this.antiSpamConfig.enabled) return;
      try {
        const saved = Number(
          window.localStorage.getItem(this.antiSpamStorageKey) || 0
        );
        if (saved > Date.now()) {
          this.activateAntiSpamLock(Math.ceil((saved - Date.now()) / 1000));
        }
      } catch {
        // Ignore storage errors
      }
    },
    activateAntiSpamLock(durationSeconds) {
      const secs =
        Number(durationSeconds) || this.antiSpamConfig.cooldownSeconds;
      this.antiSpamLockedUntil = Date.now() + secs * 1000;
      this.antiSpamRemainingSeconds = secs;
      try {
        window.localStorage.setItem(
          this.antiSpamStorageKey,
          String(this.antiSpamLockedUntil)
        );
      } catch {
        // Ignore storage errors
      }
      clearInterval(this.antiSpamTimer);
      this.antiSpamTimer = setInterval(() => {
        const diff = Math.ceil((this.antiSpamLockedUntil - Date.now()) / 1000);
        if (diff <= 0) {
          this.clearAntiSpamLock();
        } else {
          this.antiSpamRemainingSeconds = diff;
        }
      }, 1000);
    },
    clearAntiSpamLock() {
      this.antiSpamLockedUntil = 0;
      this.antiSpamRemainingSeconds = 0;
      this.sentTimestamps = [];
      clearInterval(this.antiSpamTimer);
      try {
        window.localStorage.removeItem(this.antiSpamStorageKey);
      } catch {
        // Ignore storage errors
      }
    },
    checkAndRecordAntiSpam() {
      if (!this.antiSpamConfig.enabled) return true;
      if (this.isAntiSpamLocked) return false;

      const now = Date.now();
      const windowMs = this.antiSpamConfig.windowSeconds * 1000;
      this.sentTimestamps = this.sentTimestamps.filter(
        ts => now - ts < windowMs
      );

      if (this.sentTimestamps.length >= this.antiSpamConfig.maxMessages) {
        this.activateAntiSpamLock(this.antiSpamConfig.cooldownSeconds);
        emitter.emit(BUS_EVENTS.SHOW_ALERT, {
          message: this.antiSpamConfig.warningMessage,
        });
        return false;
      }

      this.sentTimestamps.push(now);
      if (this.sentTimestamps.length >= this.antiSpamConfig.maxMessages) {
        this.activateAntiSpamLock(this.antiSpamConfig.cooldownSeconds);
      }
      return true;
    },
    async handleSendMessage(content) {
      if (!this.checkAndRecordAntiSpam()) {
        return;
      }
      await this.sendMessage({
        content,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      // reset replyTo message after sending
      this.inReplyTo = null;
      // Update conversation attributes on new conversation
      if (this.conversationSize === 0) {
        this.getAttributes();
      }
    },
    async handleSendAttachment(attachment) {
      if (!this.checkAndRecordAntiSpam()) {
        return;
      }
      await this.sendAttachment({
        attachment,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      this.inReplyTo = null;
    },
    startNewConversation() {
      this.router.replace({ name: 'prechat-form' });
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
        data: { hasConversation: true },
      });
    },
    toggleReplyTo(message) {
      this.inReplyTo = message;
    },
    startTranscriptCooldown() {
      this.transcriptCooldown = true;
      clearTimeout(this.transcriptCooldownTimer);
      this.transcriptCooldownTimer = setTimeout(() => {
        this.transcriptCooldown = false;
      }, TRANSCRIPT_COOLDOWN_MS);
    },
    async sendTranscript() {
      if (
        !this.hasEmail ||
        this.isSendingTranscript ||
        this.transcriptCooldown
      ) {
        return;
      }
      this.isSendingTranscript = true;
      try {
        await sendEmailTranscript();
        this.startTranscriptCooldown();
        emitter.emit(BUS_EVENTS.SHOW_ALERT, {
          message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'),
          type: 'success',
        });
      } catch (error) {
        emitter.emit(BUS_EVENTS.SHOW_ALERT, {
          message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'),
        });
      } finally {
        this.isSendingTranscript = false;
      }
    },
  },
};
</script>

<template>
  <footer
    v-if="!hideReplyBox"
    class="relative z-50 mb-1"
    :class="{
      'rounded-lg': !isWidgetStyleFlat,
      'pt-2.5 shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.05)] dark:shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.15)] rounded-t-none':
        hasReplyTo,
    }"
  >
    <FooterReplyTo
      v-if="hasReplyTo"
      :in-reply-to="inReplyTo"
      @dismiss="inReplyTo = null"
    />
    <div
      v-if="isAntiSpamLocked"
      class="flex flex-col gap-1.5 rounded-[7px] border border-amber-500/40 bg-amber-500/10 px-3.5 py-2.5 text-xs text-n-slate-12 shadow-sm"
    >
      <div class="flex items-center justify-between gap-2 font-semibold text-amber-600 dark:text-amber-400">
        <span>Chat temporariamente pausado (Anti-Spam)</span>
        <span class="rounded bg-amber-500/20 px-2 py-0.5 font-mono text-xs font-bold">
          {{ formattedAntiSpamTimer }}
        </span>
      </div>
      <p class="leading-relaxed text-n-slate-11">
        {{ antiSpamConfig.warningMessage }}
      </p>
    </div>
    <ChatInputWrap
      v-else
      class="shadow-sm"
      :on-send-message="handleSendMessage"
      :on-send-attachment="handleSendAttachment"
    />
  </footer>
  <div v-else>
    <CustomButton
      class="font-medium"
      block
      :bg-color="widgetColor"
      :text-color="textColor"
      @click="startNewConversation"
    >
      {{ $t('START_NEW_CONVERSATION') }}
    </CustomButton>
    <CustomButton
      v-if="showEmailTranscriptButton"
      type="clear"
      class="font-normal"
      :disabled="isSendingTranscript || transcriptCooldown"
      @click="sendTranscript"
    >
      {{ $t('EMAIL_TRANSCRIPT.BUTTON_TEXT') }}
    </CustomButton>
  </div>
</template>
