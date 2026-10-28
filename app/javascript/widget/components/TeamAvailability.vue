<script setup>
import { computed } from 'vue';
import { IFrameHelper } from 'widget/helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';
import { useMapGetter } from 'dashboard/composables/store.js';

const props = defineProps({
  hasConversation: { type: Boolean, default: false },
});

const emit = defineEmits(['startConversation']);

const widgetColor = useMapGetter('appConfig/getWidgetColor');

const startConversation = () => {
  emit('startConversation');
  if (!props.hasConversation) {
    IFrameHelper.sendMessage({
      event: 'onEvent',
      eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
      data: { hasConversation: false },
    });
  }
};

const getInboxSchedule = () => {
  const ch = window.chatwootWebChannel || {};
  const tz = ch.timezone || 'America/Sao_Paulo';
  let currentHour = 12;
  let dayOfWeek = 1;
  try {
    const now = new Date();
    const tzStr = now.toLocaleString('en-US', { timeZone: tz });
    const tzDate = new Date(tzStr);
    currentHour = tzDate.getHours();
    dayOfWeek = tzDate.getDay();
  } catch (e) {
    const now = new Date();
    currentHour = now.getHours();
    dayOfWeek = now.getDay();
  }

  let openHour = 11;
  let closeHour = 22;
  let closedToday = false;

  if (ch.workingHoursEnabled && Array.isArray(ch.workingHours)) {
    const todaySlot = ch.workingHours.find(
      s => Number(s.day_of_week ?? s.dayOfWeek) === dayOfWeek
    );
    if (todaySlot) {
      closedToday = Boolean(todaySlot.closed_all_day ?? todaySlot.closedAllDay);
      if (todaySlot.open_all_day || todaySlot.openAllDay) {
        openHour = 0;
        closeHour = 24;
      } else {
        openHour = Number(todaySlot.open_hour ?? todaySlot.openHour ?? 11);
        closeHour = Number(todaySlot.close_hour ?? todaySlot.closeHour ?? 22);
      }
    }
  }

  return { currentHour, openHour, closeHour, closedToday };
};

const botCardTitle = computed(() => {
  const botName = window.chatwootWebChannel?.hasAConnectedAgentBot;
  if (botName && String(botName).trim()) {
    return `${String(botName).trim()} • Atendimento Rápido`;
  }
  return null;
});

const isHumanOnline = computed(() => {
  try {
    const params = new URLSearchParams(window.location.search);
    const forcedStatus = params.get('cw_team_status');
    if (forcedStatus === 'online') return true;
    if (forcedStatus === 'offline' || forcedStatus === 'offline_today') {
      return false;
    }
  } catch (e) {
    // ignore
  }
  const { currentHour, openHour, closeHour, closedToday } = getInboxSchedule();
  if (closedToday) return false;
  return currentHour >= openHour && currentHour < closeHour;
});

const isOfflineBeforeOpeningToday = computed(() => {
  try {
    const params = new URLSearchParams(window.location.search);
    const forcedStatus = params.get('cw_team_status');
    if (forcedStatus === 'offline_today') return true;
  } catch (e) {
    // ignore
  }
  const { currentHour, openHour, closedToday } = getInboxSchedule();
  if (closedToday) return false;
  return currentHour < openHour;
});

const styles = {
  onlineCard: { backgroundColor: '#dcfce7', borderColor: '#86efac' },
  offlineCard: { backgroundColor: '#fee2e2', borderColor: '#fca5a5' },
  onlineCircle: {
    backgroundColor: '#16a34a',
    boxShadow: '0 4px 10px rgba(0, 0, 0, 0.08)',
  },
  onlineDot: {
    width: '13px',
    height: '13px',
    backgroundColor: '#22c55e',
    border: '2.5px solid #ffffff',
  },
  offlineCircle: {
    backgroundColor: '#dc2626',
    boxShadow: '0 4px 10px rgba(0, 0, 0, 0.08)',
  },
  offlineBadgeX: {
    width: '17px',
    height: '17px',
    boxShadow: '0 1px 3px rgba(0, 0, 0, 0.15)',
  },
  humanTitle: { color: '#0f172a' },
  humanSubtitle: { color: '#475569' },
  leoCard: {
    border: '1px solid #e2e8f0',
    boxShadow: '0 2px 6px rgba(15, 23, 42, 0.03)',
  },
  leoDot: {
    width: '10px',
    height: '10px',
    backgroundColor: '#10b981',
  },
  leoTitle: { color: '#1e293b' },
  leoPill: {
    color: '#047857',
    backgroundColor: '#ecfdf5',
    border: '1px solid #a7f3d0',
  },
  leoDesc: { color: '#64748b' },
  leoStrong: { color: '#334155' },
  leoDivider: { backgroundColor: '#f1f5f9' },
  leoHint: { color: '#94a3b8' },
};
</script>

<template>
  <div class="flex flex-col gap-3 w-full">
    <!-- Card 1: Equipe de Suporte (Destaque Principal de Horário) -->
    <div
      class="flex items-center justify-between px-4 py-[15px] rounded-[18px] transition-all duration-200 select-none border-[1.5px]"
      :style="isHumanOnline ? styles.onlineCard : styles.offlineCard"
    >
      <div class="flex items-center gap-3.5 flex-1 min-w-0">
        <!-- Ícone Dinâmico: Headset com status -->
        <div v-if="isHumanOnline" class="shrink-0">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center relative"
            :style="styles.onlineCircle"
          >
            <svg
              width="25"
              height="25"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#ffffff"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M3 18v-6a9 9 0 0 1 18 0v6" />
              <path
                d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"
              />
              <path d="M18 13c0 2-1 4-3 5" />
            </svg>
            <span
              class="absolute -top-0.5 -right-0.5 rounded-full"
              :style="styles.onlineDot"
            />
          </div>
        </div>

        <div v-else class="shrink-0">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center relative"
            :style="styles.offlineCircle"
          >
            <svg
              width="25"
              height="25"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#ffffff"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M3 18v-6a9 9 0 0 1 18 0v6" />
              <path
                d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"
              />
              <line
                x1="1"
                y1="1"
                x2="23"
                y2="23"
                stroke="#ffffff"
                stroke-width="2.2"
              />
            </svg>
            <span
              class="absolute -bottom-0.5 -right-0.5 bg-white rounded-full flex items-center justify-center"
              :style="styles.offlineBadgeX"
            >
              <svg
                width="10"
                height="10"
                viewBox="0 0 24 24"
                fill="none"
                stroke="#dc2626"
                stroke-width="4"
                stroke-linecap="round"
              >
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </span>
          </div>
        </div>

        <div class="flex flex-col flex-1 min-w-0 gap-0.5">
          <span
            class="text-[11px] font-extrabold tracking-[0.06em] uppercase"
            :style="{ color: isHumanOnline ? '#15803d' : '#dc2626' }"
          >
            {{ $t('TEAM_AVAILABILITY.HUMAN_TEAM_BADGE') }}
          </span>
          <span
            class="text-[16.5px] font-extrabold leading-[1.2] tracking-[-0.01em]"
            :style="styles.humanTitle"
          >
            {{
              isHumanOnline
                ? $t('TEAM_AVAILABILITY.HUMAN_ONLINE_TITLE')
                : $t('TEAM_AVAILABILITY.HUMAN_OFFLINE_TITLE')
            }}
          </span>
          <span
            class="text-[12.5px] font-medium leading-[1.35] mt-0.5"
            :style="styles.humanSubtitle"
          >
            {{
              isHumanOnline
                ? $t('TEAM_AVAILABILITY.HUMAN_ONLINE_SUBTITLE')
                : isOfflineBeforeOpeningToday
                  ? $t('TEAM_AVAILABILITY.HUMAN_OFFLINE_TODAY_SUBTITLE')
                  : $t('TEAM_AVAILABILITY.HUMAN_OFFLINE_SUBTITLE')
            }}
          </span>
        </div>
      </div>
    </div>

    <!-- Card 2: Leo • Atendimento Rápido (Sutil, sem objeção de IA) -->
    <div
      class="flex flex-col gap-2.5 p-4 rounded-[18px] bg-white dark:bg-n-solid-2 cursor-pointer transition-all duration-200 hover:shadow-md"
      :style="styles.leoCard"
      @click="startConversation"
    >
      <div class="flex items-start gap-2.5">
        <span
          class="inline-block rounded-full mt-1 shrink-0"
          :style="styles.leoDot"
        />
        <div class="flex flex-col flex-1 min-w-0 gap-1">
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-[14px] font-bold leading-[1.3] dark:text-n-slate-12"
              :style="styles.leoTitle"
            >
              {{ botCardTitle || $t('TEAM_AVAILABILITY.BOT_CARD_TITLE') }}
            </span>
            <span
              class="text-[10.5px] font-semibold px-2 py-0.5 rounded-full whitespace-nowrap shrink-0"
              :style="styles.leoPill"
            >
              {{
                isHumanOnline
                  ? $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_BADGE')
                  : $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_BADGE')
              }}
            </span>
          </div>

          <p
            v-if="isHumanOnline"
            class="text-[12.5px] leading-[1.45] m-0 dark:text-n-slate-11"
            :style="styles.leoDesc"
          >
            {{ $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_DESC_PREFIX') }}
            <strong
              class="font-semibold dark:text-n-slate-12"
              :style="styles.leoStrong"
            >
              {{ $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_HIGHLIGHT_1') }}
            </strong>
            <strong
              class="font-semibold dark:text-n-slate-12"
              :style="styles.leoStrong"
            >
              {{ $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_HIGHLIGHT_2') }}
            </strong>
            {{ $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_DESC_SUFFIX') }}
          </p>
          <p
            v-else
            class="text-[12.5px] leading-[1.45] m-0 dark:text-n-slate-11"
            :style="styles.leoDesc"
          >
            {{ $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_DESC_PREFIX') }}
            <strong
              class="font-semibold dark:text-n-slate-12"
              :style="styles.leoStrong"
            >
              {{ $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_HIGHLIGHT_1') }}
            </strong>
            <strong
              class="font-semibold dark:text-n-slate-12"
              :style="styles.leoStrong"
            >
              {{ $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_HIGHLIGHT_2') }}
            </strong>
            {{ $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_DESC_MID') }}
            <strong
              class="font-semibold dark:text-n-slate-12"
              :style="styles.leoStrong"
            >
              {{ $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_HIGHLIGHT_3') }}
            </strong>
          </p>
        </div>
      </div>

      <div class="h-px my-0.5" :style="styles.leoDivider" />

      <div class="flex items-center justify-between pt-0.5">
        <button
          type="button"
          class="inline-flex items-center gap-1 font-bold text-[14px] hover:opacity-80 transition-opacity p-0 bg-transparent border-0 cursor-pointer"
          :style="{ color: widgetColor || '#65a30d' }"
        >
          <span>
            {{
              hasConversation
                ? $t('CONTINUE_CONVERSATION')
                : $t('START_CONVERSATION')
            }}
          </span>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="mt-0.5"
          >
            <polyline points="9 18 15 12 9 6" />
          </svg>
        </button>

        <span class="text-[11.5px] font-medium" :style="styles.leoHint">
          {{
            isHumanOnline
              ? $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_FOOTER_HINT')
              : $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_FOOTER_HINT')
          }}
        </span>
      </div>
    </div>
  </div>
</template>
