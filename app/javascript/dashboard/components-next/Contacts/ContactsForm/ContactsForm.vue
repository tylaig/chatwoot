<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { splitName } from '@chatwoot/utils';
import countries from 'shared/constants/countries.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import CompanySelector from 'dashboard/components-next/Companies/CompanySelector.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const { currentAccount, isCloudFeatureEnabled } = useAccount();

const FORM_CONFIG = {
  FIRST_NAME: { field: 'firstName', label: 'Primeiro nome', required: true },
  LAST_NAME: { field: 'lastName', label: 'Sobrenome' },
  EMAIL_ADDRESS: { field: 'email', label: 'E-mail' },
  PHONE_NUMBER: { field: 'phoneNumber', label: 'Telefone' },
  CITY: { field: 'additionalAttributes.city', label: 'Cidade' },
  COUNTRY: { field: 'additionalAttributes.countryCode', label: 'País' },
  BIO: { field: 'additionalAttributes.description', label: 'Biografia / Cargo' },
  COMPANY_NAME: {
    field: 'additionalAttributes.companyName',
    label: 'Empresa',
  },
};

const SOCIAL_CONFIG = {
  LINKEDIN: {
    icon: 'i-ri-linkedin-box-fill',
    label: 'LinkedIn',
    badgeClass: 'bg-[#0A66C2]/20 text-[#3897F0] border-[#0A66C2]/40',
  },
  FACEBOOK: {
    icon: 'i-ri-facebook-circle-fill',
    label: 'Facebook',
    badgeClass: 'bg-[#1877F2]/20 text-[#4599FF] border-[#1877F2]/40',
  },
  INSTAGRAM: {
    icon: 'i-ri-instagram-line',
    label: 'Instagram',
    badgeClass: 'bg-[#E1306C]/20 text-[#F472B6] border-[#E1306C]/40',
  },
  WHATSAPP: {
    icon: 'i-ri-whatsapp-line',
    label: 'WhatsApp',
    badgeClass: 'bg-[#10B981]/20 text-[#34D399] border-[#10B981]/40',
  },
  TELEGRAM: {
    icon: 'i-ri-telegram-fill',
    label: 'Telegram',
    badgeClass: 'bg-[#229ED9]/20 text-[#38BDF8] border-[#229ED9]/40',
  },
  TIKTOK: {
    icon: 'i-ri-tiktok-fill',
    label: 'TikTok',
    badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
  },
  TWITTER: {
    icon: 'i-ri-twitter-x-fill',
    label: 'X (Twitter)',
    badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
  },
  GITHUB: {
    icon: 'i-ri-github-fill',
    label: 'Github',
    badgeClass: 'bg-slate-700/40 text-slate-200 border-slate-600/50',
  },
};

const defaultState = {
  id: 0,
  name: '',
  email: '',
  companyId: '',
  firstName: '',
  lastName: '',
  phoneNumber: '',
  additionalAttributes: {
    description: '',
    companyName: '',
    countryCode: '',
    country: '',
    city: '',
    socialProfiles: {
      facebook: '',
      github: '',
      instagram: '',
      telegram: '',
      tiktok: '',
      linkedin: '',
      twitter: '',
      whatsapp: '',
    },
  },
};

const state = reactive({ ...defaultState });

const validationRules = {
  firstName: { required },
  email: { email },
};

const v$ = useVuelidate(validationRules, state);

const isFormInvalid = computed(() => v$.value.$invalid);
const normalizeWhatsAppUsername = value => value?.toString().replace(/^@+/, '');
const hasCompaniesFeature = computed(
  () =>
    currentAccount.value?.id && isCloudFeatureEnabled(FEATURE_FLAGS.COMPANIES)
);
const showCompanySelector = computed(
  () =>
    hasCompaniesFeature.value &&
    (Boolean(state.companyId) || !state.additionalAttributes.companyName)
);

const emitContactUpdate = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  const { firstName, lastName, ...stateWithoutNames } = state;
  emit('update', stateWithoutNames);
};

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) {
    return; // Added to prevent state update for new contact form
  }

  const {
    id,
    name = '',
    email: emailAddress,
    phoneNumber,
    companyId = '',
    additionalAttributes = {},
  } = props.contactData || {};
  const { firstName, lastName } = splitName(name || '');
  const {
    description = '',
    companyName = '',
    countryCode = '',
    country = '',
    city = '',
    socialTelegramUserName = '',
    socialWhatsappUserName = '',
    socialProfiles = {},
  } = additionalAttributes || {};

  const telegramUsername =
    socialProfiles?.telegram || socialTelegramUserName || '';
  const whatsappUsername = normalizeWhatsAppUsername(
    socialProfiles?.whatsapp || socialWhatsappUserName || ''
  );

  Object.assign(state, {
    id,
    name,
    companyId: companyId || '',
    firstName,
    lastName,
    email: emailAddress,
    phoneNumber,
    additionalAttributes: {
      description,
      companyName,
      countryCode,
      country,
      city,
      socialProfiles: {
        ...socialProfiles,
        telegram: telegramUsername,
        whatsapp: whatsappUsername,
      },
    },
  });
};

const countryOptions = computed(() =>
  countries.map(({ name, id }) => ({ label: name, value: id }))
);

const editDetailsForm = computed(() =>
  Object.entries(FORM_CONFIG).map(([key, config]) => ({
    key,
    label: config.label,
    required: Boolean(config.required),
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const socialProfilesForm = computed(() =>
  Object.entries(SOCIAL_CONFIG).map(([key, meta]) => ({
    key,
    label: meta.label,
    icon: meta.icon,
    badgeClass: meta.badgeClass,
    placeholder: t(`CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.FORM.${key}.PLACEHOLDER`),
  }))
);

const isValidationField = key => {
  const field = FORM_CONFIG[key]?.field;
  return ['firstName', 'email'].includes(field);
};

const getValidationKey = key => {
  return FORM_CONFIG[key]?.field;
};

// Creates a computed property for two-way form field binding
const getFormBinding = key => {
  const field = FORM_CONFIG[key]?.field;
  if (!field) return null;

  return computed({
    get: () => {
      // Handle firstName/lastName fields
      if (field === 'firstName' || field === 'lastName') {
        return state[field]?.toString() || '';
      }

      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      // Example: 'email' → state.email
      // Example: 'additionalAttributes.city' → state.additionalAttributes.city
      return (nested ? state[base][nested] : state[base])?.toString() || '';
    },

    set: async value => {
      // Handle name fields specially to maintain the combined 'name' field
      if (field === 'firstName' || field === 'lastName') {
        state[field] = value;
        // Example: firstName="John", lastName="Doe" → name="John Doe"
        state.name = `${state.firstName} ${state.lastName}`.trim();
      } else {
        // Handle nested vs non-nested fields
        const [base, nested] = field.split('.');
        if (nested) {
          // Example: additionalAttributes.city = "New York"
          state[base][nested] = value;
        } else {
          // Example: email = "test@example.com"
          state[base] = value;
        }
      }

      await emitContactUpdate();
    },
  });
};

const getMessageType = key => {
  return isValidationField(key) && v$.value[getValidationKey(key)]?.$error
    ? 'error'
    : 'info';
};

const handleCountrySelection = value => {
  const selectedCountry = countries.find(option => option.id === value);
  state.additionalAttributes.country = selectedCountry?.name || '';
  emit('update', state);
};

const handleCompanySelection = async ({ id, name }) => {
  state.companyId = id || '';
  state.additionalAttributes.companyName = name || '';
  await emitContactUpdate();
};

const handleSocialProfileInput = item => {
  const key = item.key.toLowerCase();
  if (key === 'whatsapp') {
    state.additionalAttributes.socialProfiles[key] = normalizeWhatsAppUsername(
      state.additionalAttributes.socialProfiles[key]
    );
  }
  emit('update', state);
};

const resetValidation = () => {
  v$.value.$reset();
};

const resetForm = () => {
  Object.assign(state, defaultState);
};

watch(
  () => props.contactData?.id,
  id => {
    if (id) prepareStateBasedOnProps();
  },
  { immediate: true }
);

// Expose state to parent component for avatar upload
defineExpose({
  state,
  resetValidation,
  isFormInvalid,
  resetForm,
});
</script>

<template>
  <div class="flex flex-col gap-6 w-full">
    <div class="flex flex-col items-start gap-4 w-full">
      <div class="flex flex-col gap-0.5">
        <div class="flex items-center gap-2">
          <span class="i-lucide-user-cog size-4 text-[#10B981]" />
          <span class="text-base font-semibold text-white">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE') }}
          </span>
        </div>
        <p class="text-xs text-slate-400 pl-6 mb-0">
          Atualize as informações básicas e comerciais do contato.
        </p>
      </div>
      <div class="grid w-full grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
        <div
          v-for="item in editDetailsForm"
          :key="item.key"
          class="flex flex-col gap-1.5 min-w-0"
        >
          <label class="text-[13px] font-medium text-slate-300">
            {{ item.label }}
            <span v-if="item.required" class="text-red-500">*</span>
          </label>
          <ComboBox
            v-if="item.key === 'COUNTRY'"
            v-model="state.additionalAttributes.countryCode"
            :options="countryOptions"
            :placeholder="item.placeholder"
            class="[&>div>button]:!h-10 [&>div>button]:!bg-[#050C10] [&>div>button]:!outline-[#1A303D] [&>div>button:hover]:!outline-[#10B981]/50"
            @update:model-value="handleCountrySelection"
          />
          <PhoneNumberInput
            v-else-if="item.key === 'PHONE_NUMBER'"
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            show-border
          />
          <CompanySelector
            v-else-if="item.key === 'COMPANY_NAME' && showCompanySelector"
            :model-value="state.companyId"
            :selected-name="state.additionalAttributes.companyName"
            :is-details-view="isDetailsView"
            @select="handleCompanySelection"
          />
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :message-type="getMessageType(item.key)"
            custom-input-class="!h-10 !pt-1 !pb-1 !bg-[#050C10] !outline-[#1A303D] focus:!outline-[#10B981] !text-white"
            class="w-full"
            @input="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
            @blur="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
          />
        </div>
      </div>
    </div>

    <hr class="border-[#132631] w-full my-0" />

    <div class="flex flex-col items-start gap-4 w-full">
      <div class="flex flex-col gap-0.5">
        <div class="flex items-center gap-2">
          <span class="i-lucide-share-2 size-4 text-[#10B981]" />
          <span class="text-base font-semibold text-white">
            {{ t('CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.TITLE') }}
          </span>
        </div>
        <p class="text-xs text-slate-400 pl-6 mb-0">
          Adicione ou atualize os perfis de redes sociais do contato.
        </p>
      </div>
      <div class="grid w-full grid-cols-1 gap-x-6 gap-y-3 xl:grid-cols-2">
        <div
          v-for="item in socialProfilesForm"
          :key="item.key"
          class="flex items-center gap-2.5 min-w-0"
        >
          <div class="w-[112px] flex items-center gap-2 shrink-0">
            <span
              class="w-7 h-7 rounded-md border flex items-center justify-center shrink-0"
              :class="item.badgeClass"
            >
              <Icon :icon="item.icon" class="size-4" />
            </span>
            <span class="text-[13px] font-medium text-slate-200 truncate">
              {{ item.label }}
            </span>
          </div>
          <input
            v-model="
              state.additionalAttributes.socialProfiles[item.key.toLowerCase()]
            "
            class="flex-1 min-w-0 h-10 px-3 text-sm rounded-lg bg-[#050C10] border border-[#1A303D] focus:border-[#10B981] outline-none reset-base text-white placeholder:text-slate-500 transition-colors"
            :placeholder="item.placeholder"
            @input="handleSocialProfileInput(item)"
          />
        </div>
      </div>
    </div>
  </div>
</template>
