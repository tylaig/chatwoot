<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactLabels/ContactLabels.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import ConfirmContactDeleteDialog from 'dashboard/components-next/Contacts/ContactsForm/ConfirmContactDeleteDialog.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['goToContactsList']);

const exactTimestamp = useExactTimestamp();

const { t } = useI18n();
const store = useStore();

const confirmDeleteContactDialogRef = ref(null);

const avatarFile = ref(null);
const avatarUrl = ref('');

const contactsFormRef = ref(null);

const uiFlags = useMapGetter('contacts/getUIFlags');
const isUpdating = computed(() => uiFlags.value.isUpdating);

const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const contactData = ref({});

const getInitialContactData = () => {
  if (!props.selectedContact) return {};
  return { ...props.selectedContact };
};

onMounted(() => {
  Object.assign(contactData.value, getInitialContactData());
});

const createdAt = computed(() => {
  return contactData.value?.createdAt
    ? dynamicTime(contactData.value.createdAt)
    : '';
});

const lastActivityAt = computed(() => {
  return contactData.value?.lastActivityAt
    ? dynamicTime(contactData.value.lastActivityAt)
    : '';
});

const avatarSrc = computed(() => {
  return avatarUrl.value ? avatarUrl.value : contactData.value?.thumbnail;
});

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const updateContact = async () => {
  try {
    const { customAttributes, ...basicContactData } = contactData.value;
    await store.dispatch('contacts/update', basicContactData);
    await store.dispatch(
      'contacts/fetchContactableInbox',
      props.selectedContact.id
    );
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERROR_MESSAGE'));
  }
};

const openConfirmDeleteContactDialog = () => {
  confirmDeleteContactDialogRef.value?.dialogRef.open();
};

const handleAvatarUpload = async ({ file, url }) => {
  avatarFile.value = file;
  avatarUrl.value = url;

  try {
    await store.dispatch('contacts/update', {
      ...contactsFormRef.value?.state,
      avatar: file,
      isFormData: true,
    });
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.ERROR_MESSAGE'));
  }
};

const handleAvatarDelete = async () => {
  try {
    if (props.selectedContact && props.selectedContact.id) {
      await store.dispatch('contacts/deleteAvatar', props.selectedContact.id);
      useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.SUCCESS_MESSAGE'));
    }
    avatarFile.value = null;
    avatarUrl.value = '';
    contactData.value.thumbnail = null;
  } catch (error) {
    useAlert(
      error.message
        ? error.message
        : t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="flex flex-col gap-5 pb-10 w-full">
    <!-- Card 1: Profile Hero Card -->
    <section
      class="bg-[#081218] border border-[#132631] rounded-xl p-5 sm:p-6 flex flex-col sm:flex-row sm:items-start justify-between gap-4 shadow-[0_4px_20px_rgba(0,0,0,0.28)]"
    >
      <div class="flex items-start gap-4 sm:gap-5 min-w-0">
        <Avatar
          :src="avatarSrc || ''"
          :name="selectedContact?.name || ''"
          :size="68"
          rounded-full
          allow-upload
          class="ring-2 ring-[#10B981]/30 shrink-0"
          @upload="handleAvatarUpload"
          @delete="handleAvatarDelete"
        />
        <div class="flex flex-col gap-1.5 min-w-0">
          <h1
            class="text-lg sm:text-[22px] font-bold text-white tracking-tight truncate"
          >
            {{ selectedContact?.name }}
          </h1>
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1 text-[13px] text-slate-400">
            <span
              v-if="selectedContact?.identifier"
              class="inline-flex items-center gap-1"
            >
              <span class="i-ph-user-gear text-slate-400 size-4" />
              {{ selectedContact?.identifier }}
            </span>
            <span class="inline-flex flex-wrap items-center gap-1.5">
              <span
                v-if="selectedContact?.identifier"
                class="i-ph-activity text-slate-400 size-4"
              />
              <span
                v-tooltip.top="{
                  content: exactTimestamp(contactData?.createdAt),
                  delay: { show: 500, hide: 0 },
                }"
              >
                {{
                  $t('CONTACTS_LAYOUT.DETAILS.CREATED_AT', { date: createdAt })
                }}
              </span>
              <span>•</span>
              <span
                v-tooltip.top="{
                  content: exactTimestamp(contactData?.lastActivityAt),
                  delay: { show: 500, hide: 0 },
                }"
              >
                {{
                  $t('CONTACTS_LAYOUT.DETAILS.LAST_ACTIVITY', {
                    date: lastActivityAt,
                  })
                }}
              </span>
            </span>
          </div>
          <!-- Quick info pills -->
          <div class="flex flex-wrap items-center gap-2 mt-1">
            <span
              v-if="selectedContact?.phoneNumber"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-[#0D1D26] border border-[#1A303D] text-slate-200"
            >
              <span class="i-lucide-phone size-3.5 text-[#10B981]" />
              {{ selectedContact.phoneNumber }}
            </span>
            <span
              v-if="selectedContact?.email"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-[#0D1D26] border border-[#1A303D] text-slate-200 max-w-full truncate"
            >
              <span class="i-lucide-mail size-3.5 text-slate-400 shrink-0" />
              <span class="truncate">{{ selectedContact.email }}</span>
            </span>
            <span
              v-if="selectedContact?.additionalAttributes?.companyName"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-[#0D1D26] border border-[#1A303D] text-slate-200"
            >
              <span class="i-ph-buildings size-3.5 text-[#10B981]" />
              {{ selectedContact.additionalAttributes.companyName }}
            </span>
            <span
              v-if="selectedContact?.additionalAttributes?.city"
              class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-[#0D1D26] border border-[#1A303D] text-slate-200"
            >
              <span class="i-lucide-map-pin size-3.5 text-slate-400" />
              {{ selectedContact.additionalAttributes.city }}
            </span>
          </div>
        </div>
      </div>
      <div class="shrink-0">
        <ContactLabels :contact-id="selectedContact?.id" />
      </div>
    </section>

    <!-- Card 2: Edit Details & Social Networks -->
    <section
      class="bg-[#081218] border border-[#132631] rounded-xl p-5 sm:p-6 flex flex-col gap-6 shadow-[0_4px_20px_rgba(0,0,0,0.28)] w-full"
    >
      <ContactsForm
        ref="contactsFormRef"
        :contact-data="contactData"
        is-details-view
        @update="handleFormUpdate"
      />
      <div class="flex justify-end pt-2 border-t border-[#132631]">
        <Button
          :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')"
          icon="i-lucide-save"
          size="sm"
          class="!h-10 !px-5 !bg-[#10B981] hover:!bg-[#059669] !text-[#031911] font-semibold shadow-[0_0_15px_rgba(16,185,129,0.25)]"
          :is-loading="isUpdating"
          :disabled="isUpdating || isFormInvalid"
          @click="updateContact"
        />
      </div>
    </section>

    <!-- Card 3: Danger Zone -->
    <Policy :permissions="['administrator']">
      <section
        class="bg-[#14090D] border border-red-500/30 rounded-xl px-5 sm:px-6 py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 w-full"
      >
        <div class="flex items-start gap-3">
          <span class="i-lucide-trash-2 size-5 text-red-500 mt-0.5 shrink-0" />
          <div class="flex flex-col gap-0.5">
            <h6 class="text-sm font-semibold text-red-400">
              {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT') }}
            </h6>
            <span class="text-xs text-slate-400">
              {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT_DESCRIPTION') }}
            </span>
          </div>
        </div>
        <Button
          :label="t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')"
          icon="i-lucide-trash-2"
          color="ruby"
          size="sm"
          class="!bg-[#451219] hover:!bg-red-900/80 !border !border-red-500/40 !text-red-200 font-semibold shrink-0"
          @click="openConfirmDeleteContactDialog"
        />
      </section>
      <ConfirmContactDeleteDialog
        ref="confirmDeleteContactDialogRef"
        :selected-contact="selectedContact"
        @go-to-contacts-list="emit('goToContactsList')"
      />
    </Policy>
  </div>
</template>
