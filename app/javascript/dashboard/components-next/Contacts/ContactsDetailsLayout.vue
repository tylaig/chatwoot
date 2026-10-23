<script setup>
import { computed, useSlots, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { vOnClickOutside } from '@vueuse/components';

import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    default: () => ({}),
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['goToContactsList', 'toggleBlock']);

const { t } = useI18n();
const slots = useSlots();
const route = useRoute();

const isContactSidebarOpen = ref(false);

const contactId = computed(() => route.params.contactId);

const selectedContactName = computed(() => {
  return props.selectedContact?.name;
});

const breadcrumbItems = computed(() => {
  const items = [
    {
      label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS'),
      link: '#',
    },
  ];
  if (props.selectedContact) {
    items.push({
      label: selectedContactName.value,
    });
  }
  return items;
});

const isContactBlocked = computed(() => {
  return props.selectedContact?.blocked;
});

const handleBreadcrumbClick = () => {
  emit('goToContactsList');
};

const toggleBlock = () => {
  emit('toggleBlock', isContactBlocked.value);
};

const handleConversationSidebarToggle = () => {
  isContactSidebarOpen.value = !isContactSidebarOpen.value;
};

const closeMobileSidebar = () => {
  if (!isContactSidebarOpen.value) return;
  isContactSidebarOpen.value = false;
};
</script>

<template>
  <section
    class="flex w-full h-full overflow-hidden justify-evenly bg-[#04090D]"
  >
    <div
      class="flex flex-col flex-1 min-w-0 h-full transition-all duration-300"
    >
      <header
        class="sticky top-0 z-10 px-4 sm:px-6 lg:px-8 bg-[#050C10]/95 backdrop-blur-md border-b border-[#132631]"
      >
        <div class="w-full mx-auto max-w-[52rem]">
          <div
            class="flex flex-col sm:flex-row items-start sm:items-center justify-between w-full py-3.5 sm:py-4 gap-3"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="i-lucide-users size-4 text-[#10B981] shrink-0" />
              <Breadcrumb
                :items="breadcrumbItems"
                @click="handleBreadcrumbClick"
              />
            </div>
            <div class="flex items-center flex-wrap sm:flex-nowrap gap-2 shrink-0">
              <Button
                :label="
                  !isContactBlocked
                    ? $t('CONTACTS_LAYOUT.HEADER.BLOCK_CONTACT')
                    : $t('CONTACTS_LAYOUT.HEADER.UNBLOCK_CONTACT')
                "
                icon="i-lucide-ban"
                size="sm"
                slate
                variant="outline"
                class="!h-9 !bg-[#081218] !border-[#1A303D] hover:!border-red-500/50 !text-slate-200"
                :is-loading="isUpdating"
                :disabled="isUpdating"
                @click="toggleBlock"
              />
              <VoiceCallButton
                :phone="selectedContact?.phoneNumber"
                :contact-id="contactId"
                :label="$t('CONTACT_PANEL.CALL')"
                size="sm"
              />
              <ComposeConversation :contact-id="contactId">
                <template #trigger>
                  <Button
                    :label="$t('CONTACTS_LAYOUT.HEADER.SEND_MESSAGE')"
                    icon="i-lucide-send"
                    size="sm"
                    class="!h-9 !bg-[#10B981] hover:!bg-[#059669] !text-[#031911] font-semibold shadow-[0_0_14px_rgba(16,185,129,0.25)]"
                  />
                </template>
              </ComposeConversation>
            </div>
          </div>
        </div>
      </header>
      <main class="flex-1 min-h-0 px-4 sm:px-6 lg:px-8 overflow-y-auto">
        <div class="w-full py-6 mx-auto max-w-[52rem]">
          <slot name="default" />
        </div>
      </main>
    </div>

    <!-- Desktop sidebar -->
    <div
      v-if="slots.sidebar"
      class="hidden lg:flex flex-col w-[380px] xl:w-[420px] shrink-0 border-l border-[#132631] bg-[#060E14]"
    >
      <div class="shrink-0 border-b border-[#132631] bg-[#081218]">
        <slot name="sidebarHeader" />
      </div>
      <div class="flex-1 min-h-0 overflow-y-auto pb-6 pt-4">
        <slot name="sidebar" />
      </div>
    </div>

    <!-- Mobile sidebar container -->
    <div
      v-if="slots.sidebar"
      class="lg:hidden fixed top-0 ltr:right-0 rtl:left-0 h-full z-50 flex justify-end transition-all duration-200 ease-in-out pointer-events-none"
      :class="isContactSidebarOpen ? 'w-full pointer-events-auto bg-black/50 backdrop-blur-xs' : 'w-16'"
    >
      <!-- Toggle button -->
      <div
        v-on-click-outside="[
          closeMobileSidebar,
          { ignore: ['#contact-sidebar-content'] },
        ]"
        class="flex items-start p-1 w-fit h-fit relative order-1 xs:top-20 top-24 transition-all bg-[#081218] border border-[#1A303D] duration-300 ease-in-out pointer-events-auto shadow-lg"
        :class="[
          isContactSidebarOpen
            ? 'justify-end ltr:rounded-l-full rtl:rounded-r-full ltr:rounded-r-none rtl:rounded-l-none'
            : 'justify-center rounded-full ltr:mr-4 rtl:ml-4',
        ]"
      >
        <Button
          ghost
          slate
          sm
          class="!rounded-full rtl:rotate-180"
          :class="{ 'bg-[#10B981]/20 text-[#10B981]': isContactSidebarOpen }"
          :icon="
            isContactSidebarOpen
              ? 'i-lucide-panel-right-close'
              : 'i-lucide-panel-right-open'
          "
          data-contact-sidebar-toggle
          @click="handleConversationSidebarToggle"
        />
      </div>

      <Transition
        enter-active-class="transition-transform duration-200 ease-in-out"
        leave-active-class="transition-transform duration-200 ease-in-out"
        enter-from-class="ltr:translate-x-full rtl:-translate-x-full"
        enter-to-class="ltr:translate-x-0 rtl:-translate-x-0"
        leave-from-class="ltr:translate-x-0 rtl:-translate-x-0"
        leave-to-class="ltr:translate-x-full rtl:-translate-x-full"
      >
        <div
          v-if="isContactSidebarOpen"
          id="contact-sidebar-content"
          class="order-2 w-[88%] sm:w-[390px] flex flex-col bg-[#060E14] ltr:border-l rtl:border-r border-[#132631] shadow-2xl pointer-events-auto"
        >
          <div class="shrink-0 border-b border-[#132631] bg-[#081218]">
            <slot name="sidebarHeader" />
          </div>
          <div class="flex-1 min-h-0 overflow-y-auto pb-6 pt-4">
            <slot name="sidebar" />
          </div>
        </div>
      </Transition>
    </div>
  </section>
</template>
