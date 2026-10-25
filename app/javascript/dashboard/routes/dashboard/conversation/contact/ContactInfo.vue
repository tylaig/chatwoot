<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import ViewAllConversations from './ViewAllConversations.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ContactDeleteModal from 'dashboard/modules/contact/ContactDeleteModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';
import AgentsConversationButton from './AgentsConversationButton.vue';
import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';

export default {
  components: {
    NextButton,
    ContactInfoRow,
    ViewAllConversations,
    EditContact,
    Avatar,
    ComposeConversation,
    SocialIcons,
    ContactMergeModal,
    ContactDeleteModal,
    VoiceCallButton,
    InlineInput,
    AgentsConversationButton,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    showAvatar: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['panelClose'],
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
      exactTimestamp: useExactTimestamp(),
    };
  },
  data() {
    return {
      showEditModal: false,
      isEditingName: false,
      editName: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      currentChat: 'getSelectedChat',
    }),
    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    location() {
      const {
        country = '',
        city = '',
        country_code: countryCode,
      } = this.additionalAttributes;
      const cityAndCountry = [city, country].filter(item => !!item).join(', ');

      if (!cityAndCountry) {
        return '';
      }
      return this.findCountryFlag(countryCode, cityAndCountry);
    },
    socialProfiles() {
      const {
        social_profiles: socialProfiles,
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUsername,
      } = this.additionalAttributes;

      const telegram = socialProfiles?.telegram || telegramUsername || '';
      const twitter = socialProfiles?.twitter || twitterScreenName || '';

      return {
        ...(socialProfiles || {}),
        twitter,
        telegram,
      };
    },
    whatsappUsername() {
      const username =
        this.socialProfiles.whatsapp ||
        this.additionalAttributes.social_whatsapp_user_name ||
        '';

      return username.toString().replace(/^@+/, '');
    },
    formattedWhatsappUsername() {
      return this.whatsappUsername ? `@${this.whatsappUsername}` : '';
    },
  },
  watch: {
    'contact.id': {
      handler(id) {
        this.$store.dispatch('contacts/fetchContactableInbox', id);
      },
      immediate: true,
    },
  },
  methods: {
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    findCountryFlag(countryCode, cityAndCountry) {
      try {
        if (!countryCode) {
          return `${cityAndCountry} 🌎`;
        }

        const code = countryCode?.toLowerCase();
        return `${cityAndCountry} <span class="fi fi-${code} size-3.5"></span>`;
      } catch (error) {
        return '';
      }
    },
    startEditingName() {
      this.editName = this.contact.name || '';
      this.isEditingName = true;
      this.$nextTick(() => {
        this.$refs.nameInput?.focus();
      });
    },
    saveNameEdit() {
      if (!this.isEditingName) return;
      this.isEditingName = false;
      const trimmed = this.editName.trim();
      if (trimmed && trimmed !== this.contact.name) {
        this.updateContactField({ name: trimmed });
      }
    },
    cancelNameEdit() {
      this.isEditingName = false;
    },
    onFieldUpdate(field, value) {
      this.updateContactField({ [field]: value });
    },
    async updateContactField(attrs) {
      const contactId = this.contact.id;
      try {
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          ...attrs,
        });
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));
        await this.$store.dispatch('contacts/fetchContactableInbox', contactId);
      } catch (error) {
        if (error instanceof DuplicateContactException) {
          const detail = error.contactErrorDetail;
          if (detail) {
            useAlert(detail);
          } else {
            const invalidAttrs = Array.isArray(error.data) ? error.data : [];
            if (invalidAttrs.includes('email')) {
              useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
            } else if (invalidAttrs.includes('phone_number')) {
              useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
            } else {
              useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
            }
          }
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(error.message || this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
    },
  },
};
</script>

<template>
  <div class="relative items-center w-full px-3 pt-3 pb-2">
    <div
      class="msc-contact-hero-card relative overflow-hidden flex flex-col w-full gap-3.5 p-4 rounded-2xl bg-[#0B1317]/90 border border-emerald-500/20 shadow-[0_14px_32px_-8px_rgba(0,0,0,0.65),inset_0_1px_0_rgba(167,243,208,0.16)] text-left rtl:text-right"
    >
      <!-- Top Emerald Specular & Radial Glow -->
      <div
        class="pointer-events-none absolute -top-10 left-1/2 -translate-x-1/2 w-3/4 h-20 bg-emerald-500/15 blur-2xl"
      />
      <div
        class="pointer-events-none absolute top-0 left-[12%] right-[12%] h-px bg-gradient-to-r from-transparent via-emerald-400/50 to-transparent"
      />

      <!-- Header: Glowing Avatar + Name + Company Pill + Top Right Utility Buttons -->
      <div class="relative flex items-start justify-between gap-2.5 w-full">
        <div class="flex items-center gap-3 min-w-0 flex-1">
          <!-- Avatar with Emerald Gradient Ring & Online Dot -->
          <div v-if="showAvatar" class="relative flex-shrink-0">
            <div
              class="p-0.5 rounded-full bg-gradient-to-br from-emerald-400 via-emerald-500 to-teal-700 shadow-[0_0_18px_rgba(16,185,129,0.38)]"
            >
              <div class="rounded-full bg-white dark:bg-[#091318] p-0.5">
                <Avatar
                  :src="contact.thumbnail"
                  :name="contact.name"
                  :status="contact.availability_status"
                  :size="48"
                  hide-offline-status
                  rounded-full
                />
              </div>
            </div>
            <span
              class="absolute bottom-0.5 right-0.5 w-3.5 h-3.5 rounded-full bg-emerald-400 border-2 border-white dark:border-[#0B1317] shadow-[0_0_8px_rgba(16,185,129,0.8)]"
            />
          </div>

          <!-- Name & Company Badge -->
          <div class="flex flex-col items-start gap-1.5 min-w-0 flex-1">
            <div class="group/name flex items-center min-w-0 gap-1.5 w-full">
              <InlineInput
                v-if="isEditingName"
                ref="nameInput"
                v-model="editName"
                custom-input-class="!text-base !font-semibold !w-auto max-w-full [field-sizing:content]"
                class="!w-fit min-w-0"
                @enter-press="saveNameEdit"
                @escape-press="cancelNameEdit"
                @blur="saveNameEdit"
              />
              <h3
                v-else
                class="flex-shrink max-w-full min-w-0 my-0 text-base font-semibold tracking-tight leading-snug break-words text-slate-900 dark:text-slate-50 cursor-pointer hover:text-emerald-600 dark:hover:text-emerald-300 transition-colors"
                :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
                @click="startEditingName"
              >
                {{ contact.name }}
              </h3>
              <NextButton
                ghost
                xs
                slate
                icon="i-lucide-pencil"
                :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
                class="flex-shrink-0 -mx-1 opacity-0 transition-opacity"
                :class="
                  isEditingName
                    ? 'invisible'
                    : 'group-hover/name:opacity-100 focus-visible:opacity-100'
                "
                @click="startEditingName"
              />
            </div>

            <!-- Company Emerald Subtitle Pill -->
            <span
              v-if="additionalAttributes.company_name"
              class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-500/12 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 max-w-full truncate"
              :title="additionalAttributes.company_name"
            >
              <span
                class="i-lucide-building-2 text-xs text-emerald-600 dark:text-emerald-400 flex-shrink-0"
              />
              <span class="truncate">{{
                additionalAttributes.company_name
              }}</span>
            </span>
          </div>
        </div>

        <!-- Top Right Utility Buttons (Info + External Profile Link) -->
        <div class="flex items-center gap-1.5 flex-shrink-0">
          <button
            v-if="contact.created_at"
            v-tooltip.left="
              `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${exactTimestamp(
                contact.created_at
              )}`
            "
            type="button"
            class="w-8 h-8 rounded-lg bg-white/[0.03] border border-white/[0.08] hover:border-emerald-500/35 hover:bg-emerald-500/10 flex items-center justify-center text-slate-300 hover:text-emerald-300 transition-all"
          >
            <span class="i-lucide-info text-sm" />
          </button>
          <a
            :href="contactProfileLink"
            target="_blank"
            rel="noopener nofollow noreferrer"
            class="w-8 h-8 rounded-lg bg-white/[0.03] border border-white/[0.08] hover:border-emerald-500/35 hover:bg-emerald-500/10 flex items-center justify-center text-slate-300 hover:text-emerald-300 transition-all"
          >
            <span class="i-lucide-external-link text-sm" />
          </a>
        </div>
      </div>

      <p
        v-if="additionalAttributes.description"
        class="break-words text-xs text-slate-300 mb-0 px-0.5"
      >
        {{ additionalAttributes.description }}
      </p>

      <!-- Interactive Data Pills (Email, Phone, Company, etc.) -->
      <div class="flex flex-col items-start w-full gap-2">
        <ContactInfoRow
          :href="contact.email ? `mailto:${contact.email}` : ''"
          :value="contact.email"
          icon="mail"
          emoji="✉️"
          :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
          show-copy
          editable
          @update="value => onFieldUpdate('email', value)"
        />
        <ContactInfoRow
          :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
          :value="contact.phone_number"
          icon="call"
          emoji="📞"
          :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
          show-copy
          editable
          @update="value => onFieldUpdate('phone_number', value)"
        />
        <ContactInfoRow
          v-if="formattedWhatsappUsername"
          :value="formattedWhatsappUsername"
          icon="brand-whatsapp"
          emoji="💬"
          :title="$t('CONTACT_PANEL.WHATSAPP_USERNAME')"
          show-copy
        />
        <ContactInfoRow
          v-if="contact.identifier"
          :value="contact.identifier"
          icon="contact-identify"
          emoji="🪪"
          :title="$t('CONTACT_PANEL.IDENTIFIER')"
          show-copy
        />
        <ContactInfoRow
          :value="additionalAttributes.company_name"
          icon="building-bank"
          emoji="🏢"
          :title="$t('CONTACT_PANEL.COMPANY')"
          show-copy
          editable
          @update="
            value =>
              updateContactField({
                additional_attributes: {
                  ...additionalAttributes,
                  company_name: value,
                },
              })
          "
        />
        <ContactInfoRow
          v-if="location || additionalAttributes.location"
          :value="location || additionalAttributes.location"
          icon="map"
          emoji="🌍"
          :title="$t('CONTACT_PANEL.LOCATION')"
        />
        <SocialIcons :social-profiles="socialProfiles" />
      </div>

      <!-- Balanced 4-Column Quick Action Bar matching GPT Image 2.5 -->
      <div class="flex items-center w-full pt-0.5 gap-2">
        <ComposeConversation :contact-id="String(contact.id)">
          <template #trigger>
            <button
              v-tooltip.top-end="$t('CONTACT_PANEL.NEW_MESSAGE')"
              type="button"
              class="flex-1 h-9 px-2.5 rounded-xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-500/25 hover:border-emerald-400 flex items-center justify-center gap-1.5 text-xs font-medium transition-all"
            >
              <span class="i-ph-chat-circle-dots text-sm text-emerald-400" />
              <span>{{ $t('CONTACT_PANEL.NEW_MESSAGE') }}</span>
            </button>
          </template>
        </ComposeConversation>

        <ViewAllConversations :contact="contact" />
        <VoiceCallButton
          :phone="contact.phone_number"
          :contact-id="contact.id"
          :conversation-id="currentChat?.id"
          icon="i-lucide-phone"
          sm
          faded
          slate
          :tooltip-label="$t('CONTACT_PANEL.CALL')"
        />
        <AgentsConversationButton :conversation="currentChat" />

        <button
          v-tooltip.top-end="$t('EDIT_CONTACT.BUTTON_LABEL')"
          type="button"
          class="flex-1 h-9 px-2.5 rounded-xl bg-white/[0.04] border border-white/[0.09] text-slate-200 hover:bg-white/[0.08] hover:border-emerald-500/35 flex items-center justify-center gap-1.5 text-xs font-medium transition-all"
          @click="toggleEditModal"
        >
          <span class="i-ph-pencil-simple text-sm text-slate-300" />
          <span>{{ $t('EDIT_CONTACT.BUTTON_LABEL') }}</span>
        </button>

        <ContactMergeModal :primary-contact="contact">
          <template #trigger>
            <button
              v-tooltip.top-end="$t('CONTACT_PANEL.MERGE_CONTACT')"
              type="button"
              :disabled="uiFlags.isMerging"
              class="flex-1 h-9 px-2.5 rounded-xl bg-white/[0.04] border border-white/[0.09] text-slate-200 hover:bg-white/[0.08] hover:border-emerald-500/35 flex items-center justify-center gap-1.5 text-xs font-medium transition-all disabled:opacity-50"
            >
              <span class="i-ph-arrows-merge text-sm text-slate-300" />
              <span>{{ $t('CONTACT_PANEL.MERGE_CONTACT') }}</span>
            </button>
          </template>
        </ContactMergeModal>

        <ContactDeleteModal
          v-if="isAdmin"
          :contact="contact"
          @deleted="$emit('panelClose')"
        >
          <template #trigger>
            <button
              v-tooltip.top-end="$t('DELETE_CONTACT.BUTTON_LABEL')"
              type="button"
              :disabled="uiFlags.isDeleting"
              class="w-10 h-9 rounded-xl bg-red-500/12 border border-red-500/35 text-red-400 hover:bg-red-500/22 hover:border-red-400 flex items-center justify-center flex-shrink-0 transition-all disabled:opacity-50"
            >
              <span class="i-ph-trash text-sm" />
            </button>
          </template>
        </ContactDeleteModal>
      </div>

      <EditContact
        :show="showEditModal"
        :contact="contact"
        @cancel="toggleEditModal"
      />
    </div>
  </div>
</template>
