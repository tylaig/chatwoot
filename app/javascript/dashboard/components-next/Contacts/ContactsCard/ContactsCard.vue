<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Flag from 'dashboard/components-next/flag/Flag.vue';
import ContactDeleteSection from 'dashboard/components-next/Contacts/ContactsCard/ContactDeleteSection.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import countries from 'shared/constants/countries';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  email: { type: String, default: '' },
  companyId: { type: [Number, String], default: '' },
  additionalAttributes: { type: Object, default: () => ({}) },
  phoneNumber: { type: String, default: '' },
  thumbnail: { type: String, default: '' },
  availabilityStatus: { type: String, default: null },
  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits([
  'toggle',
  'updateContact',
  'showContact',
  'select',
  'avatarHover',
]);

const { t } = useI18n();

const contactsFormRef = ref(null);

const getInitialContactData = () => ({
  id: props.id,
  name: props.name,
  email: props.email,
  companyId: props.companyId,
  phoneNumber: props.phoneNumber,
  additionalAttributes: props.additionalAttributes,
});

const contactData = ref(getInitialContactData());

const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const countriesMap = computed(() => {
  return countries.reduce((acc, country) => {
    acc[country.id] = country;
    return acc;
  }, {});
});

const countryDetails = computed(() => {
  const attributes = props.additionalAttributes || {};
  const { country, countryCode, city } = attributes;

  if (!country && !countryCode) return null;

  const activeCountry =
    countriesMap.value[country] || countriesMap.value[countryCode];

  if (!activeCountry) return null;

  return {
    countryCode: activeCountry.id,
    city: city ? `${city},` : null,
    name: activeCountry.name,
  };
});

const formattedLocation = computed(() => {
  if (!countryDetails.value) return '';

  return [countryDetails.value.city, countryDetails.value.name]
    .filter(Boolean)
    .join(' ');
});

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const handleUpdateContact = () => {
  emit('updateContact', contactData.value);
};

const onClickExpand = () => {
  emit('toggle');
  contactData.value = getInitialContactData();
};

const onClickViewDetails = () => emit('showContact', props.id);

const toggleSelect = checked => {
  emit('select', checked);
};

const handleAvatarHover = isHovered => {
  emit('avatarHover', isHovered);
};
</script>

<template>
  <div class="relative">
    <CardLayout
      :key="id"
      layout="row"
      class="!bg-[#081218] !outline !outline-1 !outline-[#142633] hover:!outline-[#10B981]/40 transition-all duration-200 rounded-xl shadow-[0_4px_20px_rgba(0,0,0,0.28)]"
      :class="{
        '!outline-[#10B981] !bg-[#0B1922]': isSelected,
      }"
    >
      <div class="flex items-start sm:items-center justify-start flex-1 gap-3 sm:gap-4 min-w-0">
        <div
          class="relative shrink-0"
          @mouseenter="handleAvatarHover(true)"
          @mouseleave="handleAvatarHover(false)"
        >
          <Avatar
            :name="name"
            :src="thumbnail"
            :size="44"
            :status="availabilityStatus"
            rounded-full
            hide-offline-status
            class="ring-1 ring-[#1E3545]"
          >
            <template v-if="selectable" #overlay="{ size }">
              <label
                class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] border border-[#10B981]/50 bg-[#050C10]/70"
                :style="{ width: `${size}px`, height: `${size}px` }"
                @click.stop
              >
                <Checkbox
                  :model-value="isSelected"
                  @change="event => toggleSelect(event.target.checked)"
                />
              </label>
            </template>
          </Avatar>
        </div>
        <div class="flex flex-col gap-1.5 flex-1 min-w-0">
          <div class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
            <span
              class="text-[15px] font-semibold truncate text-white cursor-pointer hover:text-[#10B981] transition-colors"
              @click="onClickViewDetails"
            >
              {{ name }}
            </span>
            <span
              v-if="additionalAttributes?.companyName"
              class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md bg-[#0D1D26] border border-[#19303E] text-xs font-medium text-slate-300 max-w-full"
            >
              <span
                class="i-ph-buildings size-3.5 text-[#10B981] shrink-0"
              />
              <span class="truncate">
                {{ additionalAttributes.companyName }}
              </span>
            </span>
          </div>
          <div
            class="flex flex-wrap items-center justify-start gap-x-3 gap-y-1 text-xs sm:text-[13px] text-slate-300"
          >
            <div
              v-if="email"
              class="inline-flex items-center gap-1.5 truncate max-w-full sm:max-w-72"
              :title="email"
            >
              <span class="i-lucide-mail size-3.5 text-slate-400 shrink-0" />
              <span class="truncate text-slate-300">
                {{ email }}
              </span>
            </div>
            <div v-if="email && phoneNumber" class="hidden sm:block w-px h-3 bg-[#1A303D]" />
            <span
              v-if="phoneNumber"
              class="inline-flex items-center gap-1.5 truncate font-mono text-xs text-slate-300"
            >
              <span class="i-lucide-phone size-3.5 text-[#10B981] shrink-0" />
              {{ phoneNumber }}
            </span>
            <div
              v-if="(email || phoneNumber) && countryDetails"
              class="hidden sm:block w-px h-3 bg-[#1A303D]"
            />
            <span
              v-if="countryDetails"
              class="inline-flex items-center gap-1.5 truncate text-slate-300"
            >
              <Flag :country="countryDetails.countryCode" class="size-3.5 shrink-0" />
              {{ formattedLocation }}
            </span>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-1.5 sm:gap-2 shrink-0 self-center">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 h-8 px-2.5 sm:px-3 rounded-lg bg-[#10B981]/10 hover:bg-[#10B981]/20 border border-[#10B981]/30 text-xs font-semibold text-[#10B981] transition-colors cursor-pointer whitespace-nowrap"
          @click="onClickViewDetails"
        >
          <span class="hidden xs:inline">{{ t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS') }}</span>
          <span class="xs:hidden">Detalhes</span>
          <span class="i-lucide-arrow-up-right size-3.5" />
        </button>

        <Button
          icon="i-lucide-chevron-down"
          variant="ghost"
          color="slate"
          size="xs"
          class="!h-8 !w-8 !bg-[#050C10] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-lg transition-transform"
          :class="{ 'rotate-180 !border-[#10B981]': isExpanded }"
          @click="onClickExpand"
        />
      </div>

      <template #after>
        <div
          class="transition-all duration-500 ease-in-out grid overflow-hidden"
          :class="
            isExpanded
              ? 'grid-rows-[1fr] opacity-100'
              : 'grid-rows-[0fr] opacity-0'
          "
        >
          <div class="overflow-hidden">
            <div class="flex flex-col gap-6 p-6 border-t border-[#142633] bg-[#060E14]/60">
              <ContactsForm
                ref="contactsFormRef"
                :contact-data="contactData"
                @update="handleFormUpdate"
              />
              <div class="flex justify-end">
                <Button
                  :label="
                    t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')
                  "
                  icon="i-lucide-check"
                  size="sm"
                  class="!bg-[#10B981] hover:!bg-[#059669] !text-[#031911] font-semibold"
                  :is-loading="isUpdating"
                  :disabled="isUpdating || isFormInvalid"
                  @click="handleUpdateContact"
                />
              </div>
            </div>
            <ContactDeleteSection
              :selected-contact="{
                id: props.id,
                name: props.name,
              }"
            />
          </div>
        </div>
      </template>
    </CardLayout>
  </div>
</template>
