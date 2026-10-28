<script>
import { mapGetters } from 'vuex';
import { IFrameHelper, RNHelper } from 'widget/helpers/utils';
import { popoutChatWindow } from '../helpers/popoutHelper';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import configMixin from 'widget/mixins/configMixin';
import { CONVERSATION_STATUS } from 'shared/constants/messages';

export default {
  name: 'HeaderActions',
  components: { FluentIcon },
  mixins: [configMixin],
  props: {
    showPopoutButton: {
      type: Boolean,
      default: false,
    },
    showEndConversationButton: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      showEndChatModal: false,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      canUserEndConversation: 'appConfig/getCanUserEndConversation',
      widgetColor: 'appConfig/getWidgetColor',
    }),
    canLeaveConversation() {
      return [
        CONVERSATION_STATUS.OPEN,
        CONVERSATION_STATUS.SNOOZED,
        CONVERSATION_STATUS.PENDING,
      ].includes(this.conversationStatus);
    },
    isIframe() {
      return IFrameHelper.isIFrame();
    },
    isRNWebView() {
      return RNHelper.isRNWebView();
    },
    showHeaderActions() {
      return this.isIframe || this.isRNWebView || this.hasWidgetOptions;
    },
    conversationStatus() {
      return this.conversationAttributes.status;
    },
    hasWidgetOptions() {
      return this.showPopoutButton || this.conversationStatus === 'open';
    },
    brandAccentColor() {
      return this.widgetColor || '#5cb82f';
    },
  },
  methods: {
    popoutWindow() {
      this.closeWindow();
      const {
        location: { origin },
        chatwootWebChannel: { websiteToken },
        authToken,
      } = window;
      popoutChatWindow(
        origin,
        websiteToken,
        this.$root.$i18n.locale,
        authToken
      );
    },
    closeWindow() {
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'closeWindow' });
      } else if (RNHelper.isRNWebView) {
        RNHelper.sendMessage({ type: 'close-widget' });
      }
    },
    toggleEndChatModal() {
      this.showEndChatModal = !this.showEndChatModal;
    },
    closeEndChatModal() {
      this.showEndChatModal = false;
    },
    confirmResolveConversation() {
      this.showEndChatModal = false;
      this.$store.dispatch('conversation/resolveConversation');
    },
    keepWaitingConversation() {
      this.showEndChatModal = false;
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="showHeaderActions"
    class="actions relative flex items-center gap-2"
  >
    <div
      v-if="
        canLeaveConversation &&
        canUserEndConversation &&
        hasEndConversationEnabled &&
        showEndConversationButton
      "
      class="relative flex items-center"
    >
      <button
        type="button"
        class="end-chat-pill-btn inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold transition-all duration-150 cursor-pointer select-none whitespace-nowrap bg-white dark:bg-n-solid-2 hover:bg-emerald-50/70"
        :title="$t('END_CHAT_MODAL.BUTTON_LABEL')"
        @click.stop="toggleEndChatModal"
      >
        <svg
          width="15"
          height="15"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.1"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="shrink-0"
        >
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
          <polyline points="16 17 21 12 16 7" />
          <line x1="21" y1="12" x2="9" y2="12" />
        </svg>
        <span>{{ $t('END_CHAT_MODAL.BUTTON_LABEL') }}</span>
      </button>

      <!-- Backdrop transparente para fechar ao clicar fora -->
      <div
        v-if="showEndChatModal"
        class="fixed inset-0 z-40"
        @click="closeEndChatModal"
      />

      <!-- Popover/Modal de confirmação com 2 opções (Fiel à Imagem 2) -->
      <div
        v-if="showEndChatModal"
        class="end-chat-popover absolute right-0 top-[calc(100%+10px)] z-50 w-[290px] sm:w-[305px] rounded-2xl bg-white dark:bg-n-solid-3 p-5 shadow-[0_12px_36px_rgba(15,23,42,0.16)] border border-slate-100 dark:border-n-weak text-center"
        @click.stop
      >
        <div
          class="end-chat-popover__arrow absolute -top-2 right-6 w-4 h-4 bg-white dark:bg-n-solid-3 rotate-45 border-l border-t border-slate-100 dark:border-n-weak"
        />
        <button
          type="button"
          class="absolute top-3.5 right-3.5 p-1 text-slate-400 hover:text-slate-600 dark:text-n-slate-10 dark:hover:text-n-slate-12 bg-transparent border-0 cursor-pointer"
          :aria-label="$t('COMPONENTS.FILE_BUBBLE.DOWNLOAD') ? ' × ' : ' × '"
          @click="closeEndChatModal"
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>

        <!-- Ícone balão verde no topo -->
        <div class="flex justify-center mb-2.5">
          <div
            class="w-11 h-11 rounded-full bg-emerald-50 dark:bg-emerald-950/40 flex items-center justify-center text-[#15803d]"
          >
            <svg
              width="26"
              height="26"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"
              />
              <circle cx="9" cy="12" r="1" fill="currentColor" />
              <circle cx="12" cy="12" r="1" fill="currentColor" />
              <circle cx="15" cy="12" r="1" fill="currentColor" />
            </svg>
          </div>
        </div>

        <h3
          class="text-[16px] font-bold text-slate-900 dark:text-n-slate-12 leading-snug m-0"
        >
          {{ $t('END_CHAT_MODAL.TITLE') }}
        </h3>
        <p
          class="text-[12.5px] text-slate-500 dark:text-n-slate-11 mt-1 mb-4 leading-normal"
        >
          {{ $t('END_CHAT_MODAL.SUBTITLE') }}
        </p>

        <div class="flex flex-col gap-2.5">
          <button
            type="button"
            class="w-full py-2.5 px-3.5 rounded-lg text-[13px] font-bold text-white leading-tight transition-opacity hover:opacity-95 cursor-pointer border-0 shadow-sm"
            :style="{ backgroundColor: brandAccentColor }"
            @click="confirmResolveConversation"
          >
            {{ $t('END_CHAT_MODAL.CONFIRM_RESOLVE') }}
          </button>

          <button
            type="button"
            class="w-full py-2.5 px-3.5 rounded-lg text-[13px] font-semibold bg-white dark:bg-n-solid-2 text-emerald-700 leading-tight transition-colors hover:bg-emerald-50/60 cursor-pointer border border-solid"
            :style="{
              borderColor: brandAccentColor,
            }"
            @click="keepWaitingConversation"
          >
            {{ $t('END_CHAT_MODAL.KEEP_WAITING') }}
          </button>
        </div>
      </div>
    </div>

    <button
      v-if="showPopoutButton"
      class="button transparent compact new-window--button"
      @click="popoutWindow"
    >
      <FluentIcon icon="open" size="22" class="text-n-slate-12" />
    </button>
    <button
      class="button transparent compact close-button"
      :class="{
        'rn-close-button': isRNWebView,
      }"
      @click="closeWindow"
    >
      <FluentIcon icon="dismiss" size="24" class="text-n-slate-12" />
    </button>
  </div>
</template>

<style scoped lang="scss">
.actions {
  .end-chat-pill-btn {
    border: 1.5px solid #22c55e;
    color: #15803d;
    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);

    &:hover {
      border-color: #16a34a;
      color: #166534;
    }
  }

  .close-button {
    display: none;
  }

  .rn-close-button {
    display: block !important;
  }
}
</style>
