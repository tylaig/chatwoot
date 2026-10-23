<script>
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import countries from 'shared/constants/countries.js';
import { isPhoneNumberValid } from 'shared/helpers/Validators';
import parsePhoneNumber from 'libphonenumber-js';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

export default {
  components: {
    NextButton,
    Avatar,
    ComboBox,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    inProgress: {
      type: Boolean,
      default: false,
    },
    onSubmit: {
      type: Function,
      default: () => {},
    },
  },
  emits: ['cancel', 'success'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      countries: countries,
      companyName: '',
      description: '',
      email: '',
      name: '',
      phoneNumber: '',
      activeDialCode: '',
      avatarFile: null,
      avatarUrl: '',
      country: {
        id: '',
        name: '',
      },
      city: '',
      socialProfileUserNames: {
        facebook: '',
        twitter: '',
        linkedin: '',
        github: '',
        telegram: '',
      },
      socialProfileKeys: [
        {
          key: 'facebook',
          prefixURL: 'https://facebook.com/',
          icon: 'i-ri-facebook-circle-fill',
          badgeClass: 'bg-[#1877F2]/20 text-[#4599FF] border-[#1877F2]/40',
        },
        {
          key: 'linkedin',
          prefixURL: 'https://linkedin.com/',
          icon: 'i-ri-linkedin-box-fill',
          badgeClass: 'bg-[#0A66C2]/20 text-[#3897F0] border-[#0A66C2]/40',
        },
        {
          key: 'twitter',
          prefixURL: 'https://twitter.com/',
          icon: 'i-ri-twitter-x-fill',
          badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
        },
        {
          key: 'github',
          prefixURL: 'https://github.com/',
          icon: 'i-ri-github-fill',
          badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
        },
        {
          key: 'telegram',
          prefixURL: 'https://t.me/',
          icon: 'i-ri-telegram-fill',
          badgeClass: 'bg-[#229ED9]/20 text-[#38BDF8] border-[#229ED9]/40',
        },
        {
          key: 'whatsapp',
          prefixURL: 'wa.me/',
          icon: 'i-ri-whatsapp-line',
          badgeClass: 'bg-[#10B981]/20 text-[#34D399] border-[#10B981]/40',
        },
        {
          key: 'tiktok',
          prefixURL: 'https://tiktok.com/@',
          icon: 'i-ri-tiktok-fill',
          badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
        },
      ],
      initialData: null,
    };
  },
  validations: {
    name: {
      required,
    },
    description: {},
    email: {
      email,
    },
    companyName: {},
    phoneNumber: {},
    bio: {},
  },
  computed: {
    parsePhoneNumber() {
      return parsePhoneNumber(this.phoneNumber);
    },
    isPhoneNumberNotValid() {
      if (this.phoneNumber !== '') {
        return (
          !isPhoneNumberValid(this.phoneNumber, this.activeDialCode) ||
          (this.phoneNumber !== '' ? this.activeDialCode === '' : false)
        );
      }
      return false;
    },
    phoneNumberError() {
      if (this.activeDialCode === '') {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DIAL_CODE_ERROR');
      }
      if (!isPhoneNumberValid(this.phoneNumber, this.activeDialCode)) {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.ERROR');
      }
      return '';
    },
    hasUnsavedChanges() {
      if (!this.initialData) return false;
      const socialProfilesChanged = this.socialProfileKeys.some(
        ({ key }) =>
          (this.socialProfileUserNames[key] || '') !==
          (this.initialData.socialProfileUserNames[key] || '')
      );
      return (
        this.name !== this.initialData.name ||
        this.email !== this.initialData.email ||
        this.phoneNumber !== this.initialData.phoneNumber ||
        this.companyName !== this.initialData.companyName ||
        this.description !== this.initialData.description ||
        this.city !== this.initialData.city ||
        (this.country?.id || '') !== (this.initialData.countryId || '') ||
        this.avatarFile !== null ||
        socialProfilesChanged
      );
    },
    setPhoneNumber() {
      if (this.parsePhoneNumber?.countryCallingCode) {
        return this.phoneNumber;
      }
      if (this.phoneNumber === '' && this.activeDialCode !== '') {
        return '';
      }
      return this.activeDialCode
        ? `${this.activeDialCode}${this.phoneNumber}`
        : '';
    },
  },
  watch: {
    contact() {
      this.setContactObject();
    },
  },
  mounted() {
    this.setContactObject();
    this.setDialCode();
  },
  methods: {
    normalizeWhatsAppUsername(value) {
      return value?.toString().replace(/^@+/, '') || '';
    },
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('success');
    },
    countryNameWithCode({ name, id }) {
      if (!id) return name;
      if (!name && !id) return '';
      return `${name} (${id})`;
    },
    onCountryChange(value) {
      const selected = this.countries.find(c => c.id === value);
      this.country = selected
        ? { id: selected.id, name: selected.name }
        : { id: '', name: '' };
    },
    setDialCode() {
      if (
        this.phoneNumber !== '' &&
        this.parsePhoneNumber &&
        this.parsePhoneNumber.countryCallingCode
      ) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        this.activeDialCode = `+${dialCode}`;
      }
    },
    setContactObject() {
      const {
        email: emailAddress,
        phone_number: phoneNumber,
        name,
      } = this.contact;
      const additionalAttributes = this.contact.additional_attributes || {};

      this.name = name || '';
      this.email = emailAddress || '';
      this.phoneNumber = phoneNumber || '';
      this.companyName = additionalAttributes.company_name || '';
      this.country = {
        id: additionalAttributes.country_code || '',
        name:
          additionalAttributes.country ||
          this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY'),
      };
      this.city = additionalAttributes.city || '';
      this.description = additionalAttributes.description || '';
      this.avatarUrl = this.contact.thumbnail || '';
      const {
        social_profiles: socialProfiles = {},
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUserName,
        social_whatsapp_user_name: whatsappUserName,
      } = additionalAttributes;
      this.socialProfileUserNames = {
        ...socialProfiles,
        twitter: socialProfiles.twitter || twitterScreenName || '',
        facebook: socialProfiles.facebook || '',
        linkedin: socialProfiles.linkedin || '',
        github: socialProfiles.github || '',
        telegram: socialProfiles.telegram || telegramUserName || '',
        instagram: socialProfiles.instagram || '',
        tiktok: socialProfiles.tiktok || '',
        whatsapp: this.normalizeWhatsAppUsername(
          socialProfiles.whatsapp || whatsappUserName || ''
        ),
      };
      this.initialData = {
        name: this.name,
        email: this.email,
        phoneNumber: this.phoneNumber,
        companyName: this.companyName,
        description: this.description,
        city: this.city,
        countryId: this.country.id,
        socialProfileUserNames: { ...this.socialProfileUserNames },
      };
    },
    getContactObject() {
      if (this.country === null) {
        this.country = {
          id: '',
          name: '',
        };
      }
      const socialProfileUserNames = {
        ...this.socialProfileUserNames,
        whatsapp: this.normalizeWhatsAppUsername(
          this.socialProfileUserNames.whatsapp
        ),
      };
      const contactObject = {
        id: this.contact.id,
        name: this.name,
        email: this.email,
        phone_number: this.setPhoneNumber,
        additional_attributes: {
          ...this.contact.additional_attributes,
          description: this.description,
          company_name: this.companyName,
          country_code: this.country.id,
          country:
            this.country.name ===
            this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY')
              ? ''
              : this.country.name,
          city: this.city,
          social_profiles: socialProfileUserNames,
        },
      };
      if (this.avatarFile) {
        contactObject.avatar = this.avatarFile;
        contactObject.isFormData = true;
      }
      return contactObject;
    },
    setPhoneCode(code) {
      if (this.phoneNumber !== '' && this.parsePhoneNumber) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        if (dialCode === code) {
          return;
        }
        this.activeDialCode = `+${dialCode}`;
        const newPhoneNumber = this.phoneNumber.replace(
          `+${dialCode}`,
          `${code}`
        );
        this.phoneNumber = newPhoneNumber;
      } else {
        this.activeDialCode = code;
      }
    },
    async handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid || this.isPhoneNumberNotValid) {
        return;
      }
      try {
        await this.onSubmit(this.getContactObject());
        this.onSuccess();
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));
      } catch (error) {
        if (error instanceof DuplicateContactException) {
          if (error.data.includes('email')) {
            useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
          } else if (error.data.includes('phone_number')) {
            useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
          }
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    triggerAvatarInput() {
      this.$refs.drawerAvatarInput?.click();
    },
    onNativeAvatarSelect(event) {
      const [file] = event.target?.files || [];
      if (file) {
        this.handleImageUpload({
          file,
          url: URL.createObjectURL(file),
        });
      }
    },
    async handleAvatarDelete() {
      try {
        if (this.contact?.id) {
          await this.$store.dispatch('contacts/deleteAvatar', this.contact.id);
          useAlert(this.$t('CONTACT_FORM.DELETE_AVATAR.API.SUCCESS_MESSAGE'));
        }
        this.avatarFile = null;
        this.avatarUrl = '';
        this.activeDialCode = '';
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('CONTACT_FORM.DELETE_AVATAR.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form
    class="flex flex-col h-full min-h-0 w-full contact--form"
    @submit.prevent="handleSubmit"
  >
    <div class="flex-1 min-h-0 overflow-y-auto px-6 py-4 space-y-4">
      <!-- ISS-03: Avatar do Contato -->
      <div class="flex flex-col gap-2 w-full">
        <label class="text-[13px] font-semibold text-slate-200 mb-0">
          {{ $t('CONTACT_FORM.FORM.AVATAR.LABEL') }}
        </label>
        <div class="flex items-center gap-3.5">
          <div class="relative shrink-0">
            <Avatar
              :src="avatarUrl"
              :size="58"
              :name="contact.name || name"
              allow-upload
              rounded-full
              class="ring-2 ring-[#10B981] shadow-[0_0_18px_rgba(16,185,129,0.3)]"
              @upload="handleImageUpload"
              @delete="handleAvatarDelete"
            />
            <input
              ref="drawerAvatarInput"
              type="file"
              accept="image/png, image/jpeg, image/jpg, image/gif, image/webp"
              class="hidden"
              @change="onNativeAvatarSelect"
            />
          </div>
          <div class="flex items-center flex-wrap gap-2">
            <button
              type="button"
              class="h-9 px-3 rounded-lg bg-[#0D1821] border border-[#1A303D] hover:border-[#10B981]/50 text-xs font-medium text-slate-200 flex items-center gap-2 transition-colors cursor-pointer"
              @click="triggerAvatarInput"
            >
              <span class="i-lucide-image size-4 text-[#10B981]" />
              <span>Alterar imagem</span>
            </button>
            <button
              type="button"
              class="h-9 px-3 rounded-lg bg-red-950/25 border border-red-500/30 hover:bg-red-950/45 text-xs font-medium text-red-400 flex items-center gap-1.5 transition-colors cursor-pointer"
              @click="handleAvatarDelete"
            >
              <span class="i-lucide-trash-2 size-3.5 text-red-400" />
              <span>Remover</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Nome Completo -->
      <div class="w-full">
        <label
          class="block text-[13px] font-semibold text-slate-200 mb-1.5"
          :class="{ 'text-red-400': v$.name.$error }"
        >
          {{ $t('CONTACT_FORM.FORM.NAME.LABEL') }}
          <input
            v-model="name"
            type="text"
            class="!h-10 !mb-0 !mt-1.5 !px-3.5 !bg-[#0D1821] !border !border-[#1A303D] focus:!border-[#10B981] !rounded-lg !text-sm !text-white !outline-none transition-colors"
            :placeholder="$t('CONTACT_FORM.FORM.NAME.PLACEHOLDER')"
            @input="v$.name.$touch"
          />
        </label>
      </div>

      <!-- Endereço de e-mail -->
      <div class="w-full">
        <label
          class="block text-[13px] font-semibold text-slate-200 mb-1.5"
          :class="{ 'text-red-400': v$.email.$error }"
        >
          {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.LABEL') }}
          <input
            v-model="email"
            type="text"
            class="!h-10 !mb-0 !mt-1.5 !px-3.5 !bg-[#0D1821] !border !border-[#1A303D] focus:!border-[#10B981] !rounded-lg !text-sm !text-white !outline-none transition-colors"
            :placeholder="$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.PLACEHOLDER')"
            @input="v$.email.$touch"
          />
          <span v-if="v$.email.$error" class="message text-xs text-red-400 mt-1 block">
            {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.ERROR') }}
          </span>
        </label>
      </div>

      <!-- Descrição com contador -->
      <div class="w-full">
        <label
          class="block text-[13px] font-semibold text-slate-200 mb-1.5"
          :class="{ 'text-red-400': v$.description.$error }"
        >
          {{ $t('CONTACT_FORM.FORM.BIO.LABEL') }}
          <textarea
            v-model="description"
            rows="2"
            maxlength="500"
            class="!mb-0 !mt-1.5 !p-3 !bg-[#0D1821] !border !border-[#1A303D] focus:!border-[#10B981] !rounded-lg !text-sm !text-white !outline-none transition-colors resize-y"
            :placeholder="$t('CONTACT_FORM.FORM.BIO.PLACEHOLDER')"
            @input="v$.description.$touch"
          />
        </label>
        <div class="text-right text-[11px] text-slate-500 mt-1">
          {{ (description || '').length }}/500
        </div>
      </div>

      <!-- ISS-01: Número de Telefone Unificado -->
      <div class="w-full">
        <label
          class="block text-[13px] font-semibold text-slate-200 mb-1.5"
          :class="{
            'text-red-400': isPhoneNumberNotValid,
          }"
        >
          {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.LABEL') }}
          <div class="mt-1.5">
            <woot-phone-input
              v-model="phoneNumber"
              :value="phoneNumber"
              :error="isPhoneNumberNotValid"
              :placeholder="$t('CONTACT_FORM.FORM.PHONE_NUMBER.PLACEHOLDER')"
              @blur="v$.phoneNumber.$touch"
              @set-code="setPhoneCode"
            />
          </div>
          <span v-if="isPhoneNumberNotValid" class="message text-xs text-red-400 mt-1 block">
            {{ phoneNumberError }}
          </span>
        </label>
        <div
          v-if="isPhoneNumberNotValid || !phoneNumber"
          class="relative mx-0 mt-1 mb-1 p-2.5 rounded-lg text-xs border border-amber-500/30 text-amber-200 bg-amber-950/30"
        >
          {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.HELP') }}
        </div>
      </div>

      <!-- Nome da empresa -->
      <div class="w-full">
        <label class="block text-[13px] font-semibold text-slate-200 mb-1.5">
          {{ $t('CONTACT_FORM.FORM.COMPANY_NAME.LABEL') }}
          <input
            v-model="companyName"
            type="text"
            class="!h-10 !mb-0 !mt-1.5 !px-3.5 !bg-[#0D1821] !border !border-[#1A303D] focus:!border-[#10B981] !rounded-lg !text-sm !text-white !outline-none transition-colors"
            :placeholder="$t('CONTACT_FORM.FORM.COMPANY_NAME.PLACEHOLDER')"
          />
        </label>
      </div>

      <!-- ISS-04: Grid 2 Colunas para País e Cidade -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 w-full">
        <div class="min-w-0">
          <label class="block text-[13px] font-semibold text-slate-200 mb-1.5">
            {{ $t('CONTACT_FORM.FORM.COUNTRY.LABEL') }}
          </label>
          <ComboBox
            :model-value="country.id"
            :options="
              countries.map(c => ({
                value: c.id,
                label: countryNameWithCode(c),
              }))
            "
            class="[&>div>button]:!h-10 [&>div>button]:!bg-[#0D1821] [&>div>button]:!outline-[#1A303D] [&>div>button:hover]:!outline-[#10B981]/50"
            :placeholder="$t('CONTACT_FORM.FORM.COUNTRY.PLACEHOLDER')"
            :search-placeholder="$t('CONTACT_FORM.FORM.COUNTRY.SELECT_PLACEHOLDER')"
            @update:model-value="onCountryChange"
          />
        </div>
        <div class="min-w-0">
          <label class="block text-[13px] font-semibold text-slate-200 mb-1.5">
            {{ $t('CONTACT_FORM.FORM.CITY.LABEL') }}
          </label>
          <input
            v-model="city"
            type="text"
            class="!h-10 !mb-0 !px-3.5 !bg-[#0D1821] !border !border-[#1A303D] focus:!border-[#10B981] !rounded-lg !text-sm !text-white !outline-none transition-colors w-full"
            :placeholder="$t('CONTACT_FORM.FORM.CITY.PLACEHOLDER')"
          />
        </div>
      </div>

      <!-- ISS-05: Perfis Sociais Unificados -->
      <div class="w-full space-y-2.5 pt-1">
        <label class="block text-[13px] font-semibold text-slate-200 mb-1">
          {{ $t('CONTACTS_PAGE.LIST.TABLE_HEADER.SOCIAL_PROFILES') }}
        </label>
        <div
          v-for="socialProfile in socialProfileKeys"
          :key="socialProfile.key"
          class="flex items-center h-10 w-full rounded-lg bg-[#0D1821] border border-[#1A303D] focus-within:border-[#10B981] overflow-hidden transition-colors"
        >
          <span
            class="flex items-center gap-2 h-full px-3 text-xs bg-[#09131A] border-r border-[#1A303D] text-slate-300 shrink-0 select-none"
          >
            <span
              class="w-5 h-5 rounded border flex items-center justify-center shrink-0"
              :class="socialProfile.badgeClass"
            >
              <span :class="[socialProfile.icon, 'size-3.5']" />
            </span>
            <span class="text-slate-400">{{ socialProfile.prefixURL }}</span>
          </span>
          <input
            v-model="socialProfileUserNames[socialProfile.key]"
            class="!h-full !w-full !px-3 !bg-transparent !border-0 !outline-none !mb-0 !text-sm !text-white placeholder:text-slate-500"
            type="text"
            placeholder="usuario"
          />
        </div>
      </div>
    </div>

    <!-- ISS-02: Sticky Footer com CTAs -->
    <div
      class="shrink-0 px-6 py-4 bg-[#060D12]/95 backdrop-blur-md border-t border-[#162936] grid grid-cols-2 gap-3"
    >
      <NextButton
        faded
        slate
        type="reset"
        class="!h-10 !w-full justify-center !bg-[#0D1821] !border !border-[#1A303D] !text-slate-200 hover:!bg-[#13222E]"
        :label="$t('CONTACT_FORM.FORM.CANCEL')"
        @click.prevent="onCancel"
      />
      <NextButton
        type="submit"
        class="!h-10 !w-full justify-center !bg-[#10B981] hover:!bg-[#059669] !text-[#031911] font-semibold shadow-[0_0_15px_rgba(16,185,129,0.25)]"
        :label="$t('CONTACT_FORM.FORM.SUBMIT')"
        :is-loading="inProgress"
      />
    </div>
  </form>
</template>
