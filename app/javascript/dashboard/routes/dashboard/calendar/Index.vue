<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import CalendarAPI from 'dashboard/api/calendar';
import ProfileBuilderTab from './ProfileBuilderTab.vue';
import BookingModal from './BookingModal.vue';

const route = useRoute();
const router = useRouter();

const schedules = ref([]);
const appointments = ref([]);
const stats = ref({
  total: 0,
  today_confirmed: 0,
  pending: 0,
  ai_booked: 0,
  public_booked: 0,
  no_show_rate: 0,
});
const googleOauthConfigured = ref(false);
const integrationHooksCount = ref(0);
const teamPublicUrl = ref('');
const loading = ref(true);

// Multi-professional filter ('all' or schedule.id)
const selectedScheduleId = ref('all');
const showScheduleSwitcherDropdown = ref(false);
const activeMainTab = ref('calendar'); // 'calendar' | 'ai_bookings' | 'profile_builder'
const viewMode = ref('week'); // 'week' | 'list'
const searchQuery = ref('');

// Modal state
const showBookingModal = ref(false);
const editingAppointment = ref(null);

// Week navigation anchor (Monday of active week)
const getMonday = d => {
  const date = new Date(d);
  const day = date.getDay();
  const diff = date.getDate() - day + (day === 0 ? -6 : 1);
  date.setDate(diff);
  date.setHours(0, 0, 0, 0);
  return date;
};

const currentWeekStart = ref(getMonday(new Date()));

const formatIsoDate = d => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const weekDays = computed(() => {
  const names = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
  const months = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  const todayIso = formatIsoDate(new Date());
  const list = [];
  for (let i = 0; i < 6; i += 1) {
    const d = new Date(currentWeekStart.value);
    d.setDate(d.getDate() + i);
    const iso = formatIsoDate(d);
    list.push({
      iso,
      dayName: names[d.getDay()],
      dayNum: String(d.getDate()).padStart(2, '0'),
      monthName: months[d.getMonth()],
      isToday: iso === todayIso,
    });
  }
  return list;
});

const weekRangeLabel = computed(() => {
  if (!weekDays.value.length) return '';
  const first = weekDays.value[0];
  const last = weekDays.value[weekDays.value.length - 1];
  return `${first.dayNum} ${first.monthName} — ${last.dayNum} ${last.monthName}, ${currentWeekStart.value.getFullYear()}`;
});

const selectedSchedule = computed(() => {
  if (selectedScheduleId.value === 'all') return null;
  return (
    schedules.value.find(
      s => Number(s.id) === Number(selectedScheduleId.value)
    ) || null
  );
});

const activeProfessionalDisplayName = computed(() => {
  if (!schedules.value.length) return 'Nenhum Especialista Cadastrado';
  if (selectedScheduleId.value === 'all' || !selectedSchedule.value) {
    return `Todos os Profissionais (${schedules.value.length})`;
  }
  return selectedSchedule.value.name;
});

const activePublicLink = computed(() => {
  if (selectedSchedule.value?.public_booking_url) {
    return selectedSchedule.value.public_booking_url;
  }
  return (
    teamPublicUrl.value ||
    schedules.value[0]?.public_booking_url ||
    `${window.location.origin}/agendar/samuel-vicente`
  );
});

const googleConnectedCount = computed(
  () => schedules.value.filter(s => s.google_connected).length
);

const aiConversionPercent = computed(() => {
  const total = appointments.value.length || 1;
  const aiCount =
    stats.value.ai_booked ||
    appointments.value.filter(a => a.source === 'ai_agent').length;
  return Math.min(100, Math.round((aiCount / total) * 100));
});

const activeWeeklyHoursCount = computed(() => {
  const target = selectedSchedule.value || schedules.value[0];
  if (!target?.weekly_hours) return 38;
  let mins = 0;
  Object.values(target.weekly_hours).forEach(arr => {
    (arr || []).forEach(iv => {
      if (!iv.start || !iv.end) return;
      const [sh, sm] = iv.start.split(':').map(Number);
      const [eh, em] = iv.end.split(':').map(Number);
      const d = eh * 60 + em - (sh * 60 + sm);
      if (d > 0) mins += d;
    });
  });
  return Math.round(mins / 60);
});

const filteredAppointments = computed(() => {
  return appointments.value.filter(appt => {
    if (appt.status === 'cancelled') return false;
    if (
      selectedScheduleId.value !== 'all' &&
      Number(appt.calendar_schedule_id) !== Number(selectedScheduleId.value)
    ) {
      return false;
    }
    if (activeMainTab.value === 'ai_bookings' && appt.source !== 'ai_agent') {
      return false;
    }
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase();
      const match =
        appt.title?.toLowerCase().includes(q) ||
        appt.customer_name?.toLowerCase().includes(q) ||
        appt.customer_email?.toLowerCase().includes(q) ||
        appt.customer_phone?.toLowerCase().includes(q) ||
        appt.professional_name?.toLowerCase().includes(q);
      if (!match) return false;
    }
    return true;
  });
});

const appointmentsForDay = isoDate => {
  return filteredAppointments.value.filter(a => a.date === isoDate);
};

const loadAllData = async () => {
  try {
    loading.value = true;
    const [schedRes, apptRes] = await Promise.all([
      CalendarAPI.getSchedules(),
      CalendarAPI.getAppointments(),
    ]);
    schedules.value = schedRes.data?.schedules || [];
    googleOauthConfigured.value = !!schedRes.data?.google_oauth_configured;
    integrationHooksCount.value = schedRes.data?.integration_hooks_count || 0;
    teamPublicUrl.value = schedRes.data?.team_public_url || '';
    appointments.value = apptRes.data?.appointments || [];
    stats.value = apptRes.data?.stats || stats.value;
  } catch {
    useAlert('Erro ao carregar dados de agendamentos.');
  } finally {
    loading.value = false;
  }
};

const selectScheduleFromDropdown = id => {
  selectedScheduleId.value = id;
  showScheduleSwitcherDropdown.value = false;
};

const shiftWeek = delta => {
  const next = new Date(currentWeekStart.value);
  next.setDate(next.getDate() + delta * 7);
  currentWeekStart.value = next;
};

const goToToday = () => {
  currentWeekStart.value = getMonday(new Date());
};

const openNewBooking = () => {
  editingAppointment.value = null;
  showBookingModal.value = true;
};

const openEditBooking = appt => {
  editingAppointment.value = appt;
  showBookingModal.value = true;
};

const copyPublicLink = () => {
  navigator.clipboard?.writeText(activePublicLink.value);
  useAlert('Link público copiado!');
};

const goToIntegrationsHub = () => {
  const accountId = route.params.accountId || 1;
  router.push(
    `/app/accounts/${accountId}/settings/integrations/google_calendar`
  );
};

const handleProfileSaved = async savedId => {
  await loadAllData();
  if (savedId) {
    selectedScheduleId.value = savedId;
  }
};

const sourceBadge = source => {
  if (source === 'ai_agent') {
    return {
      label: 'Agente IA',
      cls: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
    };
  }
  if (source === 'public_link') {
    return {
      label: 'Página Pública',
      cls: 'bg-cyan-500/20 text-cyan-300 border-cyan-500/30',
    };
  }
  return {
    label: 'Painel',
    cls: 'bg-slate-800 text-slate-300 border-slate-700',
  };
};

onMounted(() => {
  loadAllData();
  if (route.query.google_connected) {
    useAlert('Agenda sincronizada via OAuth 2.0 com sucesso!');
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-[#04090D]">
    <!-- Top Header Executivo com Multi-Profissional Switcher -->
    <header
      class="sticky top-0 z-20 px-4 sm:px-6 border-b border-[#132631] bg-[#04090D]"
    >
      <div class="w-full">
        <div
          class="flex flex-col lg:flex-row items-start lg:items-center justify-between w-full py-3.5 lg:py-0 lg:h-20 gap-3"
        >
          <!-- Esquerda: Seletor de Especialistas -->
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shrink-0 shadow-sm"
            >
              <span class="i-lucide-calendar-check-2 size-5" />
            </div>

            <div class="flex flex-col min-w-0 relative">
              <div class="flex flex-wrap items-center gap-2">
                <span
                  class="text-base sm:text-xl font-semibold truncate text-[#F8FAFC] cursor-pointer"
                  @click="
                    showScheduleSwitcherDropdown = !showScheduleSwitcherDropdown
                  "
                >
                  {{ activeProfessionalDisplayName }}
                </span>

                <div>
                  <OnClickOutside
                    @trigger="showScheduleSwitcherDropdown = false"
                  >
                    <button
                      type="button"
                      class="px-2.5 py-1 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs text-slate-200 flex items-center gap-1 transition"
                      @click="
                        showScheduleSwitcherDropdown =
                          !showScheduleSwitcherDropdown
                      "
                    >
                      <span>Alternar</span>
                      <span class="i-lucide-chevron-down size-3.5" />
                    </button>

                    <!-- Popover Dropdown Multi-Profissional -->
                    <div
                      v-if="showScheduleSwitcherDropdown"
                      class="bg-[#081218]/95 backdrop-blur-xl border border-[#162936] w-[calc(100vw-4.5rem)] max-w-80 sm:w-96 sm:max-w-none rounded-2xl p-4 absolute z-50 left-0 top-full mt-2 flex flex-col gap-2.5 shadow-2xl"
                    >
                      <div
                        class="flex items-center justify-between gap-2 pb-2.5 border-b border-[#132631]"
                      >
                        <div>
                          <h5 class="text-sm font-semibold text-[#F8FAFC]">
                            Alternar Especialista / Agenda
                          </h5>
                          <span class="text-[11px] text-slate-400">
                            {{ schedules.length }} agendas ativas ({{
                              googleConnectedCount
                            }}
                            sincronizadas)
                          </span>
                        </div>
                        <button
                          type="button"
                          class="px-2.5 py-1 rounded-lg bg-[#0F1E29] border border-[#1C3545] text-[11px] text-emerald-400 font-semibold"
                          @click="
                            activeMainTab = 'profile_builder';
                            showScheduleSwitcherDropdown = false;
                          "
                        >
                          + Especialista
                        </button>
                      </div>

                      <div
                        class="flex flex-col gap-1.5 max-h-72 overflow-y-auto"
                      >
                        <button
                          type="button"
                          class="flex items-center justify-between px-3 py-2 rounded-xl border text-left transition"
                          :class="
                            selectedScheduleId === 'all'
                              ? 'bg-emerald-500/15 border-emerald-500/40 text-white'
                              : 'bg-transparent border-transparent hover:bg-[#0D1B24] text-slate-200'
                          "
                          @click="selectScheduleFromDropdown('all')"
                        >
                          <div class="flex items-center gap-2.5 min-w-0">
                            <span
                              class="w-7 h-7 rounded-lg bg-emerald-500/20 flex items-center justify-center text-emerald-400 shrink-0"
                            >
                              <span class="i-lucide-layers size-4" />
                            </span>
                            <div class="min-w-0">
                              <div class="text-xs font-semibold truncate">
                                Todos os Profissionais ({{ schedules.length }})
                              </div>
                              <div class="text-[10px] text-slate-400 truncate">
                                Visão consolidada da operação Meu Super Chat
                              </div>
                            </div>
                          </div>
                          <span
                            v-if="selectedScheduleId === 'all'"
                            class="i-lucide-check size-3.5 text-emerald-400 shrink-0"
                          />
                        </button>

                        <button
                          v-for="sched in schedules"
                          :key="sched.id"
                          type="button"
                          class="flex items-center justify-between px-3 py-2 rounded-xl border text-left transition"
                          :class="
                            Number(selectedScheduleId) === Number(sched.id)
                              ? 'bg-emerald-500/15 border-emerald-500/40 text-white'
                              : 'bg-transparent border-transparent hover:bg-[#0D1B24] text-slate-200'
                          "
                          @click="selectScheduleFromDropdown(sched.id)"
                        >
                          <div class="flex items-center gap-2.5 min-w-0">
                            <span
                              class="w-7 h-7 rounded-full flex items-center justify-center text-[11px] font-bold text-[#04090D] shrink-0"
                              :style="{
                                backgroundColor: sched.color || '#10b981',
                              }"
                            >
                              {{
                                sched.name
                                  .split(' ')
                                  .map(n => n[0])
                                  .slice(0, 2)
                                  .join('')
                              }}
                            </span>
                            <div class="min-w-0">
                              <div class="text-xs font-medium truncate">
                                {{ sched.name }}
                                <span
                                  v-if="sched.role_title"
                                  class="text-slate-400 font-normal"
                                >
                                  • {{ sched.role_title }}
                                </span>
                              </div>
                              <div
                                class="text-[10px] text-slate-400 font-mono truncate"
                              >
                                /agendar/{{ sched.slug }}
                                <span
                                  v-if="sched.google_connected"
                                  class="text-emerald-400"
                                >
                                  • Sync Ativo
                                </span>
                              </div>
                            </div>
                          </div>
                          <span
                            class="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 shrink-0 ml-2"
                          >
                            {{ sched.today_appointments_count || 0 }} hoje
                          </span>
                        </button>
                      </div>
                    </div>
                  </OnClickOutside>
                </div>

                <span
                  class="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-medium bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                >
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  Agenda & IA Ativos
                </span>
              </div>
              <span class="text-xs text-slate-400 truncate">
                Agendamento Inteligente sincronizado em tempo real com Agente IA
                no WhatsApp e Páginas Exclusivas Meu Super Chat
              </span>
            </div>
          </div>

          <!-- Direita: Link Público + Hub OAuth + Configurar + Novo Agendamento -->
          <div class="flex flex-wrap items-center gap-2 w-full lg:w-auto">
            <div
              class="hidden xl:flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#081218] border border-[#162936] text-xs"
            >
              <span class="i-lucide-link-2 size-3.5 text-emerald-400" />
              <a
                :href="activePublicLink"
                target="_blank"
                rel="noopener noreferrer"
                class="font-mono text-emerald-400 hover:underline truncate max-w-[230px]"
              >
                {{ activePublicLink.replace(/^https?:\/\//, '') }}
              </a>
              <button
                type="button"
                class="px-2 py-0.5 rounded-md bg-emerald-500/20 text-emerald-300 text-[10px] font-semibold"
                @click="copyPublicLink"
              >
                Copiar
              </button>
            </div>

            <button
              type="button"
              class="px-3 py-2 rounded-xl bg-emerald-500/15 border border-emerald-500/40 hover:bg-emerald-500/25 text-xs font-semibold text-emerald-300 flex items-center gap-1.5 transition"
              title="Abrir Onboarding em Vídeo & Autenticação OAuth 2.0"
              @click="goToIntegrationsHub"
            >
              <span class="i-lucide-play-circle size-3.5 text-emerald-400" />
              <span class="hidden sm:inline">Autenticar Agenda (OAuth)</span>
            </button>

            <button
              type="button"
              class="px-3 py-2 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs font-medium text-slate-200 flex items-center gap-1.5 transition"
              @click="
                activeMainTab =
                  activeMainTab === 'profile_builder'
                    ? 'calendar'
                    : 'profile_builder'
              "
            >
              <span
                class="i-lucide-sliders-horizontal size-3.5 text-emerald-400"
              />
              <span>
                {{
                  activeMainTab === 'profile_builder'
                    ? 'Voltar ao Calendário'
                    : 'Meu Perfil & Horários'
                }}
              </span>
            </button>

            <button
              type="button"
              class="px-3.5 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs flex items-center gap-1.5 shadow-md transition"
              @click="openNewBooking"
            >
              <span class="i-lucide-plus size-4" />
              <span>Novo Agendamento</span>
            </button>
          </div>
        </div>

        <!-- Sub-barra de Abas + Indicadores -->
        <div
          class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 py-2.5 border-t border-[#132631] text-xs"
        >
          <div class="flex flex-wrap items-center gap-5">
            <button
              type="button"
              class="pb-1.5 font-medium transition flex items-center gap-1.5 border-b-2"
              :class="
                activeMainTab === 'calendar'
                  ? 'text-emerald-400 border-emerald-400 font-semibold'
                  : 'text-slate-400 border-transparent hover:text-slate-200'
              "
              @click="activeMainTab = 'calendar'"
            >
              <span class="i-lucide-calendar size-3.5" />
              <span>Calendário Geral</span>
              <span
                class="px-1.5 py-0.2 rounded-full bg-emerald-500/20 text-emerald-300 text-[10px]"
              >
                {{ appointments.length }}
              </span>
            </button>

            <button
              type="button"
              class="pb-1.5 font-medium transition flex items-center gap-1.5 border-b-2"
              :class="
                activeMainTab === 'ai_bookings'
                  ? 'text-emerald-400 border-emerald-400 font-semibold'
                  : 'text-slate-400 border-transparent hover:text-slate-200'
              "
              @click="activeMainTab = 'ai_bookings'"
            >
              <span class="i-lucide-sparkles size-3.5" />
              <span>Agendados pela IA</span>
              <span
                class="px-1.5 py-0.2 rounded-full bg-slate-800 text-slate-300 text-[10px]"
              >
                {{ stats.ai_booked }}
              </span>
            </button>

            <button
              type="button"
              class="pb-1.5 font-medium transition flex items-center gap-1.5 border-b-2"
              :class="
                activeMainTab === 'profile_builder'
                  ? 'text-emerald-400 border-emerald-400 font-semibold'
                  : 'text-slate-400 border-transparent hover:text-slate-200'
              "
              @click="activeMainTab = 'profile_builder'"
            >
              <span class="i-lucide-user-Check size-3.5" />
              <span>Perfil Público & Horários</span>
            </button>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <span class="text-slate-400 text-[11px]">
              ● Hoje:
              <strong class="text-emerald-400">{{
                stats.today_confirmed
              }}</strong>
            </span>
            <span class="text-slate-400 text-[11px]">
              ● Página Pública:
              <strong class="text-cyan-400">{{ stats.public_booked }}</strong>
            </span>

            <div
              v-if="activeMainTab !== 'profile_builder'"
              class="flex rounded-xl bg-[#081218] border border-[#162936] p-0.5"
            >
              <button
                type="button"
                class="px-2.5 py-1 rounded-lg text-[11px] transition"
                :class="
                  viewMode === 'week'
                    ? 'bg-[#10B981] text-[#04090D] font-semibold'
                    : 'text-slate-400'
                "
                @click="viewMode = 'week'"
              >
                Semana
              </button>
              <button
                type="button"
                class="px-2.5 py-1 rounded-lg text-[11px] transition"
                :class="
                  viewMode === 'list'
                    ? 'bg-[#10B981] text-[#04090D] font-semibold'
                    : 'text-slate-400'
                "
                @click="viewMode = 'list'"
              >
                Lista
              </button>
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Conteúdo Principal -->
    <div class="flex-1 overflow-y-auto p-4 sm:p-6 flex flex-col gap-5">
      <!-- Faixa de 4 KPIs Executivos no Topo (Fiel ao GPT Image 2.5) -->
      <div
        class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3.5 shrink-0"
      >
        <div
          class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between shadow-sm"
        >
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
            >
              <span class="i-lucide-calendar-check size-5" />
            </div>
            <div>
              <span class="text-[11px] text-slate-400 font-medium">
                Agendamentos Hoje
              </span>
              <div
                class="text-xl font-bold text-[#F8FAFC] leading-tight mt-0.5"
              >
                {{ stats.today_confirmed || appointments.length }}
              </div>
            </div>
          </div>
          <div class="text-right">
            <span class="text-[11px] font-semibold text-emerald-400">
              ↗ +100%
            </span>
            <div class="text-[10px] text-slate-500">sincronizados</div>
          </div>
        </div>

        <div
          class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between shadow-sm"
        >
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
            >
              <span class="i-lucide-zap size-5" />
            </div>
            <div>
              <span class="text-[11px] text-slate-400 font-medium">
                Gerados pela IA
              </span>
              <div
                class="text-xl font-bold text-[#F8FAFC] leading-tight mt-0.5"
              >
                {{ aiConversionPercent }}%
              </div>
            </div>
          </div>
          <div class="text-right">
            <span class="text-[11px] font-semibold text-emerald-400">
              {{ stats.ai_booked }} sessões
            </span>
            <div class="text-[10px] text-slate-500">via WhatsApp IA</div>
          </div>
        </div>

        <div
          class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between shadow-sm"
        >
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
            >
              <span class="i-lucide-clock size-5" />
            </div>
            <div>
              <span class="text-[11px] text-slate-400 font-medium">
                Turnos Ativos
              </span>
              <div
                class="text-xl font-bold text-[#F8FAFC] leading-tight mt-0.5"
              >
                {{ activeWeeklyHoursCount }}h/sem
              </div>
            </div>
          </div>
          <div class="text-right">
            <span class="text-[11px] font-semibold text-emerald-400">
              {{ schedules.length }} agendas
            </span>
            <div class="text-[10px] text-slate-500">em operação</div>
          </div>
        </div>

        <div
          class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between shadow-sm"
        >
          <div class="flex items-center gap-3">
            <div
              class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
            >
              <span class="i-lucide-globe size-5" />
            </div>
            <div>
              <span class="text-[11px] text-slate-400 font-medium">
                Status da Página
              </span>
              <div
                class="text-xl font-bold text-[#F8FAFC] leading-tight mt-0.5 flex items-center gap-1.5"
              >
                <span>Online</span>
                <span class="w-2 h-2 rounded-full bg-emerald-400" />
              </div>
            </div>
          </div>
          <div class="text-right">
            <a
              :href="activePublicLink"
              target="_blank"
              rel="noopener noreferrer"
              class="text-[11px] font-semibold text-emerald-400 hover:underline"
            >
              Testar Link →
            </a>
            <div class="text-[10px] text-slate-500">reserva instantânea</div>
          </div>
        </div>
      </div>

      <!-- ABA 3: Construtor de Perfil & Horários Meu Super Chat -->
      <ProfileBuilderTab
        v-if="activeMainTab === 'profile_builder'"
        :schedules="schedules"
        :selected-schedule-id="selectedScheduleId"
        :google-oauth-configured="googleOauthConfigured"
        :integration-hooks-count="integrationHooksCount"
        @saved="handleProfileSaved"
        @select-schedule="id => (selectedScheduleId = id)"
      />

      <!-- ABAS 1 & 2: Calendário / Agendamentos -->
      <div v-else class="flex flex-col gap-4 flex-1">
        <!-- Barra de Pílulas de Profissionais + Navegação de Datas -->
        <div
          class="flex flex-col md:flex-row md:items-center justify-between gap-3 bg-[#081218] border border-[#142633] rounded-2xl px-4 py-3"
        >
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-xs text-slate-400 mr-1">Especialista:</span>
            <button
              type="button"
              class="px-3 py-1.5 rounded-xl text-xs font-medium border transition"
              :class="
                selectedScheduleId === 'all'
                  ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300'
                  : 'bg-[#0A151D] border-[#162936] text-slate-300'
              "
              @click="selectedScheduleId = 'all'"
            >
              Todos ({{ schedules.length }})
            </button>

            <button
              v-for="sched in schedules"
              :key="sched.id"
              type="button"
              class="px-3 py-1.5 rounded-xl text-xs border transition flex items-center gap-1.5"
              :class="
                Number(selectedScheduleId) === Number(sched.id)
                  ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300 font-medium'
                  : 'bg-[#0A151D] border-[#162936] text-slate-300 hover:border-slate-600'
              "
              @click="selectedScheduleId = sched.id"
            >
              <span
                class="w-2 h-2 rounded-full shrink-0"
                :style="{ backgroundColor: sched.color || '#10b981' }"
              />
              <span class="truncate max-w-[150px]">{{ sched.name }}</span>
            </button>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar cliente, título ou telefone..."
              class="px-3.5 py-1.5 rounded-xl bg-[#04090D] border border-[#162936] text-xs text-white outline-none w-full sm:w-56 focus:border-emerald-500/60"
            />
            <div class="flex items-center gap-1.5 text-xs text-slate-200">
              <button
                type="button"
                class="px-2.5 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 flex items-center justify-center"
                @click="shiftWeek(-1)"
              >
                <span class="i-lucide-chevron-left size-3.5" />
              </button>
              <button
                type="button"
                class="px-2.5 py-1 rounded-lg bg-[#0A151D] border border-[#162936] text-[11px] text-emerald-400 font-medium"
                @click="goToToday"
              >
                Hoje
              </button>
              <span class="font-semibold text-white px-1">
                {{ weekRangeLabel }}
              </span>
              <button
                type="button"
                class="px-2.5 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 flex items-center justify-center"
                @click="shiftWeek(1)"
              >
                <span class="i-lucide-chevron-right size-3.5" />
              </button>
            </div>
          </div>
        </div>

        <!-- Visão em Grade Semanal -->
        <div
          v-if="viewMode === 'week'"
          class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-6 gap-3 flex-1"
        >
          <div
            v-for="day in weekDays"
            :key="day.iso"
            class="rounded-2xl p-3.5 flex flex-col gap-2.5 min-h-[260px] transition"
            :class="
              day.isToday
                ? 'bg-[#0A151D] border-2 border-emerald-500/40 shadow-lg'
                : 'bg-[#081218] border border-[#142633]'
            "
          >
            <div
              class="flex items-center justify-between pb-2 border-b"
              :class="
                day.isToday ? 'border-emerald-500/30' : 'border-[#132631]'
              "
            >
              <span
                class="text-xs font-semibold"
                :class="day.isToday ? 'text-emerald-400' : 'text-slate-300'"
              >
                {{ day.dayName }} • {{ day.dayNum }} {{ day.monthName }}
              </span>
              <span
                v-if="day.isToday"
                class="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500 text-[#04090D] font-bold"
              >
                HOJE
              </span>
              <span v-else class="text-[11px] text-slate-500">
                {{ appointmentsForDay(day.iso).length }} agend.
              </span>
            </div>

            <div
              v-if="appointmentsForDay(day.iso).length === 0"
              class="flex-1 flex flex-col items-center justify-center text-center py-6 text-slate-600 text-xs"
            >
              <span>Agenda livre</span>
            </div>

            <div
              v-for="appt in appointmentsForDay(day.iso)"
              :key="appt.id"
              class="p-3 rounded-xl bg-[#04090D] border border-[#162936] hover:border-emerald-500/50 transition cursor-pointer flex flex-col gap-1 border-l-4 shadow-sm"
              :style="{
                borderLeftColor: appt.professional_color || '#10b981',
              }"
              @click="openEditBooking(appt)"
            >
              <div class="flex items-center justify-between gap-1">
                <span class="text-[11px] font-bold text-emerald-300 font-mono">
                  {{ appt.start_time }} - {{ appt.end_time }}
                </span>
                <span
                  class="text-[9px] px-1.5 py-0.5 rounded border"
                  :class="sourceBadge(appt.source).cls"
                >
                  {{ sourceBadge(appt.source).label }}
                </span>
              </div>
              <div class="text-xs font-semibold text-white truncate">
                {{ appt.title }}
              </div>
              <div class="text-[11px] text-slate-400 truncate">
                Cliente: {{ appt.customer_name }}
              </div>
              <div
                class="text-[10px] font-medium truncate flex items-center justify-between pt-0.5"
                :style="{ color: appt.professional_color || '#10b981' }"
              >
                <span class="truncate flex items-center gap-1">
                  <span class="i-lucide-user size-3 shrink-0" />
                  <span class="truncate">{{ appt.professional_name }}</span>
                </span>
                <span
                  v-if="appt.meeting_url"
                  class="text-emerald-400 flex items-center gap-0.5 shrink-0"
                >
                  <span>Sala</span>
                  <span class="i-lucide-video size-2.5" />
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Visão em Lista Completa -->
        <div
          v-else
          class="bg-[#081218] border border-[#142633] rounded-2xl overflow-hidden"
        >
          <div
            v-if="filteredAppointments.length === 0"
            class="p-8 text-center text-slate-400 text-sm"
          >
            Nenhum agendamento encontrado para o filtro selecionado.
          </div>
          <div v-else class="divide-y divide-[#132631]">
            <div
              v-for="appt in filteredAppointments"
              :key="appt.id"
              class="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-[#0A151D] cursor-pointer transition"
              @click="openEditBooking(appt)"
            >
              <div class="flex items-start gap-3 min-w-0">
                <div
                  class="w-2.5 h-10 rounded-full shrink-0 mt-0.5"
                  :style="{
                    backgroundColor: appt.professional_color || '#10b981',
                  }"
                />
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="text-sm font-semibold text-white">
                      {{ appt.title }}
                    </span>
                    <span
                      class="text-[10px] px-2 py-0.5 rounded border"
                      :class="sourceBadge(appt.source).cls"
                    >
                      {{ sourceBadge(appt.source).label }}
                    </span>
                  </div>
                  <div class="text-xs text-slate-400 mt-0.5">
                    Cliente:
                    <strong class="text-slate-200">{{
                      appt.customer_name
                    }}</strong>
                    <span v-if="appt.customer_phone">
                      • {{ appt.customer_phone }}
                    </span>
                    <span v-if="appt.customer_email">
                      • {{ appt.customer_email }}
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-3 shrink-0 text-xs">
                <div class="text-right">
                  <div class="font-mono font-semibold text-emerald-400">
                    {{ appt.date }} • {{ appt.start_time }} -
                    {{ appt.end_time }}
                  </div>
                  <div class="text-[11px] text-slate-400">
                    Especialista: {{ appt.professional_name }}
                  </div>
                </div>
                <a
                  v-if="appt.meeting_url"
                  :href="appt.meeting_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="px-3 py-1.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 font-semibold text-xs"
                  @click.stop
                >
                  Abrir Sala de Vídeo
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Criar / Editar Agendamento -->
    <BookingModal
      :show="showBookingModal"
      :schedules="schedules"
      :default-schedule-id="selectedScheduleId"
      :appointment="editingAppointment"
      @close="showBookingModal = false"
      @saved="loadAllData"
    />
  </section>
</template>
