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

const isHumanOnline = computed(() => {
  try {
    const now = new Date();
    const brStr = now.toLocaleString('en-US', {
      timeZone: 'America/Sao_Paulo',
    });
    const brDate = new Date(brStr);
    const hour = brDate.getHours();
    return hour >= 11 && hour < 22;
  } catch (e) {
    const localHour = new Date().getHours();
    return localHour >= 11 && localHour < 22;
  }
});
</script>

<template>
  <div class="flex flex-col gap-3 w-full">
    <!-- Card 1: Equipe Humana (Online / Offline por Horário de Brasília) -->
    <div
      class="flex items-center justify-between p-3.5 rounded-2xl cursor-pointer transition-all duration-200 hover:shadow-md select-none border"
      :class="
        isHumanOnline
          ? 'bg-green-50/80 border-green-200 dark:bg-green-950/20 dark:border-green-900/50'
          : 'bg-red-50/80 border-red-200 dark:bg-red-950/20 dark:border-red-900/50'
      "
      @click="startConversation"
    >
      <div class="flex items-center gap-3.5 flex-1 min-w-0">
        <!-- Ícone Dinâmico: Headset / Microfone com status -->
        <div v-if="isHumanOnline" class="shrink-0">
          <div
            class="w-12 h-12 rounded-full bg-green-600 flex items-center justify-center shadow-md relative"
          >
            <svg
              width="26"
              height="26"
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
            <span class="absolute -top-0.5 -right-0.5 flex h-3 w-3">
              <span
                class="absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75 animate-ping"
              />
              <span
                class="relative inline-flex rounded-full h-3 w-3 bg-green-500 border-2 border-white"
              />
            </span>
          </div>
        </div>

        <div v-else class="shrink-0">
          <div
            class="w-12 h-12 rounded-full bg-red-600 flex items-center justify-center shadow-md relative"
          >
            <svg
              width="26"
              height="26"
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
              class="absolute bottom-0 right-0 bg-white rounded-full w-4 h-4 flex items-center justify-center shadow-xs"
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

        <div class="flex flex-col flex-1 min-w-0 pr-1">
          <span
            class="text-[11px] font-bold tracking-wider uppercase"
            :class="isHumanOnline ? 'text-green-600' : 'text-red-600'"
          >
            {{ $t('TEAM_AVAILABILITY.HUMAN_TEAM_BADGE') }}
          </span>
          <span
            class="text-base font-extrabold text-slate-900 dark:text-white leading-tight tracking-tight"
          >
            {{
              isHumanOnline
                ? $t('TEAM_AVAILABILITY.HUMAN_ONLINE_TITLE')
                : $t('TEAM_AVAILABILITY.HUMAN_OFFLINE_TITLE')
            }}
          </span>
          <span
            class="text-xs text-slate-500 dark:text-slate-400 font-medium leading-snug mt-0.5"
          >
            {{
              isHumanOnline
                ? $t('TEAM_AVAILABILITY.HUMAN_ONLINE_SUBTITLE')
                : $t('TEAM_AVAILABILITY.HUMAN_OFFLINE_SUBTITLE')
            }}
          </span>
        </div>
      </div>

      <div class="shrink-0 text-slate-400 pl-1">
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <polyline points="9 18 15 12 9 6" />
        </svg>
      </div>
    </div>

    <!-- Card 2: Assistente Virtual Online 24h -->
    <div
      class="flex flex-col gap-2.5 p-4 rounded-2xl bg-white dark:bg-n-solid-2 shadow-xs border border-slate-100 dark:border-n-container"
    >
      <div class="flex items-start gap-2.5">
        <span
          class="inline-block w-2.5 h-2.5 rounded-full bg-emerald-500 mt-1 shrink-0 shadow-sm"
        />
        <div class="flex flex-col min-w-0">
          <span
            class="text-[13.5px] font-semibold text-slate-800 dark:text-n-slate-12 leading-tight"
          >
            {{ $t('TEAM_AVAILABILITY.BOT_CARD_TITLE') }}
          </span>
          <span class="text-xs text-slate-500 dark:text-n-slate-11 mt-0.5">
            {{
              isHumanOnline
                ? $t('TEAM_AVAILABILITY.BOT_CARD_ONLINE_SUBTITLE')
                : $t('TEAM_AVAILABILITY.BOT_CARD_OFFLINE_SUBTITLE')
            }}
          </span>
        </div>
      </div>

      <button
        class="mt-1 inline-flex items-center gap-1.5 font-semibold text-sm hover:opacity-80 transition-opacity"
        :style="{ color: widgetColor }"
        @click="startConversation"
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
    </div>
  </div>
</template>
