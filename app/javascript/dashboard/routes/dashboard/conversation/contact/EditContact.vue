<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import ContactForm from './ContactForm.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  contact: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['cancel']);

const store = useStore();
const uiFlags = useMapGetter('contacts/getUIFlags');

const contactForm = ref(null);
const confirmDiscardDialog = ref(null);

const onCancel = async () => {
  const hasChanges = contactForm.value?.hasUnsavedChanges;
  if (hasChanges) {
    const shouldDiscard = await confirmDiscardDialog.value?.showConfirmation();
    if (!shouldDiscard) return;
  }
  emit('cancel');
};

const onSubmit = async contactItem => {
  await store.dispatch('contacts/update', contactItem);
  await store.dispatch('contacts/fetchContactableInbox', props.contact.id);
};

// Restore Escape-to-close behavior that was provided by woot-modal before
// this drawer was reimplemented as a plain fixed panel.
useKeyboardEvents({
  Escape: {
    action: () => {
      if (props.show) onCancel();
    },
    allowOnFocusedInput: true,
  },
});
</script>

<template>
  <transition
    enter-active-class="transition duration-200 ease-out"
    enter-from-class="ltr:translate-x-full rtl:-translate-x-full opacity-0"
    leave-active-class="transition duration-150 ease-in"
    leave-to-class="ltr:translate-x-[30%] rtl:-translate-x-[30%] opacity-0"
  >
    <div
      v-if="show"
      class="fixed inset-y-0 ltr:right-0 rtl:left-0 z-50 flex flex-col w-full sm:w-[27.5rem] max-w-full h-full bg-[#081015]/95 backdrop-blur-xl ltr:border-l-2 rtl:border-r-2 border-[#10B981]/60 shadow-[0_0_40px_rgba(0,0,0,0.65)] overflow-hidden"
    >
      <div
        class="shrink-0 flex items-start justify-between px-6 pt-5 pb-4 border-b border-[#162936] bg-[#060D12]/95"
      >
        <div class="min-w-0 pr-3">
          <h2 class="text-lg font-semibold tracking-tight text-white truncate mb-0.5">
            {{
              `${$t('EDIT_CONTACT.TITLE')} - ${contact.name || contact.email}`
            }}
          </h2>
          <p class="text-[13px] text-slate-400 mb-0">
            {{ $t('EDIT_CONTACT.DESC') }}
          </p>
        </div>
        <Button
          icon="i-lucide-x"
          slate
          ghost
          sm
          class="!h-8 !w-8 !bg-[#0B161E] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-lg shrink-0"
          @click="onCancel"
        />
      </div>
      <ContactForm
        ref="contactForm"
        :contact="contact"
        :in-progress="uiFlags.isUpdating"
        :on-submit="onSubmit"
        class="flex-1 min-h-0"
        @success="$emit('cancel')"
        @cancel="onCancel"
      />
    </div>
  </transition>
  <woot-confirm-modal
    ref="confirmDiscardDialog"
    :title="$t('EDIT_CONTACT.CONFIRM_DISCARD.TITLE')"
    :description="$t('EDIT_CONTACT.CONFIRM_DISCARD.MESSAGE')"
    :confirm-label="$t('EDIT_CONTACT.CONFIRM_DISCARD.YES')"
    :cancel-label="$t('EDIT_CONTACT.CONFIRM_DISCARD.NO')"
  />
</template>
