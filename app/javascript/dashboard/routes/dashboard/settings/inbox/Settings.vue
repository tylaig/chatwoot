<script>
import { mapGetters } from 'vuex';
import { shouldBeUrl } from 'shared/helpers/Validators';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import Avatar from 'next/avatar/Avatar.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SettingIntroBanner from 'dashboard/components/widgets/SettingIntroBanner.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import inboxMixin from 'shared/mixins/inboxMixin';
import FacebookReauthorize from './facebook/Reauthorize.vue';
import InstagramReauthorize from './channels/instagram/Reauthorize.vue';
import TiktokReauthorize from './channels/tiktok/Reauthorize.vue';
import DuplicateInboxBanner from './channels/instagram/DuplicateInboxBanner.vue';
import MicrosoftReauthorize from './channels/microsoft/Reauthorize.vue';
import GoogleReauthorize from './channels/google/Reauthorize.vue';
import WhatsappReauthorize from './channels/whatsapp/Reauthorize.vue';
import InboxHealthAPI from 'dashboard/api/inboxHealth';
import PreChatFormSettings from './PreChatForm/Settings.vue';
import WeeklyAvailability from './components/WeeklyAvailability.vue';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import ConfigurationPage from './settingsPage/ConfigurationPage.vue';
import VoiceConfigurationPage from './settingsPage/VoiceConfigurationPage.vue';
import WhatsappCallingPage from './settingsPage/WhatsappCallingPage.vue';
import CustomerSatisfactionPage from './settingsPage/CustomerSatisfactionPage.vue';
import CollaboratorsPage from './settingsPage/CollaboratorsPage.vue';
import BotConfiguration from './components/BotConfiguration.vue';
import WhatsappServiceQuotaCard from './components/WhatsappServiceQuotaCard.vue';
import AccountHealth from './components/AccountHealth.vue';
import TwilioHealth from './components/TwilioHealth.vue';
import WhatsappManualMigrationDialog from './components/WhatsappManualMigrationDialog.vue';
import WhatsappManualMigrationBanner from './components/WhatsappManualMigrationBanner.vue';
import WhatsappLegacyProviderBanner from './components/WhatsappLegacyProviderBanner.vue';
import WhatsappLinkDeviceModal from './components/WhatsappLinkDeviceModal.vue';
import { isProviderOffline } from 'dashboard/helper/whatsapp';
import { consumePairingRequest } from 'dashboard/helper/whatsappPairingRequest';
import { useWhatsappSessionProviders } from 'dashboard/composables/useWhatsappSessionProviders';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import SenderNameExamplePreview from './components/SenderNameExamplePreview.vue';
import LockToSingleConversationPreview from './components/LockToSingleConversationPreview.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SpinnerLoader from 'dashboard/components-next/spinner/Spinner.vue';
import ConvertInboxModal from 'dashboard/components/widgets/modal/ConvertInboxModal.vue';
import {
  getInboxIconByType,
  getInboxIdentifier,
  INBOX_TYPES,
} from 'dashboard/helper/inbox';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import Widget from 'dashboard/modules/widget-preview/components/Widget.vue';
import AccessToken from 'dashboard/routes/dashboard/settings/profile/AccessToken.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { META_RESTRICTION_STATUS_URL } from 'dashboard/constants/globals';
import { CAPABILITIES } from 'dashboard/helper/whatsappSession';

export default {
  components: {
    Banner,
    BotConfiguration,
    WhatsappServiceQuotaCard,
    CollaboratorsPage,
    ConfigurationPage,
    VoiceConfigurationPage,
    WhatsappCallingPage,
    CustomerSatisfactionPage,
    FacebookReauthorize,
    GreetingsEditor,
    PreChatFormSettings,
    SettingIntroBanner,
    SettingsToggleSection,
    SettingsFieldSection,
    SettingsAccordion,
    WeeklyAvailability,
    SenderNameExamplePreview,
    LockToSingleConversationPreview,
    MicrosoftReauthorize,
    GoogleReauthorize,
    NextButton,
    SpinnerLoader,
    ConvertInboxModal,
    InstagramReauthorize,
    TiktokReauthorize,
    WhatsappReauthorize,
    DuplicateInboxBanner,
    Editor,
    Avatar,
    ColorPicker,
    SelectInput,
    AccountHealth,
    TwilioHealth,
    WhatsappManualMigrationDialog,
    WhatsappManualMigrationBanner,
    WhatsappLegacyProviderBanner,
    WhatsappLinkDeviceModal,
    Widget,
    AccessToken,
    Icon,
  },
  mixins: [inboxMixin],
  setup() {
    const { descriptorFor, creatableProviders, fetchProviders } =
      useWhatsappSessionProviders();
    return {
      v$: useVuelidate(),
      descriptorFor,
      creatableProviders,
      fetchWhatsappSessionProviders: fetchProviders,
    };
  },
  data() {
    return {
      avatarFile: null,
      avatarUrl: '',
      inboxColor: '',
      inboxBadgeLabel: '',
      chatBackgroundOpacity: 22,
      chatBackgroundFile: null,
      chatBackgroundUrl: '',
      removeChatBackgroundImage: false,
      antiSpamEnabled: false,
      antiSpamMaxMessages: 10,
      antiSpamWindowSeconds: 60,
      antiSpamCooldownSeconds: 120,
      antiSpamWarningMessage:
        '⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens para não atrasar seu atendimento.',
      inboxColorPresets: [
        '#EAB308',
        '#22C55E',
        '#3B82F6',
        '#A855F7',
        '#F97316',
        '#EF4444',
        '#06B6D4',
        '#EC4899',
      ],
      greetingEnabled: true,
      greetingMessage: '',
      emailCollectEnabled: false,
      senderNameType: 'friendly',
      businessName: '',
      locktoSingleConversation: false,
      legacyInbox: false,
      allowMessagesAfterResolved: true,
      continuityViaEmail: true,
      selectedInboxName: '',
      channelWebsiteUrl: '',
      webhookUrl: '',
      channelWelcomeTitle: '',
      channelWelcomeTagline: '',
      selectedFeatureFlags: [],
      replyTime: '',
      selectedTabIndex: 0,
      selectedPortalSlug: '',
      showBusinessNameInput: false,
      healthData: null,
      isLoadingHealth: false,
      healthError: null,
      isRegisteringWebhook: false,
      isTransferringWhatsAppToManual: false,
      widgetBubblePosition: 'right',
      widgetBubbleType: 'standard',
      widgetBubbleLauncherTitle: '',
      showConvertGate: false,
      // Set when the conversion was asked for from the legacy banner, which names its target.
      convertTarget: null,
      showLinkDeviceModal: false,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      isOnChatwootCloud: 'globalConfig/isOnChatwootCloud',
      isMetaMessageSendingDisabled: 'globalConfig/isMetaMessageSendingDisabled',
      uiFlags: 'inboxes/getUIFlags',
      portals: 'portals/allPortals',
    }),
    isInboundEmailEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.INBOUND_EMAILS
      );
    },
    showContinuityToggle() {
      if (this.isInboundEmailEnabled) return true;
      return this.isOnChatwootCloud;
    },
    isContinuityDisabled() {
      return this.isOnChatwootCloud && !this.isInboundEmailEnabled;
    },
    continuityDescription() {
      if (this.isContinuityDisabled) {
        return this.$t(
          'INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL_DISABLED_TEXT'
        );
      }
      return this.$t(
        'INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL_SUB_TEXT'
      );
    },
    selectedTabKey() {
      return this.tabs[this.selectedTabIndex]?.key;
    },
    // AccountHealth renders the structured provider error; TwilioHealth only needs the message.
    healthErrorMessage() {
      return this.healthError?.message || '';
    },
    shouldShowWhatsAppConfiguration() {
      return this.isAWhatsAppCloudChannel;
    },
    shouldShowTwilioHealth() {
      return this.isATwilioChannel && this.inbox.medium === 'sms';
    },
    whatsAppAPIProviderName() {
      if (this.isAWhatsAppCloudChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD');
      }
      if (this.is360DialogWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.360_DIALOG');
      }
      if (this.isATwilioWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO');
      }
      if (this.isAWhatsAppBaileysChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS');
      }
      if (this.isAWhatsAppZapiChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.ZAPI');
      }
      if (this.isASessionWhatsAppChannel) {
        return this.$t(
          `INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.${this.whatsAppAPIProvider.toUpperCase()}`
        );
      }
      return '';
    },
    // The catalog says which providers are legacy, and whether this account can pick the
    // native one; Baileys and Z-API are the legacy ones today.
    isLegacyWhatsAppProvider() {
      return (
        this.isAWhatsAppChannel &&
        Boolean(this.descriptorFor(this.whatsAppAPIProvider)?.legacy)
      );
    },
    isNativeWhatsAppAvailable() {
      return this.creatableProviders.some(({ key }) => key === 'native');
    },
    isConvertibleWhatsAppChannel() {
      return (
        this.isAWhatsAppCloudChannel ||
        this.isASessionWhatsAppChannel ||
        this.is360DialogWhatsAppChannel
      );
    },
    tabs() {
      let visibleToAllChannelTabs = [
        {
          key: 'inbox-settings',
          name: this.$t('INBOX_MGMT.TABS.SETTINGS'),
        },
        {
          key: 'collaborators',
          name: this.$t('INBOX_MGMT.TABS.COLLABORATORS'),
        },
      ];

      visibleToAllChannelTabs = [
        ...visibleToAllChannelTabs,
        {
          key: 'business-hours',
          name: this.$t('INBOX_MGMT.TABS.BUSINESS_HOURS'),
        },
        {
          key: 'csat',
          name: this.$t('INBOX_MGMT.TABS.CSAT'),
        },
      ];

      if (this.isAWebWidgetInbox) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'pre-chat-form',
            name: this.$t('INBOX_MGMT.TABS.PRE_CHAT_FORM'),
          },
        ];
      }

      if (
        this.isATwilioChannel ||
        this.isALineChannel ||
        this.isAPIInbox ||
        (this.isAnEmailChannel && !this.inbox.provider) ||
        this.shouldShowWhatsAppConfiguration ||
        this.isAWebWidgetInbox ||
        this.isASessionWhatsAppChannel
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'configuration',
            name: this.$t('INBOX_MGMT.TABS.CONFIGURATION'),
          },
        ];
      }

      if (
        this.isFeatureEnabledonAccount(this.accountId, FEATURE_FLAGS.AGENT_BOTS)
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'bot-configuration',
            name: this.$t('INBOX_MGMT.TABS.BOT_CONFIGURATION'),
          },
        ];
      }
      if (this.shouldShowWhatsAppConfiguration) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'whatsapp-health',
            name: this.$t('INBOX_MGMT.TABS.ACCOUNT_HEALTH'),
          },
        ];
      }

      if (this.shouldShowTwilioHealth) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'twilio-health',
            name: this.$t('INBOX_MGMT.TABS.ACCOUNT_HEALTH'),
          },
        ];
      }

      if (
        this.isATwilioChannel &&
        this.inbox.phone_number &&
        this.inbox.medium === 'sms' &&
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.CHANNEL_VOICE
        )
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'voice-configuration',
            name: this.$t('INBOX_MGMT.TABS.VOICE'),
          },
        ];
      }

      if (
        (this.isAWhatsAppCloudChannel ||
          this.hasInboxCapability(CAPABILITIES.VOICE_CALLS)) &&
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.CHANNEL_VOICE
        )
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'calls-configuration',
            name: this.$t('INBOX_MGMT.TABS.CALLS'),
          },
        ];
      }

      return visibleToAllChannelTabs;
    },
    currentInboxId() {
      return this.$route.params.inboxId;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.currentInboxId);
    },
    inboxIcon() {
      const {
        medium,
        channel_type: type,
        voice_enabled: voiceEnabled,
      } = this.inbox;
      return getInboxIconByType(type, medium, 'line', voiceEnabled);
    },
    bannerMaxWidth() {
      const narrowTabs = ['collaborators', 'bot-configuration'];
      const wideIfWebWidget = ['configuration', 'inbox-settings'];
      if (narrowTabs.includes(this.selectedTabKey)) return 'max-w-4xl';
      if (wideIfWebWidget.includes(this.selectedTabKey)) {
        return this.isAWebWidgetInbox ? 'max-w-7xl' : 'max-w-4xl';
      }
      return 'max-w-7xl';
    },
    inboxName() {
      return this.inbox.name;
    },
    inboxIdentifier() {
      return getInboxIdentifier(this.inbox);
    },
    canLocktoSingleConversation() {
      return (
        this.isASmsInbox ||
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAPIInbox ||
        this.isAnInstagramChannel ||
        this.isALineChannel ||
        this.isATiktokChannel ||
        this.isATelegramChannel
      );
    },
    inboxNameLabel() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.LABEL');
    },
    inboxNamePlaceHolder() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.PLACEHOLDER');
    },
    textAreaChannels() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return true;
      return false;
    },
    instagramUnauthorized() {
      return this.isAnInstagramChannel && this.inbox.reauthorization_required;
    },
    // Every tab, not just Configuration: a session inbox that dropped, or one just converted
    // and never paired, has nothing else on this page saying it cannot send or receive.
    showSessionDisconnectedBanner() {
      return (
        this.isASessionWhatsAppChannel &&
        isProviderOffline(this.inbox.provider_connection)
      );
    },
    showInstagramRestrictionSettingsBanner() {
      return this.isMetaMessageSendingDisabled && this.isAnInstagramChannel;
    },
    metaRestrictionStatusUrl() {
      return META_RESTRICTION_STATUS_URL;
    },
    tiktokUnauthorized() {
      return this.isATiktokChannel && this.inbox.reauthorization_required;
    },
    // Check if a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return this.inbox.channel_type === INBOX_TYPES.FB && instagramInbox;
    },
    microsoftUnauthorized() {
      return this.isAMicrosoftInbox && this.inbox.reauthorization_required;
    },
    facebookUnauthorized() {
      return this.isAFacebookInbox && this.inbox.reauthorization_required;
    },
    googleUnauthorized() {
      const isLegacyInbox = ['imap.gmail.com', 'imap.google.com'].includes(
        this.inbox.imap_address
      );

      return (
        (this.isAGoogleInbox || isLegacyInbox) &&
        this.inbox.reauthorization_required
      );
    },
    isEmbeddedSignupWhatsApp() {
      return this.inbox.provider_config?.source === 'embedded_signup';
    },
    whatsappUnauthorized() {
      return (
        this.isAWhatsAppCloudChannel &&
        this.isEmbeddedSignupWhatsApp &&
        this.inbox.reauthorization_required
      );
    },
    whatsappRegistrationIncomplete() {
      if (
        !this.healthData ||
        !this.isAWhatsAppCloudChannel ||
        !this.isEmbeddedSignupWhatsApp
      ) {
        return false;
      }

      return (
        this.healthData.platform_type === 'NOT_APPLICABLE' ||
        this.healthData.throughput?.level === 'NOT_APPLICABLE'
      );
    },
    showWhatsAppManualMigration() {
      return (
        this.isAWhatsAppCloudChannel &&
        this.isEmbeddedSignupWhatsApp &&
        this.healthData?.is_on_biz_app === false &&
        this.healthError?.type !== 'authorization' &&
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.WHATSAPP_MANUAL_TRANSFER
        )
      );
    },
    widgetBuilderStorageKey() {
      return `${LOCAL_STORAGE_KEYS.WIDGET_BUILDER}${this.inbox.id}`;
    },
  },
  watch: {
    // On a direct visit the inbox arrives after mount, so the catalog is fetched once the
    // page knows it is a WhatsApp inbox rather than at mount.
    isAWhatsAppChannel: {
      handler(isWhatsApp) {
        if (isWhatsApp) this.fetchWhatsappSessionProviders();
      },
      immediate: true,
    },
    $route(to, from) {
      if (to.name === 'settings_inbox_show') {
        const inboxChanged = to.params.inboxId !== from.params.inboxId;
        if (inboxChanged) {
          this.syncInboxData();
          this.setTabFromRouteParam();
          this.openWhatsAppManualMigrationIfRequested();
        }
      }
    },
    inbox: {
      handler(newInbox, oldInbox) {
        if (newInbox?.id !== oldInbox?.id) {
          this.syncInboxData();
          this.fetchHealthData();
          this.$nextTick(() => {
            this.setTabFromRouteParam();
            this.openWhatsAppManualMigrationIfRequested();
            this.openLinkDeviceModalIfRequested();
          });
        } else {
          this.selectedFeatureFlags = newInbox?.selected_feature_flags || [];
        }
      },
      immediate: true,
    },
  },
  mounted() {
    this.fetchSharedData();
    this.openWhatsAppManualMigrationIfRequested();
  },
  // The settings wrapper keeps this page alive per full path, so a conversion can land on
  // an instance that is reactivated rather than mounted, and no watcher fires for it.
  activated() {
    this.openLinkDeviceModalIfRequested();
  },
  methods: {
    // A conversion to a provider paired by QR leaves the inbox with no session, and the
    // pairing is the one thing left to do. Read wherever the page can first see that the
    // inbox has a session: on activation, or once a late inbox arrives.
    openLinkDeviceModalIfRequested() {
      if (!this.isASessionWhatsAppChannel) return;
      if (consumePairingRequest(this.inbox.id)) this.showLinkDeviceModal = true;
    },
    openWhatsAppManualMigrationDialog() {
      this.$refs.whatsappManualMigrationDialog?.open();
    },
    openWhatsAppManualMigrationIfRequested() {
      if (
        this.showWhatsAppManualMigration &&
        this.$route.query.migration === 'whatsapp_manual'
      ) {
        this.$nextTick(() => {
          this.openWhatsAppManualMigrationDialog();
        });
      }
    },
    async transferWhatsAppToManualSetup(form) {
      this.isTransferringWhatsAppToManual = true;
      try {
        const providerConfig = { ...(this.inbox.provider_config || {}) };
        delete providerConfig.source;
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...providerConfig,
              phone_number_id: form.phoneNumberId,
              business_account_id: form.wabaId,
              api_key: form.accessToken,
              app_secret: form.appSecret,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(
          this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_MANUAL_TRANSFER_SUCCESS')
        );
        this.$refs.whatsappManualMigrationDialog?.close();
      } catch (error) {
        useAlert(
          this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_MANUAL_TRANSFER_ERROR')
        );
      } finally {
        this.isTransferringWhatsAppToManual = false;
      }
    },
    async copyWebhookSecret(value) {
      await copyTextToClipboard(value);
      useAlert(
        this.$t(
          'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_SECRET.COPY_SUCCESS'
        )
      );
    },
    async resetWebhookSecret() {
      const response = await this.$store.dispatch(
        'inboxes/resetSecret',
        this.inbox.id
      );
      if (response) {
        useAlert(
          this.$t(
            'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_SECRET.RESET_SUCCESS'
          )
        );
      } else {
        useAlert(
          this.$t(
            'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_SECRET.RESET_ERROR'
          )
        );
      }
    },
    fetchSharedData() {
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
      this.$store.dispatch('labels/get');
      this.$store.dispatch('portals/index');
    },
    syncInboxData() {
      if (!this.inbox || !this.inbox.id) return;

      this.avatarUrl = this.inbox.avatar_url;
      this.inboxColor = this.inbox.inbox_color || '';
      this.inboxBadgeLabel = this.inbox.inbox_badge_label || '';
      this.chatBackgroundOpacity =
        Number(this.inbox.chat_background_opacity) || 22;
      this.chatBackgroundUrl = this.inbox.chat_background_url || '';
      this.chatBackgroundFile = null;
      this.removeChatBackgroundImage = false;
      this.antiSpamEnabled = Boolean(this.inbox.anti_spam_enabled);
      this.antiSpamMaxMessages =
        Number(this.inbox.anti_spam_max_messages) || 10;
      this.antiSpamWindowSeconds =
        Number(this.inbox.anti_spam_window_seconds) || 60;
      this.antiSpamCooldownSeconds =
        Number(this.inbox.anti_spam_cooldown_seconds) || 120;
      this.antiSpamWarningMessage =
        this.inbox.anti_spam_warning_message ||
        '⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens para não atrasar seu atendimento.';
      this.selectedInboxName = this.inbox.name;
      this.webhookUrl = this.inbox.webhook_url;
      this.greetingEnabled = this.inbox.greeting_enabled || false;
      this.greetingMessage = this.inbox.greeting_message || '';
      this.emailCollectEnabled = this.inbox.enable_email_collect;
      this.senderNameType = this.inbox.sender_name_type;
      this.businessName = this.inbox.business_name;
      this.allowMessagesAfterResolved =
        this.inbox.allow_messages_after_resolved;
      this.continuityViaEmail = this.inbox.continuity_via_email;
      this.channelWebsiteUrl = this.inbox.website_url;
      this.channelWelcomeTitle = this.inbox.welcome_title;
      this.channelWelcomeTagline = this.inbox.welcome_tagline || '';
      this.selectedFeatureFlags = this.inbox.selected_feature_flags || [];
      this.replyTime = this.inbox.reply_time;
      this.locktoSingleConversation = this.inbox.lock_to_single_conversation;
      this.legacyInbox = Boolean(this.inbox.legacy);
      this.selectedPortalSlug = this.inbox.help_center
        ? this.inbox.help_center.slug
        : '';

      const savedBubbleSettings = LocalStorage.get(
        this.widgetBuilderStorageKey
      );
      if (savedBubbleSettings) {
        this.widgetBubblePosition = savedBubbleSettings.position || 'right';
        this.widgetBubbleType = savedBubbleSettings.type || 'standard';
        this.widgetBubbleLauncherTitle =
          savedBubbleSettings.launcherTitle || '';
      } else {
        this.widgetBubblePosition = 'right';
        this.widgetBubbleType = 'standard';
        this.widgetBubbleLauncherTitle = '';
      }
    },
    async fetchHealthData() {
      if (!this.inbox) return;

      if (!this.isAWhatsAppCloudChannel && !this.shouldShowTwilioHealth) {
        return;
      }

      try {
        this.isLoadingHealth = true;
        // Cleared with the answer, not before asking. Until #593 there was nothing to press in the
        // error state, so the gap between the two never had a viewer; now the operator presses
        // Register, the re-read starts, and clearing the error here would drop the screen into the
        // "nothing is known" state for as long as the read takes, which with a quiet Meta is the
        // whole 10s ceiling: the error card, the provider message and the button all disappear and
        // come back.
        const response = await InboxHealthAPI.getHealthStatus(this.inbox.id);
        this.healthData = response.data;
        this.healthError = null;
      } catch (error) {
        const apiError = error.response?.data?.error;
        this.healthError =
          typeof apiError === 'object'
            ? apiError
            : {
                type: 'generic',
                message: apiError || error.message,
              };
      } finally {
        this.isLoadingHealth = false;
      }
    },
    goToWhatsAppConfiguration() {
      const configurationTabIndex = this.tabs.findIndex(
        tab => tab.key === 'configuration'
      );
      if (configurationTabIndex !== -1) {
        this.onTabChange(configurationTabIndex);
      }
    },
    async registerWebhook() {
      if (!this.inbox) return;

      try {
        this.isRegisteringWebhook = true;
        const { data } = await InboxHealthAPI.registerWebhook(this.inbox.id);
        // Meta refuses the per-number override for a whole class of accounts, and that refusal no
        // longer takes the channel down, so a plain success here would be the only thing the
        // operator sees about a write that did not land. The flag is about that write and nothing
        // else: it reads `false` for a refusal, for a 500 and for a connection that closed, so the
        // sentence sends the reader to the card instead of claiming where delivery goes.
        useAlert(
          data?.callback_override_applied === false
            ? this.$t(
                'INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.REGISTER_SUCCESS_WITHOUT_ROUTING'
              )
            : this.$t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.REGISTER_SUCCESS')
        );
        // The answer already carries the routing Meta reported after the write, so the card comes
        // from it instead of a second round trip. When that read did not come back the field says
        // so, and then the card is fetched rather than left showing what it had before the press.
        if (data?.routing_read_back) {
          // The error has to go with it. Until #593 the screen could not be repaired from the error
          // state at all, so nothing ever reached this line holding a stale failure; now it can,
          // and leaving `healthError` set would keep the error card over a reading that came back.
          this.healthData = data.health;
          this.healthError = null;
        } else {
          await this.fetchHealthData();
        }
      } catch (error) {
        // Same as the health fetch: the provider's own message is the actionable part.
        useAlert(
          error.response?.data?.error ||
            error.message ||
            this.$t('INBOX_MGMT.ACCOUNT_HEALTH.WEBHOOK.REGISTER_ERROR')
        );
      } finally {
        this.isRegisteringWebhook = false;
      }
    },
    handleFeatureFlag(e) {
      this.selectedFeatureFlags = this.toggleInput(
        this.selectedFeatureFlags,
        e.target.value
      );
    },
    toggleInput(selected, current) {
      if (selected.includes(current)) {
        const newSelectedFlags = selected.filter(flag => flag !== current);
        return newSelectedFlags;
      }
      return [...selected, current];
    },
    onTabChange(selectedTabIndex) {
      this.selectedTabIndex = selectedTabIndex;
      this.updateRouteWithoutRefresh(selectedTabIndex);
    },
    updateRouteWithoutRefresh(selectedTabIndex) {
      const tab = this.tabs[selectedTabIndex];
      if (!tab) return;

      const { accountId, inboxId } = this.$route.params;
      const baseUrl = `/app/accounts/${accountId}/settings/inboxes/${inboxId}`;

      // Append the tab key only if it's not the default.
      const newUrl =
        tab.key === 'inbox-settings' ? baseUrl : `${baseUrl}/${tab.key}`;
      // Update URL without triggering route watcher
      window.history.replaceState(null, '', newUrl);
    },
    setTabFromRouteParam() {
      const { tab: tabParam } = this.$route.params;
      if (!tabParam) {
        this.selectedTabIndex = 0;
        return;
      }
      const tabIndex = this.tabs.findIndex(tab => tab.key === tabParam);
      this.selectedTabIndex = tabIndex === -1 ? 0 : tabIndex;
    },
    async updateInbox() {
      const bubbleSettings = {
        position: this.widgetBubblePosition,
        type: this.widgetBubbleType,
        launcherTitle: this.widgetBubbleLauncherTitle,
      };
      LocalStorage.set(this.widgetBuilderStorageKey, bubbleSettings);

      try {
        const payload = {
          id: this.currentInboxId,
          name: this.selectedInboxName?.trim(),
          enable_email_collect: this.emailCollectEnabled,
          allow_messages_after_resolved: this.allowMessagesAfterResolved,
          greeting_enabled: this.greetingEnabled,
          greeting_message: this.greetingMessage || '',
          portal_id: this.selectedPortalSlug
            ? this.portals.find(
                portal => portal.slug === this.selectedPortalSlug
              )?.id || null
            : null,
          lock_to_single_conversation: this.locktoSingleConversation,
          legacy: this.legacyInbox,
          sender_name_type: this.senderNameType,
          business_name: this.businessName || null,
          inbox_color: this.inboxColor || '',
          inbox_badge_label: this.inboxBadgeLabel?.trim() || '',
          chat_background_opacity: Number(this.chatBackgroundOpacity) || 22,
          remove_chat_background_image: this.removeChatBackgroundImage,
          anti_spam_enabled: Boolean(this.antiSpamEnabled),
          anti_spam_max_messages: Number(this.antiSpamMaxMessages) || 10,
          anti_spam_window_seconds: Number(this.antiSpamWindowSeconds) || 60,
          anti_spam_cooldown_seconds:
            Number(this.antiSpamCooldownSeconds) || 120,
          anti_spam_warning_message:
            this.antiSpamWarningMessage?.trim() ||
            '⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens para não atrasar seu atendimento.',
          channel: {
            widget_color: this.inbox.widget_color,
            website_url: this.channelWebsiteUrl,
            webhook_url: this.webhookUrl,
            welcome_title: this.channelWelcomeTitle || '',
            welcome_tagline: this.channelWelcomeTagline || '',
            selectedFeatureFlags: this.selectedFeatureFlags,
            reply_time: this.replyTime || 'in_a_few_minutes',
            continuity_via_email:
              this.isInboundEmailEnabled && this.continuityViaEmail,
          },
        };
        if (this.avatarFile) {
          payload.avatar = this.avatarFile;
        }
        if (this.chatBackgroundFile) {
          payload.chat_background_image = this.chatBackgroundFile;
        }
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
        this.showBusinessNameInput = false;
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    handleChatBackgroundUpload(event) {
      const file = event?.target?.files?.[0];
      if (!file) return;
      this.chatBackgroundFile = file;
      this.chatBackgroundUrl = URL.createObjectURL(file);
      this.removeChatBackgroundImage = false;
    },
    handleChatBackgroundRemove() {
      this.chatBackgroundFile = null;
      this.chatBackgroundUrl = '';
      this.removeChatBackgroundImage = true;
      if (this.$refs.chatBackgroundInput) {
        this.$refs.chatBackgroundInput.value = '';
      }
    },
    async handleAvatarDelete() {
      try {
        await this.$store.dispatch(
          'inboxes/deleteInboxAvatar',
          this.currentInboxId
        );
        this.avatarFile = null;
        this.avatarUrl = '';
        useAlert(this.$t('INBOX_MGMT.DELETE.API.AVATAR_SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('INBOX_MGMT.DELETE.API.AVATAR_ERROR_MESSAGE')
        );
      }
    },
    toggleSenderNameType(key) {
      this.senderNameType = key;
    },
    onClickShowBusinessNameInput() {
      this.showBusinessNameInput = true;
      this.$nextTick(() => {
        this.$refs.businessNameInput?.focus();
      });
    },
    hideBusinessNameInput() {
      this.showBusinessNameInput = false;
    },
    toggleLockToSingleConversation(value) {
      this.locktoSingleConversation = value;
    },
    openConvertGate(target = null) {
      this.convertTarget = target;
      this.showConvertGate = true;
    },
    closeConvertGate() {
      this.showConvertGate = false;
    },
    // The legacy banner goes through the same gate as the provider field's button: the
    // conversion is the same act whichever button asked for it. It only arrives with the
    // native provider already picked.
    openConvertGateToNative() {
      this.openConvertGate('native');
    },
    goToConvert() {
      const provider = this.convertTarget;
      this.showConvertGate = false;
      this.convertTarget = null;
      this.$router.push({
        name: 'settings_inbox_convert',
        params: {
          accountId: this.$route.params.accountId,
          inboxId: this.inbox.id,
        },
        ...(provider ? { query: { provider } } : {}),
      });
    },
  },
  validations: {
    webhookUrl: {
      shouldBeUrl,
    },
    selectedInboxName: {},
  },
};
</script>

<template>
  <div
    v-if="uiFlags.isFetching"
    class="flex items-center justify-center h-full w-full"
  >
    <SpinnerLoader :size="28" class="text-n-blue-9" />
  </div>
  <div
    v-else
    class="grid grid-rows-[auto_1fr] h-full flex-grow flex-shrink pr-0 pl-0 w-full min-w-0 settings"
  >
    <SettingIntroBanner
      :header-image="inbox.avatarUrl"
      :header-title="inboxName"
      :header-identifier="inboxIdentifier"
    >
      <woot-tabs
        class="[&_ul]:p-0 top-px relative"
        :index="selectedTabIndex"
        :border="false"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="(tab, index) in tabs"
          :key="tab.key"
          :index="index"
          :name="tab.name"
          :show-badge="false"
          is-compact
        />
      </woot-tabs>
    </SettingIntroBanner>
    <section class="w-full overflow-auto py-8">
      <div class="max-w-7xl mx-auto w-full">
        <WhatsappServiceQuotaCard
          v-if="isAWhatsAppCloudChannel && selectedTabKey !== 'configuration'"
          :inbox="inbox"
          class="mx-6 mb-6 max-w-4xl"
        />
        <MicrosoftReauthorize
          v-if="microsoftUnauthorized"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <FacebookReauthorize
          v-if="facebookUnauthorized"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <GoogleReauthorize
          v-if="googleUnauthorized"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <InstagramReauthorize
          v-if="instagramUnauthorized"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <TiktokReauthorize
          v-if="tiktokUnauthorized"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <WhatsappReauthorize
          v-if="whatsappUnauthorized"
          :whatsapp-registration-incomplete="whatsappRegistrationIncomplete"
          :inbox="inbox"
          class="mb-4"
          :class="bannerMaxWidth"
        />
        <DuplicateInboxBanner
          v-if="hasDuplicateInstagramInbox"
          :content="$t('INBOX_MGMT.ADD.INSTAGRAM.DUPLICATE_INBOX_BANNER')"
          class="mx-6 mb-4"
          :class="bannerMaxWidth"
        />
        <Banner
          v-if="showInstagramRestrictionSettingsBanner"
          color="amber"
          class="mx-6 mb-4 max-w-4xl"
        >
          <div class="flex items-start gap-3 text-start">
            <Icon
              icon="i-lucide-triangle-alert"
              class="flex-shrink-0 size-4 mt-0.5"
            />
            <span>
              {{ $t('INBOX_MGMT.ADD.INSTAGRAM.SETTINGS_RESTRICTED_WARNING') }}
              <a
                :href="metaRestrictionStatusUrl"
                class="link underline"
                rel="noopener noreferrer nofollow"
                target="_blank"
              >
                {{ $t('INBOX_MGMT.ADD.INSTAGRAM.STATUS_LINK') }}
              </a>
            </span>
          </div>
        </Banner>
        <Banner
          v-if="showSessionDisconnectedBanner"
          color="ruby"
          :action-label="
            $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_DISCONNECTED.CONNECT')
          "
          class="mx-6 mb-4"
          :class="bannerMaxWidth"
          data-testid="whatsapp-session-disconnected-banner"
          @action="showLinkDeviceModal = true"
        >
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_DISCONNECTED.MESSAGE') }}
        </Banner>
        <WhatsappLegacyProviderBanner
          v-if="isLegacyWhatsAppProvider"
          :native-available="isNativeWhatsAppAvailable"
          can-convert
          class="mx-6 mb-4"
          :class="bannerMaxWidth"
          @convert="openConvertGateToNative"
        />
        <WhatsappManualMigrationBanner
          v-if="showWhatsAppManualMigration"
          class="mx-6 mb-6"
          :class="bannerMaxWidth"
          @start="openWhatsAppManualMigrationDialog"
        />

        <div
          v-if="selectedTabKey === 'inbox-settings'"
          class="flex flex-col md:flex-row items-center lg:items-start justify-between gap-5 lg:gap-10 mx-6"
        >
          <div
            class="flex-1 flex flex-col min-w-0"
            :class="{
              'max-w-2xl': isAWebWidgetInbox,
              'max-w-4xl': !isAWebWidgetInbox,
            }"
          >
            <div class="flex flex-col gap-1 items-start mb-4">
              <label class="text-heading-3 text-n-slate-12">
                {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_AVATAR.LABEL') }}
              </label>
              <Avatar
                :src="avatarUrl"
                :size="64"
                :icon-name="inboxIcon"
                name=""
                allow-upload
                rounded-full
                @upload="handleImageUpload"
                @delete="handleAvatarDelete"
              />
            </div>
            <SettingsFieldSection :label="inboxNameLabel">
              <woot-input
                v-model="selectedInboxName"
                class="[&>input]:!mb-0"
                :class="{ error: v$.selectedInboxName.$error }"
                :placeholder="inboxNamePlaceHolder"
                :error="
                  v$.selectedInboxName.$error
                    ? $t('INBOX_MGMT.ADD.CHANNEL_NAME.ERROR')
                    : ''
                "
                @blur="v$.selectedInboxName.$touch"
              />
            </SettingsFieldSection>
            <SettingsFieldSection
              v-if="isAPIInbox"
              :label="
                $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.LABEL')
              "
            >
              <woot-input
                v-model="webhookUrl"
                class="[&>input]:!mb-0"
                :class="{ error: v$.webhookUrl.$error }"
                :placeholder="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.PLACEHOLDER'
                  )
                "
                :error="
                  v$.webhookUrl.$error
                    ? $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.ERROR'
                      )
                    : ''
                "
                @blur="v$.webhookUrl.$touch"
              />
            </SettingsFieldSection>

            <SettingsFieldSection
              v-if="isAPIInbox && inbox.secret"
              :label="
                $t(
                  'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_SECRET.LABEL'
                )
              "
            >
              <AccessToken
                :value="inbox.secret"
                @on-copy="copyWebhookSecret"
                @on-reset="resetWebhookSecret"
              />
            </SettingsFieldSection>

            <SettingsFieldSection
              v-if="isAWebWidgetInbox"
              :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL')"
            >
              <woot-input
                v-model="channelWebsiteUrl"
                class="[&>input]:!mb-0"
                :placeholder="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER'
                  )
                "
              />
            </SettingsFieldSection>

            <SettingsFieldSection
              v-if="isAWhatsAppChannel"
              :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL')"
            >
              <div class="flex items-center gap-2 w-full">
                <input
                  :value="whatsAppAPIProviderName"
                  type="text"
                  disabled
                  class="!mb-0 flex-1"
                />
                <NextButton
                  v-if="isConvertibleWhatsAppChannel"
                  slate
                  sm
                  :label="$t('INBOX_MGMT.CONVERT.BUTTON')"
                  @click="openConvertGate()"
                />
              </div>
            </SettingsFieldSection>

            <SettingsFieldSection
              :label="$t('INBOX_MGMT.HELP_CENTER.LABEL')"
              :help-text="$t('INBOX_MGMT.HELP_CENTER.SUB_TEXT')"
            >
              <SelectInput
                v-model="selectedPortalSlug"
                :placeholder="$t('INBOX_MGMT.HELP_CENTER.PLACEHOLDER')"
                :options="[
                  { value: '', label: $t('INBOX_MGMT.HELP_CENTER.NONE') },
                  ...portals.map(p => ({ value: p.slug, label: p.name })),
                ]"
              />
            </SettingsFieldSection>

            <SettingsFieldSection
              v-if="canLocktoSingleConversation"
              :label="
                $t('INBOX_MGMT.SETTINGS_POPUP.LOCK_TO_SINGLE_CONVERSATION')
              "
              class="[&>div>div]:justify-end [&>div>div]:flex lg:[&>div:first-child]:h-12 [&>div:first-child]:h-16"
            >
              <template #extra>
                <LockToSingleConversationPreview
                  :lock-to-single-conversation="locktoSingleConversation"
                  @update="toggleLockToSingleConversation"
                />
              </template>
            </SettingsFieldSection>

            <SettingsToggleSection
              v-model="legacyInbox"
              :header="$t('INBOX_MGMT.SETTINGS_POPUP.LEGACY_INBOX')"
              :description="
                $t('INBOX_MGMT.SETTINGS_POPUP.LEGACY_INBOX_SUB_TEXT')
              "
            />

            <SettingsFieldSection
              v-if="isAWebWidgetInbox || isAnEmailChannel"
              :label="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.TITLE')"
              class="[&>div>div]:justify-end [&>div>div]:flex lg:[&>div:first-child]:h-12 [&>div:first-child]:h-16"
            >
              <NextButton
                v-if="!showBusinessNameInput"
                ghost
                blue
                sm
                :label="
                  $t(
                    'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.BUTTON_TEXT'
                  )
                "
                @click="onClickShowBusinessNameInput"
              />

              <div
                v-if="showBusinessNameInput"
                v-on-clickaway="hideBusinessNameInput"
                class="flex justify-end gap-2 w-full"
              >
                <input
                  ref="businessNameInput"
                  v-model="businessName"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.PLACEHOLDER'
                    )
                  "
                  class="!mb-0"
                  type="text"
                />
                <NextButton
                  :label="
                    $t(
                      'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.SAVE_BUTTON_TEXT'
                    )
                  "
                  class="flex-shrink-0"
                  @click="updateInbox"
                />
              </div>

              <template #extra>
                <SenderNameExamplePreview
                  :sender-name-type="senderNameType"
                  :business-name="businessName"
                  :is-website-channel="isAWebWidgetInbox"
                  @update="toggleSenderNameType"
                />
              </template>
            </SettingsFieldSection>

            <SettingsAccordion
              v-if="isAWebWidgetInbox"
              :title="$t('INBOX_MGMT.WIDGET_FEATURES')"
              class="mt-6"
            >
              <SettingsFieldSection
                :label="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL'
                  )
                "
              >
                <woot-input
                  v-model="channelWelcomeTitle"
                  class="[&>input]:!mb-0"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER'
                    )
                  "
                />
              </SettingsFieldSection>

              <SettingsFieldSection
                :label="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL'
                  )
                "
                class="[&>div]:!items-start [&>div>label]:mt-1"
              >
                <Editor
                  v-model="channelWelcomeTagline"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER'
                    )
                  "
                  :max-length="255"
                  channel-type="Context::InboxSettings"
                />
              </SettingsFieldSection>

              <SettingsFieldSection
                :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL')"
              >
                <div class="justify-start">
                  <ColorPicker v-model="inbox.widget_color" />
                </div>
              </SettingsFieldSection>
              <SettingsFieldSection
                :label="
                  $t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE')
                "
              >
                <div class="flex items-center gap-6">
                  <div class="flex items-center gap-2">
                    <label class="text-n-slate-11 text-heading-3">
                      {{
                        $t(
                          'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_POSITION_LABEL'
                        )
                      }}
                    </label>
                    <SelectInput
                      v-model="widgetBubblePosition"
                      :options="[
                        {
                          label: $t(
                            'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_POSITION.LEFT'
                          ),
                          value: 'left',
                        },
                        {
                          label: $t(
                            'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_POSITION.RIGHT'
                          ),
                          value: 'right',
                        },
                      ]"
                      class="[&>select]:!p-0 min-w-16 [&>select]:!outline-none"
                    />
                  </div>
                  <div class="h-3 w-px bg-n-weak rounded-lg" />
                  <div class="flex items-center gap-2">
                    <label class="text-n-slate-11 text-heading-3">
                      {{
                        $t(
                          'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_TYPE_LABEL'
                        )
                      }}
                    </label>
                    <SelectInput
                      v-model="widgetBubbleType"
                      :options="[
                        {
                          label: $t(
                            'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_TYPE.STANDARD'
                          ),
                          value: 'standard',
                        },
                        {
                          label: $t(
                            'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_TYPE.EXPANDED_BUBBLE'
                          ),
                          value: 'expanded_bubble',
                        },
                      ]"
                      class="[&>select]:!p-0 min-w-16 [&>select]:!outline-none"
                    />
                  </div>
                </div>
              </SettingsFieldSection>

              <SettingsFieldSection
                :label="
                  $t(
                    'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_LAUNCHER_TITLE.LABEL'
                  )
                "
              >
                <woot-input
                  v-model="widgetBubbleLauncherTitle"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_BUBBLE_LAUNCHER_TITLE.PLACE_HOLDER'
                    )
                  "
                  class="[&>input]:!mb-0"
                />
              </SettingsFieldSection>
              <SettingsFieldSection
                :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.TITLE')"
                :help-text="
                  $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.HELP_TEXT')
                "
              >
                <SelectInput
                  v-model="replyTime"
                  :options="[
                    {
                      value: 'in_a_few_minutes',
                      label: $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_MINUTES'
                      ),
                    },
                    {
                      value: 'in_a_few_hours',
                      label: $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_FEW_HOURS'
                      ),
                    },
                    {
                      value: 'in_a_day',
                      label: $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.REPLY_TIME.IN_A_DAY'
                      ),
                    },
                  ]"
                />
              </SettingsFieldSection>

              <SettingsFieldSection
                :label="$t('INBOX_MGMT.FEATURES.LABEL')"
                class="[&>div]:!items-start [&>div>label]:mt-2"
              >
                <div class="flex flex-col gap-1 items-start">
                  <div class="flex gap-2 pt-2 py-0.5">
                    <input
                      v-model="selectedFeatureFlags"
                      type="checkbox"
                      value="attachments"
                      @input="handleFeatureFlag"
                    />
                    <label for="attachments">
                      {{ $t('INBOX_MGMT.FEATURES.DISPLAY_FILE_PICKER') }}
                    </label>
                  </div>
                  <div class="flex gap-2 py-0.5">
                    <input
                      v-model="selectedFeatureFlags"
                      type="checkbox"
                      value="emoji_picker"
                      @input="handleFeatureFlag"
                    />
                    <label for="emoji_picker">
                      {{ $t('INBOX_MGMT.FEATURES.DISPLAY_EMOJI_PICKER') }}
                    </label>
                  </div>
                  <div class="flex gap-2 py-0.5">
                    <input
                      v-model="selectedFeatureFlags"
                      type="checkbox"
                      value="end_conversation"
                      @input="handleFeatureFlag"
                    />
                    <label for="end_conversation">
                      {{ $t('INBOX_MGMT.FEATURES.ALLOW_END_CONVERSATION') }}
                    </label>
                  </div>
                  <div class="flex gap-2 py-0.5">
                    <input
                      v-model="selectedFeatureFlags"
                      type="checkbox"
                      value="use_inbox_avatar_for_bot"
                      @input="handleFeatureFlag"
                    />
                    <label for="use_inbox_avatar_for_bot">
                      {{ $t('INBOX_MGMT.FEATURES.USE_INBOX_AVATAR_FOR_BOT') }}
                    </label>
                  </div>
                  <div class="flex gap-2 py-0.5">
                    <input
                      id="browser_push_notifications"
                      v-model="selectedFeatureFlags"
                      type="checkbox"
                      value="browser_push_notifications"
                      @input="handleFeatureFlag"
                    />
                    <label for="browser_push_notifications">
                      {{ $t('INBOX_MGMT.FEATURES.BROWSER_PUSH_NOTIFICATIONS') }}
                    </label>
                  </div>
                </div>
              </SettingsFieldSection>
            </SettingsAccordion>

            <SettingsAccordion
              :title="$t('INBOX_MGMT.CHANNEL_PREFERENCES')"
              class="mt-6"
            >
              <SettingsToggleSection
                v-model="greetingEnabled"
                :header="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.LABEL'
                  )
                "
                :description="
                  $t(
                    'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_TOGGLE.HELP_TEXT'
                  )
                "
              >
                <template v-if="greetingEnabled" #editor>
                  <GreetingsEditor
                    v-model="greetingMessage"
                    :label="
                      $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.LABEL'
                      )
                    "
                    :placeholder="
                      $t(
                        'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_GREETING_MESSAGE.PLACEHOLDER'
                      )
                    "
                    :richtext="!textAreaChannels"
                  />
                </template>
              </SettingsToggleSection>

              <SettingsToggleSection
                v-if="isAWebWidgetInbox"
                v-model="emailCollectEnabled"
                :header="
                  $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX')
                "
                :description="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.ENABLE_EMAIL_COLLECT_BOX_SUB_TEXT'
                  )
                "
              />

              <SettingsToggleSection
                v-if="isAWebWidgetInbox"
                v-model="allowMessagesAfterResolved"
                :header="
                  $t('INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED')
                "
                :description="
                  $t(
                    'INBOX_MGMT.SETTINGS_POPUP.ALLOW_MESSAGES_AFTER_RESOLVED_SUB_TEXT'
                  )
                "
              />

              <SettingsToggleSection
                v-if="isAWebWidgetInbox && showContinuityToggle"
                v-model="continuityViaEmail"
                :header="
                  $t('INBOX_MGMT.SETTINGS_POPUP.ENABLE_CONTINUITY_VIA_EMAIL')
                "
                :description="continuityDescription"
                :hide-toggle="isContinuityDisabled"
                :class="
                  isContinuityDisabled ? 'cursor-not-allowed opacity-50' : ''
                "
              />
            </SettingsAccordion>

            <SettingsAccordion
              v-if="isAWebWidgetInbox"
              title="Proteção Anti-Spam e Anti-Flood (Chat do Cliente)"
              class="mt-6"
            >
              <SettingsToggleSection
                v-model="antiSpamEnabled"
                header="Ativar bloqueio automático contra flood/spam de mensagens"
                description="Quando o cliente envia muitas mensagens seguidas em curto espaço de tempo sem aguardar resposta, o campo de digitação é travado temporariamente com contador regressivo e aviso na tela."
              />

              <div
                v-if="antiSpamEnabled"
                class="flex flex-col gap-4 mt-3 p-4 rounded-xl border border-n-weak bg-n-solid-2"
              >
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex flex-col gap-1">
                    <label class="text-xs font-semibold text-n-slate-12">
                      Limite de mensagens seguidas
                    </label>
                    <input
                      v-model.number="antiSpamMaxMessages"
                      type="number"
                      min="2"
                      max="50"
                      class="!mb-0 rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
                    />
                    <span class="text-[11px] text-n-slate-11">
                      Ex: 10 mensagens seguidas
                    </span>
                  </div>

                  <div class="flex flex-col gap-1">
                    <label class="text-xs font-semibold text-n-slate-12">
                      Janela de detecção (segundos)
                    </label>
                    <input
                      v-model.number="antiSpamWindowSeconds"
                      type="number"
                      min="10"
                      max="600"
                      class="!mb-0 rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
                    />
                    <span class="text-[11px] text-n-slate-11">
                      Ex: 60s (1 minuto)
                    </span>
                  </div>

                  <div class="flex flex-col gap-1">
                    <label class="text-xs font-semibold text-n-slate-12">
                      Tempo de bloqueio / Cooldown (segundos)
                    </label>
                    <input
                      v-model.number="antiSpamCooldownSeconds"
                      type="number"
                      min="15"
                      max="1800"
                      class="!mb-0 rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
                    />
                    <span class="text-[11px] text-n-slate-11">
                      Ex: 120s (2 minutos). Destrava se o atendente responder.
                    </span>
                  </div>
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-semibold text-n-slate-12">
                    Mensagem de aviso exibida ao cliente quando o chat travar
                  </label>
                  <textarea
                    v-model="antiSpamWarningMessage"
                    rows="2"
                    class="!mb-0 rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
                    placeholder="⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens."
                  />
                </div>
              </div>
            </SettingsAccordion>

            <SettingsAccordion
              title="Identidade Visual da Caixa na Conversa"
              class="mt-6"
            >
              <SettingsFieldSection
                label="Cor da Caixa (Barra Lateral e Tag)"
                help-text="Define a barra colorida lateral e a pílula de identificação no topo das conversas desta caixa."
              >
                <div class="flex flex-col gap-3">
                  <div class="flex flex-wrap items-center gap-3">
                    <input
                      v-model="inboxColor"
                      type="color"
                      class="h-10 w-14 rounded-lg border border-n-weak cursor-pointer bg-transparent p-0.5"
                    />
                    <woot-input
                      v-model="inboxColor"
                      class="[&>input]:!mb-0 w-36"
                      placeholder="#EAB308"
                    />
                    <div class="flex flex-wrap items-center gap-1.5">
                      <button
                        v-for="preset in inboxColorPresets"
                        :key="preset"
                        type="button"
                        class="size-6 rounded-md border border-n-weak transition-transform hover:scale-110"
                        :class="{
                          'ring-2 ring-offset-1 ring-n-brand':
                            inboxColor.toUpperCase() === preset,
                        }"
                        :style="{ backgroundColor: preset }"
                        :title="preset"
                        @click="inboxColor = preset"
                      />
                    </div>
                    <button
                      v-if="inboxColor"
                      type="button"
                      class="text-xs text-n-slate-11 hover:text-n-ruby-11 underline ml-1"
                      @click="inboxColor = ''"
                    >
                      Limpar cor
                    </button>
                  </div>
                </div>
              </SettingsFieldSection>

              <SettingsFieldSection
                label="Texto da Tag no Topo da Conversa"
                help-text="Ex: BARBA GAMES ou GAMES SAFARI. Se deixar em branco, usará o nome da caixa em maiúsculas quando uma cor estiver ativa."
              >
                <woot-input
                  v-model="inboxBadgeLabel"
                  class="[&>input]:!mb-0"
                  :placeholder="(selectedInboxName || 'GAMES SAFARI').toUpperCase()"
                />
              </SettingsFieldSection>

              <SettingsFieldSection
                label="Logo / Imagem de Fundo do Chat (Marca d'água)"
                help-text="Aparece centralizada no fundo da conversa aberta com opacidade suave (recomendado PNG transparente)."
              >
                <div class="flex flex-col gap-3">
                  <div class="flex flex-wrap items-center gap-3">
                    <input
                      ref="chatBackgroundInput"
                      type="file"
                      accept="image/png,image/jpeg,image/webp,image/gif"
                      class="text-xs text-n-slate-11 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-n-alpha-2 file:text-n-slate-12 hover:file:bg-n-alpha-3 cursor-pointer"
                      @change="handleChatBackgroundUpload"
                    />
                    <button
                      v-if="chatBackgroundUrl"
                      type="button"
                      class="text-xs text-n-ruby-11 hover:underline font-medium"
                      @click="handleChatBackgroundRemove"
                    >
                      Remover imagem de fundo
                    </button>
                  </div>

                  <div class="flex items-center gap-3 max-w-md">
                    <span class="text-xs text-n-slate-11 whitespace-nowrap">
                      Opacidade da Logo: {{ chatBackgroundOpacity }}%
                    </span>
                    <input
                      v-model.number="chatBackgroundOpacity"
                      type="range"
                      min="5"
                      max="60"
                      step="1"
                      class="w-full cursor-pointer"
                    />
                  </div>

                  <div
                    class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2 p-3 rounded-xl border border-n-weak bg-n-solid-2"
                  >
                    <div class="flex flex-col gap-1.5">
                      <span class="text-xs font-medium text-n-slate-11">
                        Prévia na Lista de Conversas:
                      </span>
                      <div
                        class="relative flex items-start gap-2.5 p-3 rounded-lg bg-n-surface-1 border border-n-weak overflow-hidden"
                      >
                        <span
                          v-if="inboxColor"
                          class="absolute inset-y-0.5 left-0 w-1 rounded-r-sm"
                          :style="{ backgroundColor: inboxColor }"
                        />
                        <div
                          class="size-8 rounded-lg bg-n-alpha-2 flex items-center justify-center text-xs font-bold text-n-slate-11 mt-3 ml-1"
                        >
                          SC
                        </div>
                        <div class="flex flex-col min-w-0 flex-1">
                          <div>
                            <span
                              class="inline-flex items-center px-2 py-0.5 rounded-[5px] text-[11px] font-bold uppercase tracking-wide leading-4"
                              :style="
                                inboxColor
                                  ? {
                                      backgroundColor: `${inboxColor}33`,
                                      color: inboxColor,
                                      border: `1px solid ${inboxColor}59`,
                                    }
                                  : {}
                              "
                            >
                              {{
                                (
                                  inboxBadgeLabel ||
                                  selectedInboxName ||
                                  'NOME DA CAIXA'
                                ).toUpperCase()
                              }}
                            </span>
                          </div>
                          <span class="text-sm font-semibold text-n-slate-12 mt-0.5">
                            Cliente Exemplo
                          </span>
                          <span class="text-xs text-n-slate-11 truncate">
                            Olá, preciso de ajuda com meu pedido...
                          </span>
                        </div>
                      </div>
                    </div>

                    <div class="flex flex-col gap-1.5">
                      <span class="text-xs font-medium text-n-slate-11">
                        Prévia do Fundo do Chat:
                      </span>
                      <div
                        class="relative h-24 rounded-lg bg-n-surface-1 border border-n-weak flex items-center justify-center overflow-hidden p-3"
                      >
                        <img
                          v-if="chatBackgroundUrl"
                          :src="chatBackgroundUrl"
                          alt="Preview fundo"
                          class="max-h-16 max-w-[75%] object-contain pointer-events-none"
                          :style="{ opacity: (chatBackgroundOpacity || 22) / 100 }"
                        />
                        <span
                          v-else
                          class="text-xs text-n-slate-10 italic"
                        >
                          Nenhuma imagem de fundo selecionada
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </SettingsFieldSection>
            </SettingsAccordion>

            <div class="w-full flex justify-end items-center py-4 mt-2">
              <NextButton
                v-if="isAPIInbox"
                type="submit"
                :disabled="v$.webhookUrl.$invalid"
                :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
                :is-loading="uiFlags.isUpdating"
                @click="updateInbox"
              />
              <NextButton
                v-else
                type="submit"
                :disabled="v$.$invalid"
                :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
                :is-loading="uiFlags.isUpdating"
                @click="updateInbox"
              />
            </div>
          </div>

          <div
            v-if="isAWebWidgetInbox"
            class="flex-1 sticky top-4 self-start max-w-lg flex-shrink-0 w-full min-w-0"
          >
            <div
              class="flex flex-col outline -outline-offset-1 outline-1 outline-n-weak w-full px-3 pt-3 pb-8 bg-n-surface-1 rounded-2xl min-h-[45rem] overflow-hidden"
            >
              <Widget
                :welcome-heading="channelWelcomeTitle"
                :welcome-tagline="channelWelcomeTagline"
                :website-name="selectedInboxName"
                :logo="avatarUrl"
                is-online
                :reply-time="replyTime"
                :color="inbox.widget_color"
                :widget-bubble-position="widgetBubblePosition"
                :widget-bubble-launcher-title="widgetBubbleLauncherTitle"
                :widget-bubble-type="widgetBubbleType"
                :web-widget-script="inbox.web_widget_script"
              />
            </div>
          </div>
        </div>

        <div v-if="selectedTabKey === 'collaborators'" class="mx-6 max-w-4xl">
          <CollaboratorsPage :inbox="inbox" />
        </div>
        <div
          v-if="selectedTabKey === 'configuration'"
          class="mx-6"
          :class="isAWebWidgetInbox ? 'max-w-7xl' : 'max-w-4xl'"
        >
          <ConfigurationPage :inbox="inbox" />
        </div>
        <div
          v-if="selectedTabKey === 'voice-configuration'"
          class="mx-6 max-w-4xl"
        >
          <VoiceConfigurationPage :inbox="inbox" />
        </div>
        <div
          v-if="selectedTabKey === 'calls-configuration'"
          class="mx-6 max-w-4xl"
        >
          <WhatsappCallingPage :inbox="inbox" />
        </div>
        <div v-if="selectedTabKey === 'csat'">
          <CustomerSatisfactionPage :inbox="inbox" />
        </div>
        <div v-if="selectedTabKey === 'pre-chat-form'">
          <PreChatFormSettings :inbox="inbox" />
        </div>
        <div v-if="selectedTabKey === 'business-hours'">
          <WeeklyAvailability :inbox="inbox" />
        </div>
        <div v-if="selectedTabKey === 'bot-configuration'">
          <BotConfiguration :inbox="inbox" />
        </div>
        <div v-if="selectedTabKey === 'whatsapp-health'">
          <AccountHealth
            :health-data="healthData"
            :health-error="healthError"
            :is-embedded-signup="isEmbeddedSignupWhatsApp"
            :is-registering-webhook="isRegisteringWebhook"
            @register-webhook="registerWebhook"
            @go-to-configuration="goToWhatsAppConfiguration"
          />
        </div>
        <div v-if="selectedTabKey === 'twilio-health'">
          <TwilioHealth
            :health-data="healthData"
            :is-loading="isLoadingHealth"
            :error="healthErrorMessage"
            :is-registering-webhook="isRegisteringWebhook"
            @register-webhook="registerWebhook"
          />
        </div>
        <WhatsappManualMigrationDialog
          v-if="showWhatsAppManualMigration"
          ref="whatsappManualMigrationDialog"
          :inbox="inbox"
          :is-loading="isTransferringWhatsAppToManual"
          @reconnect="transferWhatsAppToManualSetup"
        />
      </div>
    </section>
    <ConvertInboxModal
      v-if="showConvertGate"
      v-model:show="showConvertGate"
      :inbox-name="inbox.name"
      :current-provider="whatsAppAPIProviderName"
      @on-confirm="goToConvert"
      @on-close="closeConvertGate"
    />
    <WhatsappLinkDeviceModal
      v-if="showLinkDeviceModal"
      :show="showLinkDeviceModal"
      :on-close="() => (showLinkDeviceModal = false)"
      :inbox="inbox"
    />
  </div>
</template>
