<script setup>
import { computed, ref, onMounted } from 'vue';
import Auth from 'dashboard/api/auth';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';
import SystemUpdateModal from './SystemUpdateModal.vue';
import SystemUpdatesAPI from 'dashboard/api/systemUpdates';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import {
  getAgentsByAvailability,
  getAgentsByUpdatedPresence,
} from 'dashboard/helper/agentHelper';

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
const store = useStore();

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const accountId = useMapGetter('getCurrentAccountId');
const globalConfig = useMapGetter('globalConfig/get');
const agents = useMapGetter('agents/getAgents');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const showTeamAgentsPanel = ref(false);
const showOfflineInMenu = ref(false);
const updatingAgentIds = ref({});

const updatedAgentsList = computed(() => {
  const list = Array.isArray(agents.value) ? agents.value : [];
  if (!list.length) return [];

  return currentUser.value?.id && Array.isArray(currentUser.value?.accounts)
    ? getAgentsByUpdatedPresence(list, currentUser.value, accountId.value)
    : list;
});

const activeAgents = computed(() => {
  const onlineAgents = getAgentsByAvailability(
    updatedAgentsList.value,
    'online'
  );
  const busyAgents = getAgentsByAvailability(updatedAgentsList.value, 'busy');
  return [...onlineAgents, ...busyAgents];
});

const offlineAgents = computed(() => {
  return getAgentsByAvailability(updatedAgentsList.value, 'offline');
});

const getAgentDisplayName = agent => {
  return agent.available_name || agent.name || agent.email || '';
};

const getAgentStatusLabel = status => {
  if (status === 'busy') {
    return t('SIDEBAR.ONLINE_AGENTS.STATUS.BUSY');
  }
  if (status === 'offline') {
    return t('SIDEBAR.ONLINE_AGENTS.STATUS.OFFLINE');
  }
  return t('SIDEBAR.ONLINE_AGENTS.STATUS.ONLINE');
};

const updateAgentAvailability = async (agent, availability) => {
  if (!isAdmin.value || updatingAgentIds.value[agent.id]) return;

  updatingAgentIds.value = { ...updatingAgentIds.value, [agent.id]: true };
  try {
    await store.dispatch('agents/update', {
      id: agent.id,
      availability,
      auto_offline: false,
    });
    if (Number(agent.id) === Number(currentUser.value?.id)) {
      store.dispatch('updateAvailability', {
        availability,
        account_id: accountId.value,
      });
    }
  } catch (e) {
    // ignore error
  } finally {
    updatingAgentIds.value = { ...updatingAgentIds.value, [agent.id]: false };
  }
};

const toggleTeamAgentsPanel = () => {
  showTeamAgentsPanel.value = !showTeamAgentsPanel.value;
  if (!agents.value?.length) {
    store.dispatch('agents/get');
  }
};

const handleTriggerClick = toggle => {
  if (!agents.value?.length) {
    store.dispatch('agents/get');
  }
  toggle();
};

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
  if (!agents.value?.length) {
    store.dispatch('agents/get');
  }
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
      label: t('SIDEBAR.TEAM_AGENTS'),
      icon: 'i-lucide-users',
      preserveOpen: true,
      click: toggleTeamAgentsPanel,
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
        @click="handleTriggerClick(toggle)"
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
      <DropdownSeparator />
      <div class="-mx-2 px-2 pt-1 pb-1">
        <div
          class="flex items-center justify-between px-2 mb-2 text-[11px] font-semibold tracking-wider uppercase text-n-slate-10"
        >
          <span>
            {{
              t('SIDEBAR.ONLINE_AGENTS.TITLE', { count: activeAgents.length })
            }}
          </span>
          <div class="flex items-center gap-1">
            <button
              v-if="isAdmin"
              type="button"
              :title="t('SIDEBAR.ONLINE_AGENTS.MANAGE_TEAM')"
              class="p-1 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 cursor-pointer transition-colors"
              :class="{ 'bg-n-alpha-2 text-n-slate-12': showOfflineInMenu }"
              @click.stop="showOfflineInMenu = !showOfflineInMenu"
            >
              <Icon icon="i-lucide-user-cog" class="size-3.5" />
            </button>
            <span
              class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-bold"
              :class="
                activeAgents.length > 0
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-slate-3 text-n-slate-11'
              "
            >
              <span
                class="size-1.5 rounded-full"
                :class="
                  activeAgents.length > 0 ? 'bg-n-teal-10' : 'bg-n-slate-10'
                "
              />
              {{ activeAgents.length }}
            </span>
          </div>
        </div>
        <div
          v-if="activeAgents.length > 0"
          class="flex flex-col gap-1 max-h-48 overflow-y-auto px-1"
        >
          <div
            v-for="agent in activeAgents"
            :key="agent.id"
            class="flex items-center gap-2.5 px-2 py-1.5 rounded-lg hover:bg-n-alpha-2 transition-colors"
          >
            <Avatar
              :size="28"
              :name="getAgentDisplayName(agent)"
              :src="agent.thumbnail || agent.avatar_url"
              :status="agent.availability_status"
              rounded-full
              hide-offline-status
              class="flex-shrink-0"
            />
            <div class="min-w-0 flex-1">
              <div
                class="text-xs font-medium leading-4 truncate text-n-slate-12"
              >
                {{ getAgentDisplayName(agent) }}
              </div>
              <div class="flex items-center gap-1 mt-0.5">
                <span
                  class="size-1.5 rounded-full flex-shrink-0"
                  :class="
                    agent.availability_status === 'busy'
                      ? 'bg-n-amber-10'
                      : 'bg-n-teal-10'
                  "
                />
                <span
                  class="text-[11px] leading-3 font-medium truncate"
                  :class="
                    agent.availability_status === 'busy'
                      ? 'text-n-amber-11'
                      : 'text-n-teal-11'
                  "
                >
                  {{ getAgentStatusLabel(agent.availability_status) }}
                </span>
              </div>
            </div>
            <button
              v-if="isAdmin"
              type="button"
              :disabled="updatingAgentIds[agent.id]"
              :title="t('SIDEBAR.ONLINE_AGENTS.SET_OFFLINE')"
              class="px-2 py-1 rounded text-[10px] font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-ruby-3 hover:text-n-ruby-11 cursor-pointer transition-colors disabled:opacity-50 flex-shrink-0"
              @click.stop="updateAgentAvailability(agent, 'offline')"
            >
              Offline
            </button>
          </div>
        </div>
        <div
          v-else
          class="flex items-center gap-2 px-2 py-2 text-xs text-n-slate-10"
        >
          <Icon icon="i-lucide-users" class="size-3.5 text-n-slate-9" />
          <span>{{ t('SIDEBAR.ONLINE_AGENTS.EMPTY') }}</span>
        </div>

        <div
          v-if="isAdmin && showOfflineInMenu && offlineAgents.length > 0"
          class="mt-2 pt-2 border-t border-n-weak flex flex-col gap-1 max-h-40 overflow-y-auto px-1"
        >
          <div
            class="px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{
              t('SIDEBAR.ONLINE_AGENTS.OFFLINE_AGENTS', {
                count: offlineAgents.length,
              })
            }}
          </div>
          <div
            v-for="agent in offlineAgents"
            :key="`menu-offline-${agent.id}`"
            class="flex items-center gap-2.5 px-2 py-1 rounded-lg hover:bg-n-alpha-2 transition-colors"
          >
            <Avatar
              :size="24"
              :name="getAgentDisplayName(agent)"
              :src="agent.thumbnail || agent.avatar_url"
              status="offline"
              rounded-full
              hide-offline-status
              class="flex-shrink-0 opacity-70"
            />
            <div class="min-w-0 flex-1 text-xs truncate text-n-slate-11">
              {{ getAgentDisplayName(agent) }}
            </div>
            <button
              type="button"
              :disabled="updatingAgentIds[agent.id]"
              :title="t('SIDEBAR.ONLINE_AGENTS.SET_ONLINE')"
              class="px-2 py-1 rounded text-[10px] font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-teal-3 hover:text-n-teal-11 cursor-pointer transition-colors disabled:opacity-50 flex-shrink-0"
              @click.stop="updateAgentAvailability(agent, 'online')"
            >
              Online
            </button>
          </div>
        </div>
      </div>
    </DropdownBody>
  </DropdownContainer>
  <SystemUpdateModal v-if="canManageSystemUpdates" ref="systemUpdateModalRef" />
</template>
