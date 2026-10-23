<script setup>
import { computed, ref, onMounted } from 'vue';
import Auth from 'dashboard/api/auth';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';
import SystemUpdateModal from './SystemUpdateModal.vue';
import SystemUpdatesAPI from 'dashboard/api/systemUpdates';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSeparator,
  DropdownItem,
} from 'next/dropdown-menu/base';
import CustomBrandPolicyWrapper from '../../components/CustomBrandPolicyWrapper.vue';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'openKeyShortcutModal']);

defineOptions({
  inheritAttrs: false,
});

const { t } = useI18n();
const { isAdmin } = useAdmin();

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const accountId = useMapGetter('getCurrentAccountId');
const globalConfig = useMapGetter('globalConfig/get');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const systemUpdateModalRef = ref(null);
const pendingUpdatesCount = ref(0);
const pendingBadgeLabel = computed(() => `${pendingUpdatesCount.value} ↑`);
const pendingBadgeTitle = 'Nova atualização disponível';

const canManageSystemUpdates = computed(() => {
  return currentUser.value?.type === 'SuperAdmin' || isAdmin.value;
});

const openSystemUpdateModal = () => {
  systemUpdateModalRef.value?.open();
};

onMounted(async () => {
  if (!canManageSystemUpdates.value) return;
  try {
    const { data } = await SystemUpdatesAPI.check(false);
    pendingUpdatesCount.value = data?.has_updates ? data.ahead_by || 1 : 0;
  } catch (e) {
    // ignore background check error
  }
});

const showChatSupport = computed(() => {
  return (
    isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.CONTACT_CHATWOOT_SUPPORT_TEAM
    ) && globalConfig.value.chatwootInboxToken
  );
});

const toggleChatSupport = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggle();
  }
};

const menuItems = computed(() => {
  return [
    {
      show: showChatSupport.value,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CONTACT_SUPPORT'),
      icon: 'i-lucide-life-buoy',
      click: toggleChatSupport,
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS'),
      icon: 'i-lucide-keyboard',
      click: () => {
        emit('openKeyShortcutModal');
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.PROFILE_SETTINGS'),
      icon: 'i-lucide-user-pen',
      link: { name: 'profile_settings_index' },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.APPEARANCE'),
      icon: 'i-lucide-palette',
      click: () => {
        const ninja = document.querySelector('ninja-keys');
        ninja.open({ parent: 'appearance_settings' });
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.DOCS'),
      icon: 'i-lucide-book',
      link: 'https://www.chatwoot.com/hc/user-guide/en',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CHANGELOG'),
      icon: 'i-lucide-scroll-text',
      link: 'https://fazer.ai/chatwoot-release-notes',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: canManageSystemUpdates.value,
      showOnCustomBrandedInstance: true,
      label:
        pendingUpdatesCount.value > 0
          ? `Atualizações do Sistema (${pendingUpdatesCount.value} nova${pendingUpdatesCount.value > 1 ? 's' : ''})`
          : 'Atualizações do Sistema',
      icon: 'i-lucide-rocket',
      click: openSystemUpdateModal,
    },
    {
      show: currentUser.value.type === 'SuperAdmin',
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE'),
      icon: 'i-lucide-castle',
      link: '/super_admin',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.LOGOUT'),
      icon: 'i-lucide-power',
      click: Auth.logout,
    },
  ];
});

const allowedMenuItems = computed(() => {
  return menuItems.value.filter(item => item.show);
});
</script>

<template>
  <DropdownContainer
    class="relative min-w-0"
    :class="isCollapsed ? 'w-auto' : 'w-full'"
    @close="emit('close')"
  >
    <template #trigger="{ toggle, isOpen }">
      <button
        class="flex gap-2 items-center p-1 text-left rounded-lg cursor-pointer hover:bg-n-alpha-1"
        :class="[
          { 'bg-n-alpha-1': isOpen },
          isCollapsed ? 'justify-center' : 'w-full',
        ]"
        :title="isCollapsed ? currentUser.available_name : undefined"
        @click="toggle"
      >
        <Avatar
          :size="32"
          :name="currentUser.available_name"
          :src="currentUser.avatar_url"
          :status="currentUserAvailability"
          class="flex-shrink-0"
        />
        <div v-if="!isCollapsed" class="min-w-0 flex-1">
          <div class="text-sm font-medium leading-4 truncate text-n-slate-12">
            {{ currentUser.available_name }}
          </div>
          <div class="text-xs truncate text-n-slate-11">
            {{ currentUser.email }}
          </div>
        </div>
        <span
          v-if="
            canManageSystemUpdates && pendingUpdatesCount > 0 && !isCollapsed
          "
          class="px-1.5 py-0.5 text-[10px] font-bold rounded-full bg-n-teal-9 text-white shrink-0"
          :title="pendingBadgeTitle"
          @click.stop="openSystemUpdateModal"
        >
          {{ pendingBadgeLabel }}
        </span>
      </button>
    </template>
    <DropdownBody class="bottom-12 z-50 mb-2 w-80 ltr:left-0 rtl:right-0">
      <SidebarProfileMenuStatus />
      <DropdownSeparator />
      <template v-for="item in allowedMenuItems" :key="item.label">
        <CustomBrandPolicyWrapper
          :show-on-custom-branded-instance="item.showOnCustomBrandedInstance"
        >
          <DropdownItem v-if="item.show" v-bind="item" />
        </CustomBrandPolicyWrapper>
      </template>
    </DropdownBody>
  </DropdownContainer>
  <SystemUpdateModal v-if="canManageSystemUpdates" ref="systemUpdateModalRef" />
</template>
