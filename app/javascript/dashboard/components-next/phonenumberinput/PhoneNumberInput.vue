<script setup>
import { ref, computed, watch } from 'vue';
import parsePhoneNumber from 'libphonenumber-js';
import { useI18n } from 'vue-i18n';
import countries from 'shared/constants/countries.js';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, numeric } from '@vuelidate/validators';
import {
  getActiveCountryCode,
  getActiveDialCode,
} from 'shared/components/PhoneInput/helper';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Flag from 'dashboard/components-next/flag/Flag.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  placeholder: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  showBorder: {
    type: Boolean,
    default: true,
  },
});

const modelValue = defineModel({
  type: [String, Number],
  default: '',
});

const { t } = useI18n();

const showDropdown = ref(false);
const searchQuery = ref('');
const activeCountryCode = ref(getActiveCountryCode());
const activeDialCode = ref(getActiveDialCode());
const phoneNumber = ref('');

const rules = {
  phoneNumber: {
    minLength: minLength(2),
    numeric,
  },
  activeDialCode: {
    required,
    validDialCode: value => {
      return countries.some(country => country.dial_code === value);
    },
  },
};

const v$ = useVuelidate(rules, {
  phoneNumber,
  activeDialCode,
});

const hasError = computed(() => v$.value.$invalid);

const countryList = computed(() => {
  return countries.map(country => ({
    value: country.id,
    label: country.name,
    dialCode: country.dial_code,
    emoji: country.emoji,
    isSelected: String(activeCountryCode.value) === String(country.id),
    action: 'phoneNumberInput',
  }));
});

const filteredCountries = computed(() => {
  const query = searchQuery.value.toLowerCase();
  return countryList.value.filter(({ label, dialCode, value }) =>
    [label, dialCode, value].some(field => field.toLowerCase().includes(query))
  );
});

const activeCountry = computed(() =>
  activeCountryCode.value
    ? countryList.value.find(
        country => country.value === activeCountryCode.value
      )
    : ''
);

const inputBorderClass = computed(() => {
  const errorClass =
    'outline-n-ruby-8 dark:outline-n-ruby-8 hover:outline-n-ruby-9 dark:hover:outline-n-ruby-9 disabled:outline-n-ruby-8 dark:disabled:outline-n-ruby-8';
  const focusClass =
    'has-[:focus]:outline-[#10B981] dark:has-[:focus]:outline-[#10B981]';

  if (!props.showBorder) {
    if (hasError.value) return errorClass;
    return `outline-transparent ${focusClass}`;
  }

  if (hasError.value) {
    return errorClass;
  }
  return `${focusClass} outline-[#1A303D] dark:outline-[#1A303D] hover:outline-[#10B981]/50 dark:hover:outline-[#10B981]/50 disabled:outline-[#1A303D] dark:disabled:outline-[#1A303D]`;
});

const phoneNumberError = computed(() => {
  if (!v$.value.$dirty) return '';
  return v$.value.activeDialCode.$invalid
    ? t('PHONE_INPUT.DIAL_CODE_ERROR')
    : v$.value.phoneNumber.$invalid && t('PHONE_INPUT.ERROR');
});

const emitPhoneNumber = value => {
  const newValue = value ? `${activeDialCode.value}${value}` : '';
  modelValue.value = newValue;
};

const onSelectCountry = async ({ value, dialCode }) => {
  if (!value || !showDropdown.value) return;

  activeCountryCode.value = value;
  activeDialCode.value = dialCode;
  searchQuery.value = '';
  showDropdown.value = false;
  if (!v$.value.$invalid && phoneNumber.value) {
    emitPhoneNumber(phoneNumber.value);
  }
};

const toggleCountryDropdown = () => {
  showDropdown.value = !showDropdown.value;
};

const closeCountryDropdown = () => {
  showDropdown.value = false;
};

watch(phoneNumber, async value => {
  await v$.value.$touch();
  if (!v$.value.$invalid) {
    emitPhoneNumber(value);
  }
});

watch(
  modelValue,
  newValue => {
    const number = parsePhoneNumber(newValue);
    if (number) {
      if (number?.country) activeCountryCode.value = number.country;
      if (number?.countryCallingCode)
        activeDialCode.value = `+${number.countryCallingCode}`;
      phoneNumber.value = newValue.replace(`+${number.countryCallingCode}`, '');
    }
  },
  { immediate: true }
);
</script>

<template>
  <div>
    <div
      v-on-clickaway="() => closeCountryDropdown()"
      class="relative flex items-center h-10 transition-all duration-300 ease-in-out outline outline-1 outline-offset-[-1px] rounded-lg bg-[#050C10]"
      :class="[inputBorderClass, { 'cursor-not-allowed opacity-50': disabled }]"
    >
      <Input
        v-model="phoneNumber"
        type="tel"
        :placeholder="placeholder"
        :disabled="disabled"
        custom-input-class="!border-0 !outline-none !h-10 !py-0.5 !bg-transparent !text-white ltr:!pl-2.5 rtl:!pr-2.5"
        class="w-full !flex-row items-center"
      >
        <template #prefix>
          <div
            class="flex items-center flex-shrink-0 h-10 px-2.5 bg-[#09151C] border-r border-[#1A303D] rounded-l-lg"
          >
            <Button
              color="slate"
              size="sm"
              :icon="
                !activeCountry ? 'i-lucide-globe' : 'i-lucide-chevron-down'
              "
              trailing-icon
              :disabled="disabled"
              type="button"
              class="!h-7 !px-1.5 !bg-transparent outline-0 !outline-none !rounded-md border-0"
              @click="toggleCountryDropdown"
            >
              <Flag
                v-if="activeCountry?.value"
                :country="activeCountry.value"
                class="size-4 rounded-[2px]"
              />
            </Button>
            <span
              v-if="activeCountry"
              class="text-sm font-medium text-slate-200 ltr:pl-1 rtl:pr-1"
            >
              {{ activeDialCode }}
            </span>
          </div>
        </template>
      </Input>
      <DropdownMenu
        v-if="showDropdown"
        :menu-items="filteredCountries"
        show-search
        class="z-[100] w-56 mt-2 ltr:left-0 rtl:right-0 top-full max-h-52"
        @action="onSelectCountry"
      />
    </div>
    <template v-if="phoneNumberError">
      <p
        v-if="phoneNumberError"
        class="min-w-0 mt-1 mb-0 text-xs truncate transition-all duration-500 ease-in-out text-n-ruby-9 dark:text-n-ruby-9"
      >
        {{ phoneNumberError }}
      </p>
    </template>
  </div>
</template>
