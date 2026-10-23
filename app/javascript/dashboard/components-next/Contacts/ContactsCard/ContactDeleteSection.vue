<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';

import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmContactDeleteDialog from 'dashboard/components-next/Contacts/ContactsForm/ConfirmContactDeleteDialog.vue';
import Policy from 'dashboard/components/policy.vue';

defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const [showDeleteSection, toggleDeleteSection] = useToggle();
const confirmDeleteContactDialogRef = ref(null);

const openConfirmDeleteContactDialog = () => {
  confirmDeleteContactDialogRef.value?.dialogRef.open();
};
</script>

<template>
  <Policy :permissions="['administrator']">
    <div
      class="flex flex-col items-start border-t border-[#142633] bg-[#14090D]/80 px-6 py-4 rounded-b-xl"
    >
      <Button
        :label="t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')"
        sm
        link
        slate
        class="hover:!no-underline !text-red-400 font-medium"
        icon="i-lucide-chevron-down"
        trailing-icon
        @click="toggleDeleteSection()"
      />

      <div
        class="transition-all duration-300 ease-in-out grid w-full overflow-hidden"
        :class="
          showDeleteSection
            ? 'grid-rows-[1fr] opacity-100 mt-2'
            : 'grid-rows-[0fr] opacity-0 mt-0'
        "
      >
        <div class="overflow-hidden min-h-0">
          <span class="inline-flex flex-wrap text-slate-300 text-xs sm:text-sm items-center gap-2">
            {{ t('CONTACTS_LAYOUT.CARD.DELETE_CONTACT.MESSAGE') }}
            <Button
              :label="t('CONTACTS_LAYOUT.CARD.DELETE_CONTACT.BUTTON')"
              sm
              ruby
              link
              class="!text-red-400 font-semibold"
              @click="openConfirmDeleteContactDialog()"
            />
          </span>
        </div>
      </div>
    </div>
    <ConfirmContactDeleteDialog
      ref="confirmDeleteContactDialogRef"
      :selected-contact="selectedContact"
    />
  </Policy>
</template>
