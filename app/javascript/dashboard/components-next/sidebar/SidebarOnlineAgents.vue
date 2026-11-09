<script setup>
import { computed, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import {
  getAgentsByAvailability,
  getAgentsByUpdatedPresence,
} from 'dashboard/helper/agentHelper';

defineProps({
  isCollapsed: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const { isAdmin } = useAdmin();
const store = useStore();

const currentUser = useMapGetter('getCurrentUser');
const accountId = useMapGetter('getCurrentAccountId');
const agents = useMapGetter('agents/getAgents');

const isExpanded = ref(true);
const showOfflineAgents = ref(false);
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

const collapsedTooltip = computed(() => {
  if (!activeAgents.value.length) {
    return t('SIDEBAR.ONLINE_AGENTS.EMPTY');
  }
  const names = activeAgents.value
    .map(
      agent =>
        `${agent.availability_status === 'busy' ? '🟡' : '🟢'} ${getAgentDisplayName(agent)}`
    )
    .join('\n');
  return `${t('SIDEBAR.ONLINE_AGENTS.TITLE', { count: activeAgents.value.length })}\n${names}`;
});

const toggleExpanded = () => {
  isExpanded.value = !isExpanded.value;
};

const toggleOfflineAgents = () => {
  showOfflineAgents.value = !showOfflineAgents.value;
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
    useAlert(
      t('SIDEBAR.ONLINE_AGENTS.STATUS_UPDATED', {
        name: getAgentDisplayName(agent),
        status: getAgentStatusLabel(availability),
      })
    );
  } catch (error) {
    useAlert(t('SIDEBAR.ONLINE_AGENTS.STATUS_UPDATE_ERROR'));
  } finally {
    updatingAgentIds.value = { ...updatingAgentIds.value, [agent.id]: false };
  }
};
</script>

<template>
  <div class="w-full border-t border-n-weak bg-n-background">
    <div
      v-if="isCollapsed"
      :title="collapsedTooltip"
      class="flex items-center justify-center py-2 px-1"
    >
      <div
        class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-bold"
        :class="
          activeAgents.length > 0
            ? 'bg-n-teal-3 text-n-teal-11'
            : 'bg-n-slate-3 text-n-slate-11'
        "
      >
        <span
          class="size-1.5 rounded-full flex-shrink-0"
          :class="activeAgents.length > 0 ? 'bg-n-teal-10' : 'bg-n-slate-10'"
        />
        <span>{{ activeAgents.length }}</span>
      </div>
    </div>
    <div v-else class="px-2 py-1.5">
      <div class="flex items-center justify-between gap-1">
        <button
          type="button"
          class="flex items-center justify-between flex-1 min-w-0 px-1 py-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-10 hover:text-n-slate-12 rounded-md cursor-pointer transition-colors"
          @click="toggleExpanded"
        >
          <span class="flex items-center gap-1.5 truncate">
            <span
              class="size-2 rounded-full flex-shrink-0"
              :class="activeAgents.length > 0 ? 'bg-n-teal-10' : 'bg-n-slate-9'"
            />
            <span class="truncate">
              {{
                t('SIDEBAR.ONLINE_AGENTS.TITLE', { count: activeAgents.length })
              }}
            </span>
          </span>
          <Icon
            :icon="isExpanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-up'"
            class="size-3.5 text-n-slate-10 flex-shrink-0"
          />
        </button>
        <button
          v-if="isAdmin"
          type="button"
          :title="t('SIDEBAR.ONLINE_AGENTS.MANAGE_TEAM')"
          class="p-1 rounded-md text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 cursor-pointer transition-colors flex-shrink-0"
          :class="{ 'bg-n-alpha-2 text-n-slate-12': showOfflineAgents }"
          @click="toggleOfflineAgents"
        >
          <Icon icon="i-lucide-user-cog" class="size-3.5" />
        </button>
      </div>
      <div
        v-if="isExpanded"
        class="flex flex-col gap-0.5 mt-1 max-h-48 overflow-y-auto no-scrollbar"
      >
        <template v-if="activeAgents.length > 0">
          <div
            v-for="agent in activeAgents"
            :key="agent.id"
            class="flex items-center gap-2 px-1.5 py-1 rounded-md hover:bg-n-alpha-1 transition-colors group"
          >
            <Avatar
              :size="24"
              :name="getAgentDisplayName(agent)"
              :src="agent.thumbnail || agent.avatar_url"
              :status="agent.availability_status"
              rounded-full
              hide-offline-status
              class="flex-shrink-0"
            />
            <div
              class="min-w-0 flex-1 flex items-center justify-between gap-1.5"
            >
              <span class="text-xs font-medium truncate text-n-slate-12">
                {{ getAgentDisplayName(agent) }}
              </span>
              <div class="flex items-center gap-1 flex-shrink-0">
                <span
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium"
                  :class="
                    agent.availability_status === 'busy'
                      ? 'bg-n-amber-3 text-n-amber-11'
                      : 'bg-n-teal-3 text-n-teal-11'
                  "
                >
                  <span
                    class="size-1.5 rounded-full"
                    :class="
                      agent.availability_status === 'busy'
                        ? 'bg-n-amber-10'
                        : 'bg-n-teal-10'
                    "
                  />
                  {{ getAgentStatusLabel(agent.availability_status) }}
                </span>
                <button
                  v-if="isAdmin"
                  type="button"
                  :data-test-id="`set-offline-${agent.id}`"
                  :disabled="updatingAgentIds[agent.id]"
                  :title="t('SIDEBAR.ONLINE_AGENTS.SET_OFFLINE')"
                  class="p-0.5 rounded text-n-slate-10 hover:text-n-ruby-11 hover:bg-n-ruby-3 cursor-pointer transition-colors disabled:opacity-50"
                  @click.stop="updateAgentAvailability(agent, 'offline')"
                >
                  <Icon icon="i-lucide-power-off" class="size-3" />
                </button>
              </div>
            </div>
          </div>
        </template>
        <div
          v-else
          class="flex items-center gap-1.5 px-1.5 py-1 text-[11px] text-n-slate-10"
        >
          <span>{{ t('SIDEBAR.ONLINE_AGENTS.EMPTY') }}</span>
        </div>

        <div
          v-if="isAdmin && showOfflineAgents && offlineAgents.length > 0"
          class="mt-1.5 pt-1.5 border-t border-n-weak flex flex-col gap-0.5"
        >
          <div
            class="px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{
              t('SIDEBAR.ONLINE_AGENTS.OFFLINE_AGENTS', {
                count: offlineAgents.length,
              })
            }}
          </div>
          <div
            v-for="agent in offlineAgents"
            :key="`offline-${agent.id}`"
            class="flex items-center gap-2 px-1.5 py-1 rounded-md hover:bg-n-alpha-1 transition-colors"
          >
            <Avatar
              :size="22"
              :name="getAgentDisplayName(agent)"
              :src="agent.thumbnail || agent.avatar_url"
              status="offline"
              rounded-full
              hide-offline-status
              class="flex-shrink-0 opacity-70"
            />
            <div
              class="min-w-0 flex-1 flex items-center justify-between gap-1.5"
            >
              <span class="text-xs truncate text-n-slate-11">
                {{ getAgentDisplayName(agent) }}
              </span>
              <button
                type="button"
                :data-test-id="`set-online-${agent.id}`"
                :disabled="updatingAgentIds[agent.id]"
                :title="t('SIDEBAR.ONLINE_AGENTS.SET_ONLINE')"
                class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-n-slate-3 text-n-slate-11 hover:bg-n-teal-3 hover:text-n-teal-11 cursor-pointer transition-colors disabled:opacity-50 flex-shrink-0"
                @click.stop="updateAgentAvailability(agent, 'online')"
              >
                <span class="size-1.5 rounded-full bg-n-teal-10" />
                {{ t('SIDEBAR.ONLINE_AGENTS.STATUS.ONLINE') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
