<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import CalendarAPI from 'dashboard/api/calendar';

const props = defineProps({
  schedules: {
    type: Array,
    default: () => [],
  },
  selectedScheduleId: {
    type: [String, Number],
    default: 'all',
  },
  integrationHooksCount: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['saved', 'selectSchedule']);

const route = useRoute();
const router = useRouter();

const WEEKDAYS = [
  { key: '1', label: 'Segunda-feira', short: 'Seg' },
  { key: '2', label: 'Terça-feira', short: 'Ter' },
  { key: '3', label: 'Quarta-feira', short: 'Qua' },
  { key: '4', label: 'Quinta-feira', short: 'Qui' },
  { key: '5', label: 'Sexta-feira', short: 'Sex' },
  { key: '6', label: 'Sábado', short: 'Sáb' },
  { key: '0', label: 'Domingo', short: 'Dom' },
];

const COLORS = [
  '#10b981',
  '#06b6d4',
  '#8b5cf6',
  '#f59e0b',
  '#ec4899',
  '#3b82f6',
];

const isCreatingNew = ref(false);
const saving = ref(false);
const savingService = ref(false);
const syncingNow = ref(false);
const showNewServiceForm = ref(false);

const activeSchedule = computed(() => {
  if (isCreatingNew.value) return null;
  if (props.selectedScheduleId && props.selectedScheduleId !== 'all') {
    return (
      props.schedules.find(
        s => Number(s.id) === Number(props.selectedScheduleId)
      ) ||
      props.schedules[0] ||
      null
    );
  }
  return props.schedules[0] || null;
});

const buildDefaultHours = () => ({
  1: [
    { start: '09:00', end: '12:00' },
    { start: '14:00', end: '18:30' },
  ],
  2: [
    { start: '09:00', end: '12:00' },
    { start: '14:00', end: '18:30' },
  ],
  3: [
    { start: '09:00', end: '12:00' },
    { start: '14:00', end: '18:30' },
  ],
  4: [
    { start: '09:00', end: '12:00' },
    { start: '14:00', end: '18:30' },
  ],
  5: [
    { start: '09:00', end: '12:00' },
    { start: '14:00', end: '17:30' },
  ],
  6: [],
  0: [],
});

const form = ref({
  name: '',
  slug: '',
  role_title: '',
  bio: '',
  color: '#10b981',
  timezone: 'America/Sao_Paulo',
  ai_bookable: true,
  active: true,
  google_email: '',
  google_calendar_id: 'primary',
  google_connected: false,
  slot_duration_minutes: 30,
  buffer_before_minutes: 0,
  buffer_after_minutes: 15,
  minimum_notice_minutes: 60,
  max_days_ahead: 30,
  weekly_hours: buildDefaultHours(),
});

const newService = ref({
  title: '',
  duration_minutes: 30,
  buffer_minutes: 15,
  location_type: 'google_meet',
  description: '',
});

const syncFormFromSchedule = sched => {
  if (!sched) {
    form.value = {
      name: '',
      slug: '',
      role_title: 'Especialista em Automação & IA',
      bio: 'Agende seu horário diretamente na minha agenda inteligente do Meu Super Chat.',
      color: '#10b981',
      timezone: 'America/Sao_Paulo',
      ai_bookable: true,
      active: true,
      google_email: '',
      google_calendar_id: 'primary',
      google_connected: false,
      slot_duration_minutes: 30,
      buffer_before_minutes: 0,
      buffer_after_minutes: 15,
      minimum_notice_minutes: 60,
      max_days_ahead: 30,
      weekly_hours: buildDefaultHours(),
    };
    return;
  }

  const normalizedHours = buildDefaultHours();
  Object.keys(normalizedHours).forEach(k => {
    if (Array.isArray(sched.weekly_hours?.[k])) {
      normalizedHours[k] = JSON.parse(JSON.stringify(sched.weekly_hours[k]));
    }
  });

  form.value = {
    name: sched.name || '',
    slug: sched.slug || '',
    role_title: sched.role_title || '',
    bio: sched.bio || '',
    color: sched.color || '#10b981',
    timezone: sched.timezone || 'America/Sao_Paulo',
    ai_bookable: sched.ai_bookable ?? true,
    active: sched.active ?? true,
    google_email: sched.google_email || '',
    google_calendar_id: sched.google_calendar_id || 'primary',
    google_connected: sched.google_connected ?? false,
    slot_duration_minutes: sched.slot_duration_minutes || 30,
    buffer_before_minutes: sched.buffer_before_minutes || 0,
    buffer_after_minutes: sched.buffer_after_minutes || 15,
    minimum_notice_minutes: sched.minimum_notice_minutes || 60,
    max_days_ahead: sched.max_days_ahead || 30,
    weekly_hours: normalizedHours,
  };
};

watch(
  activeSchedule,
  sched => {
    syncFormFromSchedule(sched);
  },
  { immediate: true }
);

const totalWeeklyHours = computed(() => {
  let totalMinutes = 0;
  Object.values(form.value.weekly_hours || {}).forEach(intervals => {
    (intervals || []).forEach(iv => {
      if (!iv.start || !iv.end) return;
      const [sh, sm] = iv.start.split(':').map(Number);
      const [eh, em] = iv.end.split(':').map(Number);
      const diff = eh * 60 + em - (sh * 60 + sm);
      if (diff > 0) totalMinutes += diff;
    });
  });
  return Math.round((totalMinutes / 60) * 10) / 10;
});

const initials = computed(() => {
  const n = form.value.name || 'MS';
  return n
    .split(' ')
    .filter(Boolean)
    .map(w => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
});

const startNewProfessional = () => {
  isCreatingNew.value = true;
  syncFormFromSchedule(null);
};

const selectExistingProfessional = id => {
  isCreatingNew.value = false;
  emit('selectSchedule', id);
};

const isDayEnabled = key => {
  return (form.value.weekly_hours[key] || []).length > 0;
};

const toggleDay = key => {
  if (isDayEnabled(key)) {
    form.value.weekly_hours[key] = [];
  } else {
    form.value.weekly_hours[key] = [
      { start: '09:00', end: '12:00' },
      { start: '14:00', end: '18:00' },
    ];
  }
};

const addInterval = key => {
  if (!form.value.weekly_hours[key]) form.value.weekly_hours[key] = [];
  form.value.weekly_hours[key].push({ start: '14:00', end: '18:00' });
};

const removeInterval = (key, idx) => {
  form.value.weekly_hours[key].splice(idx, 1);
};

const saveProfile = async () => {
  if (!form.value.name.trim()) {
    useAlert('Informe o nome do profissional.');
    return;
  }
  try {
    saving.value = true;
    let res;
    if (isCreatingNew.value || !activeSchedule.value) {
      res = await CalendarAPI.createSchedule(form.value);
      isCreatingNew.value = false;
      useAlert('Novo profissional e página pública criados com sucesso!');
      emit('saved', res.data?.id);
    } else {
      res = await CalendarAPI.updateSchedule(
        activeSchedule.value.id,
        form.value
      );
      useAlert('Perfil, disponibilidade e configurações salvos!');
      emit('saved', res.data?.id);
    }
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Erro ao salvar perfil de agenda.');
  } finally {
    saving.value = false;
  }
};

const syncAgendaNow = async () => {
  if (!activeSchedule.value) return;
  try {
    syncingNow.value = true;
    await CalendarAPI.updateSchedule(activeSchedule.value.id, {
      ...form.value,
      google_connected: true,
    });
    useAlert('Disponibilidade e eventos sincronizados em tempo real!');
    emit('saved', activeSchedule.value.id);
  } catch {
    useAlert('Erro ao sincronizar agenda.');
  } finally {
    syncingNow.value = false;
  }
};

const disconnectGoogle = async () => {
  if (!activeSchedule.value) return;
  try {
    await CalendarAPI.disconnectGoogle(activeSchedule.value.id);
    useAlert('Sincronização externa desconectada.');
    emit('saved', activeSchedule.value.id);
  } catch {
    useAlert('Erro ao desconectar agenda.');
  }
};

const openIntegrationsHub = () => {
  const accountId =
    route.params.accountId || activeSchedule.value?.account_id || 1;
  router.push(
    `/app/accounts/${accountId}/settings/integrations/google_calendar`
  );
};

const addAppointmentType = async () => {
  if (!activeSchedule.value || !newService.value.title.trim()) {
    useAlert('Informe o título do tipo de atendimento.');
    return;
  }
  try {
    savingService.value = true;
    await CalendarAPI.upsertAppointmentType({
      appointment_type: {
        ...newService.value,
        calendar_schedule_id: activeSchedule.value.id,
        color: form.value.color,
        active: true,
      },
    });
    newService.value = {
      title: '',
      duration_minutes: 30,
      buffer_minutes: 15,
      location_type: 'google_meet',
      description: '',
    };
    showNewServiceForm.value = false;
    useAlert('Tipo de atendimento adicionado!');
    emit('saved', activeSchedule.value.id);
  } catch {
    useAlert('Erro ao criar tipo de atendimento.');
  } finally {
    savingService.value = false;
  }
};

const removeAppointmentType = async typeId => {
  try {
    await CalendarAPI.deleteAppointmentType(typeId);
    useAlert('Tipo de atendimento removido.');
    emit('saved', activeSchedule.value?.id);
  } catch {
    useAlert('Erro ao remover tipo de atendimento.');
  }
};

const previewBookingUrl = computed(() => {
  const slug =
    form.value.slug ||
    form.value.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') ||
    'especialista';
  return `${window.location.origin}/agendar/${slug}`;
});

const copyLink = url => {
  navigator.clipboard?.writeText(url);
  useAlert('Link público copiado para a área de transferência!');
};

const locationLabel = loc => {
  if (loc === 'google_meet') return 'Sala de Vídeo Meu Super Chat';
  if (loc === 'whatsapp') return 'WhatsApp / Ligação';
  if (loc === 'in_person') return 'Presencial';
  return 'Atendimento Online';
};
</script>

<template>
  <div class="flex flex-col gap-5 pb-10 pt-1">
    <!-- Barra Superior de Seleção de Especialista + Ações Rápidas -->
    <div
      class="flex flex-wrap items-center justify-between gap-3 bg-[#081218] border border-[#142633] rounded-2xl p-4 shadow-sm"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs font-medium text-slate-400 mr-1">
          Especialista selecionado:
        </span>
        <button
          v-for="sched in schedules"
          :key="sched.id"
          type="button"
          class="px-3.5 py-2 rounded-xl text-xs font-medium border transition-all duration-200 flex items-center gap-2"
          :class="
            !isCreatingNew && activeSchedule?.id === sched.id
              ? 'bg-emerald-500/15 border-emerald-500/50 text-emerald-300 shadow-sm'
              : 'bg-[#04090D] border-[#162936] text-slate-300 hover:border-emerald-500/30'
          "
          @click="selectExistingProfessional(sched.id)"
        >
          <span
            class="w-2.5 h-2.5 rounded-full shrink-0"
            :style="{ backgroundColor: sched.color || '#10b981' }"
          />
          <span class="truncate max-w-[170px]">{{ sched.name }}</span>
        </button>

        <button
          type="button"
          class="px-3.5 py-2 rounded-xl text-xs font-semibold border border-dashed border-emerald-500/40 text-emerald-400 hover:bg-emerald-500/10 transition flex items-center gap-1.5"
          @click="startNewProfessional"
        >
          <span class="i-lucide-user-plus size-3.5" />
          <span>Adicionar Especialista</span>
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2.5">
        <button
          type="button"
          class="px-3.5 py-2 rounded-xl bg-emerald-500/15 border border-emerald-500/40 hover:bg-emerald-500/25 text-xs font-semibold text-emerald-300 transition flex items-center gap-1.5"
          @click="openIntegrationsHub"
        >
          <span class="i-lucide-play-circle size-3.5 text-emerald-400" />
          <span>Onboarding & Autenticação OAuth</span>
        </button>
        <a
          v-if="activeSchedule && !isCreatingNew"
          :href="activeSchedule.public_booking_url"
          target="_blank"
          rel="noopener noreferrer"
          class="px-3.5 py-2 rounded-xl bg-[#0A151D] border border-[#162936] text-xs text-emerald-400 hover:bg-emerald-500/10 transition flex items-center gap-1.5 font-medium"
        >
          <span class="i-lucide-external-link size-3.5" />
          <span>Abrir Página Pública</span>
        </a>
        <button
          type="button"
          :disabled="saving"
          class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs transition shadow-md disabled:opacity-50 flex items-center gap-1.5"
          @click="saveProfile"
        >
          <span class="i-lucide-check size-3.5" />
          <span>
            {{
              saving
                ? 'Salvando...'
                : isCreatingNew
                  ? 'Criar Perfil & Agenda'
                  : 'Salvar Alterações'
            }}
          </span>
        </button>
      </div>
    </div>

    <!-- Layout Principal em 2 Colunas Balanceadas (Fiel ao GPT Image 2.5) -->
    <div class="grid grid-cols-1 xl:grid-cols-12 gap-5 items-start">
      <!-- Coluna Esquerda (5 cols): Perfil & IA + Sincronização OAuth + Tipos de Atendimento -->
      <div class="xl:col-span-5 flex flex-col gap-5">
        <!-- Card 1: Configuração do Perfil & IA -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4 shadow-sm"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div
                class="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
              >
                <span class="i-lucide-user-check size-4" />
              </div>
              <div>
                <h3 class="text-sm font-semibold text-[#F8FAFC]">
                  Configuração do Perfil & IA
                </h3>
                <p class="text-[11px] text-slate-400">
                  Defina como você será encontrado e como o Agente IA deve agir.
                </p>
              </div>
            </div>

            <div class="flex items-center gap-1.5 pt-1">
              <button
                v-for="c in COLORS"
                :key="c"
                type="button"
                class="w-4 h-4 rounded-full border-2 transition-transform"
                :class="
                  form.color === c
                    ? 'border-white scale-125 shadow'
                    : 'border-transparent opacity-70 hover:opacity-100'
                "
                :style="{ backgroundColor: c }"
                @click="form.color = c"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label
                class="block text-[11px] font-medium text-slate-300 mb-1.5"
              >
                Nome do Especialista *
              </label>
              <input
                v-model="form.name"
                type="text"
                placeholder="Ex: Samuel Vicente"
                class="w-full px-3.5 py-2.5 rounded-xl bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500/70 outline-none transition"
              />
            </div>
            <div>
              <label
                class="block text-[11px] font-medium text-slate-300 mb-1.5"
              >
                Cargo / Especialidade
              </label>
              <input
                v-model="form.role_title"
                type="text"
                placeholder="Ex: Especialista em Automação & IA"
                class="w-full px-3.5 py-2.5 rounded-xl bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500/70 outline-none transition"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label
                class="block text-[11px] font-medium text-slate-300 mb-1.5"
              >
                Slug da sua página pública
              </label>
              <div
                class="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-[#04090D] border border-[#162936] focus-within:border-emerald-500/70 transition"
              >
                <span
                  class="i-lucide-link-2 size-3.5 text-emerald-400 shrink-0"
                />
                <input
                  v-model="form.slug"
                  type="text"
                  placeholder="samuel-vicente"
                  class="w-full bg-transparent text-xs font-mono text-emerald-400 outline-none"
                />
              </div>
            </div>
            <div>
              <label
                class="block text-[11px] font-medium text-slate-300 mb-1.5"
              >
                Fuso Horário
              </label>
              <div
                class="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-[#04090D] border border-[#162936] focus-within:border-emerald-500/70 transition"
              >
                <span
                  class="i-lucide-globe size-3.5 text-emerald-400 shrink-0"
                />
                <select
                  v-model="form.timezone"
                  class="w-full bg-transparent text-xs text-white outline-none"
                >
                  <option value="America/Sao_Paulo">
                    America/Sao_Paulo (BRT)
                  </option>
                  <option value="America/Manaus">America/Manaus (AMT)</option>
                  <option value="Europe/Lisbon">Europe/Lisbon (WET)</option>
                  <option value="Europe/London">Europe/London (UK)</option>
                  <option value="America/New_York">
                    America/New_York (EST)
                  </option>
                </select>
              </div>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between mb-1.5">
              <label class="text-[11px] font-medium text-slate-300">
                Bio (aparece na sua página pública Meu Super Chat)
              </label>
              <span class="text-[10px] text-slate-500 font-mono">
                {{ (form.bio || '').length }}/500
              </span>
            </div>
            <textarea
              v-model="form.bio"
              rows="3"
              maxlength="500"
              placeholder="Descreva sua especialidade e o objetivo das reuniões..."
              class="w-full px-3.5 py-2.5 rounded-xl bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500/70 outline-none resize-none leading-relaxed transition"
            />
          </div>

          <!-- Switch iOS Emerald: Agente IA -->
          <div
            class="flex items-center justify-between gap-3 p-3.5 rounded-xl bg-[#04090D] border border-[#162936] hover:border-emerald-500/30 transition cursor-pointer"
            @click="form.ai_bookable = !form.ai_bookable"
          >
            <div class="flex items-center gap-3 min-w-0">
              <button
                type="button"
                role="switch"
                :aria-checked="form.ai_bookable"
                class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out"
                :class="form.ai_bookable ? 'bg-[#10B981]' : 'bg-slate-700'"
              >
                <span
                  class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
                  :class="form.ai_bookable ? 'translate-x-5' : 'translate-x-0'"
                />
              </button>
              <div class="flex flex-col min-w-0">
                <span class="text-xs font-semibold text-white">
                  Permitir que o Agente IA agende automaticamente
                </span>
                <span class="text-[11px] text-slate-400">
                  A IA analisa solicitações no WhatsApp e reserva nos seus
                  horários livres.
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Card 2: Sincronização de Agenda & Salas de Vídeo -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4 shadow-sm"
        >
          <div class="flex items-start justify-between gap-2">
            <div class="flex items-center gap-2.5">
              <div
                class="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
              >
                <span class="i-lucide-calendar-sync size-4" />
              </div>
              <div>
                <h3 class="text-sm font-semibold text-[#F8FAFC]">
                  Sincronização de Agenda & Salas de Vídeo
                </h3>
                <p class="text-[11px] text-slate-400">
                  Conecte sua agenda via OAuth 2.0 para leitura de conflitos em
                  tempo real.
                </p>
              </div>
            </div>
            <span
              class="px-2.5 py-1 rounded-full text-[11px] font-semibold shrink-0 flex items-center gap-1.5"
              :class="
                form.google_connected
                  ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                  : 'bg-slate-800 text-slate-400 border border-slate-700'
              "
            >
              <span
                class="w-1.5 h-1.5 rounded-full"
                :class="
                  form.google_connected ? 'bg-emerald-400' : 'bg-slate-400'
                "
              />
              {{ form.google_connected ? 'Conectado' : 'Pendente' }}
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label class="block text-[11px] font-medium text-slate-300 mb-1">
                E-mail da Conta Sincronizada
              </label>
              <input
                v-model="form.google_email"
                type="email"
                placeholder="samuel@meusuper.app"
                class="w-full px-3.5 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-xs text-white outline-none focus:border-emerald-500/70"
              />
            </div>
            <div>
              <label class="block text-[11px] font-medium text-slate-300 mb-1">
                Calendar ID
              </label>
              <input
                v-model="form.google_calendar_id"
                type="text"
                placeholder="primary"
                class="w-full px-3.5 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-xs font-mono text-slate-200 outline-none focus:border-emerald-500/70"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            <button
              type="button"
              class="px-3.5 py-2.5 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] text-xs font-bold transition flex items-center justify-center gap-1.5 shadow-sm"
              @click="openIntegrationsHub"
            >
              <span class="i-lucide-play-circle size-4" />
              <span>
                Abrir Onboarding OAuth ({{
                  integrationHooksCount || schedules.length
                }}) ativas
              </span>
            </button>
            <button
              type="button"
              :disabled="syncingNow"
              class="px-3.5 py-2.5 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-slate-200 text-xs font-medium transition flex items-center justify-center gap-1.5"
              @click="syncAgendaNow"
            >
              <span class="i-lucide-refresh-cw size-3.5 text-emerald-400" />
              <span>{{
                syncingNow ? 'Sincronizando...' : 'Sincronizar Agora'
              }}</span>
            </button>
          </div>

          <div class="flex items-center justify-between text-[11px] pt-1">
            <span class="text-slate-400 flex items-center gap-1.5">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-400" />
              Sincronização ativa em tempo real • Sala de Vídeo Meu Super Chat
            </span>
            <button
              v-if="form.google_connected"
              type="button"
              class="text-rose-400 hover:text-rose-300 font-medium"
              @click="disconnectGoogle"
            >
              Desconectar
            </button>
          </div>
        </div>

        <!-- Card 3: Tipos de Atendimento -->
        <div
          v-if="activeSchedule && !isCreatingNew"
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-3.5 shadow-sm"
        >
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-2.5">
              <div
                class="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
              >
                <span class="i-lucide-layout-grid size-4" />
              </div>
              <div>
                <h3 class="text-sm font-semibold text-[#F8FAFC]">
                  Tipos de Atendimento
                </h3>
                <p class="text-[11px] text-slate-400">
                  Defina as sessões que podem ser agendadas na sua página.
                </p>
              </div>
            </div>
            <button
              type="button"
              class="px-3 py-1.5 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs text-emerald-400 font-semibold transition flex items-center gap-1"
              @click="showNewServiceForm = !showNewServiceForm"
            >
              <span class="i-lucide-plus size-3.5" />
              <span>Novo Tipo</span>
            </button>
          </div>

          <div class="flex flex-col gap-2.5">
            <div
              v-for="(srv, sIdx) in activeSchedule.appointment_types || []"
              :key="srv.id"
              class="flex items-center justify-between gap-3 p-3.5 rounded-xl bg-[#04090D] border border-[#162936] hover:border-emerald-500/30 transition"
            >
              <div class="flex items-center gap-3 min-w-0">
                <div
                  class="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                  :class="
                    sIdx % 2 === 0
                      ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                      : 'bg-amber-500/15 text-amber-400 border border-amber-500/30'
                  "
                >
                  <span
                    :class="
                      sIdx % 2 === 0
                        ? 'i-lucide-sparkles size-4'
                        : 'i-lucide-crown size-4'
                    "
                  />
                </div>
                <div class="min-w-0">
                  <div class="text-xs font-semibold text-white truncate">
                    {{ srv.title }}
                  </div>
                  <div class="text-[11px] text-slate-400 truncate mt-0.5">
                    {{
                      srv.description ||
                      `${locationLabel(srv.location_type)} • Buffer ${srv.buffer_minutes || 15}m`
                    }}
                  </div>
                </div>
              </div>

              <div class="flex items-center gap-2 shrink-0">
                <span
                  class="px-2.5 py-1 rounded-full bg-[#0A151D] border border-[#162936] text-[11px] font-mono font-semibold text-emerald-400"
                >
                  {{ srv.duration_minutes }} min
                </span>
                <button
                  type="button"
                  class="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
                  title="Remover tipo de atendimento"
                  @click="removeAppointmentType(srv.id)"
                >
                  <span class="i-lucide-trash-2 size-3.5" />
                </button>
              </div>
            </div>
          </div>

          <div
            v-if="showNewServiceForm"
            class="p-3.5 rounded-xl bg-[#04090D] border border-emerald-500/30 flex flex-col gap-2.5"
          >
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <input
                v-model="newService.title"
                type="text"
                placeholder="Título (Ex: Consultoria Executiva)"
                class="sm:col-span-2 px-3 py-2 rounded-lg bg-[#081218] border border-[#162936] text-xs text-white outline-none"
              />
              <select
                v-model.number="newService.duration_minutes"
                class="px-3 py-2 rounded-lg bg-[#081218] border border-[#162936] text-xs text-white outline-none"
              >
                <option :value="15">15 min</option>
                <option :value="30">30 min</option>
                <option :value="45">45 min</option>
                <option :value="60">60 min</option>
                <option :value="90">90 min</option>
              </select>
            </div>
            <input
              v-model="newService.description"
              type="text"
              placeholder="Descrição curta exibida para o cliente na página pública..."
              class="px-3 py-2 rounded-lg bg-[#081218] border border-[#162936] text-xs text-white outline-none"
            />
            <div class="flex items-center justify-end gap-2">
              <button
                type="button"
                class="px-3 py-1.5 rounded-lg text-xs text-slate-400"
                @click="showNewServiceForm = false"
              >
                Cancelar
              </button>
              <button
                type="button"
                :disabled="savingService"
                class="px-3.5 py-1.5 rounded-lg bg-[#10B981] text-[#04090D] text-xs font-semibold"
                @click="addAppointmentType"
              >
                {{ savingService ? 'Salvando...' : 'Salvar Tipo' }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Coluna Direita (7 cols): Grade de Disponibilidade Semanal + Live Preview Meu Super Chat -->
      <div class="xl:col-span-7 flex flex-col gap-5">
        <!-- Card 4: Grade de Disponibilidade Semanal -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4 shadow-sm"
        >
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div
                class="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
              >
                <span class="i-lucide-clock-4 size-4" />
              </div>
              <div>
                <h3 class="text-sm font-semibold text-[#F8FAFC]">
                  Grade de Disponibilidade Semanal
                </h3>
                <p class="text-[11px] text-slate-400">
                  Defina os horários em que você está disponível para ser
                  agendado ({{ totalWeeklyHours }}h/semana).
                </p>
              </div>
            </div>

            <div class="flex flex-wrap items-center gap-2 text-xs">
              <div
                class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-[#04090D] border border-[#162936]"
              >
                <span class="text-slate-400 text-[11px]">Slot:</span>
                <select
                  v-model.number="form.slot_duration_minutes"
                  class="bg-transparent text-emerald-400 font-semibold outline-none text-xs"
                >
                  <option :value="15">15m</option>
                  <option :value="30">30m</option>
                  <option :value="45">45m</option>
                  <option :value="60">60m</option>
                </select>
              </div>
              <div
                class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-[#04090D] border border-[#162936]"
              >
                <span class="text-slate-400 text-[11px]">Buffer:</span>
                <select
                  v-model.number="form.buffer_after_minutes"
                  class="bg-transparent text-emerald-400 font-semibold outline-none text-xs"
                >
                  <option :value="0">0m</option>
                  <option :value="10">10m</option>
                  <option :value="15">15m</option>
                  <option :value="30">30m</option>
                </select>
              </div>
            </div>
          </div>

          <div class="flex flex-col divide-y divide-[#132631]">
            <div
              v-for="day in WEEKDAYS"
              :key="day.key"
              class="py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <!-- Dia + Toggle Switch iOS -->
              <div
                class="flex items-center justify-between sm:justify-start gap-3 min-w-[175px]"
              >
                <span
                  class="text-xs font-semibold w-28"
                  :class="
                    isDayEnabled(day.key) ? 'text-[#F8FAFC]' : 'text-slate-500'
                  "
                >
                  {{ day.label }}
                </span>
                <button
                  type="button"
                  role="switch"
                  :aria-checked="isDayEnabled(day.key)"
                  class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out"
                  :class="
                    isDayEnabled(day.key) ? 'bg-[#10B981]' : 'bg-slate-700/70'
                  "
                  @click="toggleDay(day.key)"
                >
                  <span
                    class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
                    :class="
                      isDayEnabled(day.key) ? 'translate-x-5' : 'translate-x-0'
                    "
                  />
                </button>
              </div>

              <!-- Pílulas de Turno Customizadas (Sem ícone de relógio nativo feio) -->
              <div
                v-if="isDayEnabled(day.key)"
                class="flex flex-wrap items-center gap-2 flex-1 sm:justify-end"
              >
                <div
                  v-for="(interval, idx) in form.weekly_hours[day.key]"
                  :key="idx"
                  class="inline-flex items-center gap-1.5 bg-[#04090D] border border-[#162936] hover:border-emerald-500/40 rounded-xl px-3 py-1.5 transition"
                >
                  <span
                    class="i-lucide-clock size-3.5 text-emerald-400 shrink-0"
                  />
                  <input
                    v-model="interval.start"
                    type="text"
                    maxlength="5"
                    placeholder="09:00"
                    class="w-12 bg-transparent text-xs font-mono font-semibold text-white text-center outline-none"
                  />
                  <span class="text-slate-500 text-xs">—</span>
                  <input
                    v-model="interval.end"
                    type="text"
                    maxlength="5"
                    placeholder="18:00"
                    class="w-12 bg-transparent text-xs font-mono font-semibold text-white text-center outline-none"
                  />
                  <button
                    v-if="form.weekly_hours[day.key].length > 1"
                    type="button"
                    class="text-slate-500 hover:text-rose-400 ml-0.5"
                    title="Remover turno"
                    @click="removeInterval(day.key, idx)"
                  >
                    <span class="i-lucide-x size-3.5" />
                  </button>
                </div>

                <button
                  type="button"
                  class="px-2.5 py-1.5 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-[11px] font-medium text-emerald-400 transition flex items-center gap-1"
                  @click="addInterval(day.key)"
                >
                  <span class="i-lucide-plus size-3" />
                  <span>Turno</span>
                </button>
              </div>

              <div
                v-else
                class="flex items-center justify-between sm:justify-end gap-3 flex-1"
              >
                <span class="text-xs text-slate-500 italic">Indisponível</span>
                <button
                  type="button"
                  class="px-2.5 py-1.5 rounded-xl bg-[#04090D] border border-[#162936] text-[11px] text-slate-400 hover:text-emerald-400 transition flex items-center gap-1"
                  @click="toggleDay(day.key)"
                >
                  <span class="i-lucide-plus size-3" />
                  <span>Turno</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Card 5: Live Preview Executivo — Página Pública Meu Super Chat -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4 shadow-sm"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div class="flex items-center gap-2.5">
              <div
                class="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
              >
                <span class="i-lucide-eye size-4" />
              </div>
              <div>
                <h3 class="text-sm font-semibold text-[#F8FAFC]">
                  Live Preview — Página Pública Meu Super Chat
                </h3>
                <p class="text-[11px] text-slate-400">
                  Veja em tempo real como sua página exclusiva aparece para quem
                  deseja agendar com você.
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                class="px-3 py-1.5 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs text-slate-200 font-medium flex items-center gap-1.5 transition"
                @click="copyLink(previewBookingUrl)"
              >
                <span class="i-lucide-copy size-3.5 text-emerald-400" />
                <span>Copiar Link</span>
              </button>
              <a
                :href="previewBookingUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="px-3.5 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-500/25 text-xs font-semibold flex items-center gap-1.5 transition"
              >
                <span class="i-lucide-external-link size-3.5" />
                <span>Testar Página</span>
              </a>
            </div>
          </div>

          <!-- Mini Card Interativo do Perfil Público -->
          <div
            class="rounded-2xl bg-[#04090D] border border-[#162936] p-4 sm:p-5 grid grid-cols-1 md:grid-cols-12 gap-4 items-center"
          >
            <div class="md:col-span-7 flex flex-col gap-3">
              <div class="flex items-center gap-3.5">
                <div class="relative shrink-0">
                  <div
                    class="w-14 h-14 rounded-2xl flex items-center justify-center text-base font-bold text-[#04090D] ring-2 ring-emerald-500/50 shadow-lg"
                    :style="{ backgroundColor: form.color || '#10b981' }"
                  >
                    {{ initials }}
                  </div>
                  <span
                    class="w-3.5 h-3.5 rounded-full bg-emerald-400 border-2 border-[#04090D] absolute -bottom-0.5 -right-0.5"
                  />
                </div>
                <div class="min-w-0">
                  <div class="flex items-center gap-1.5">
                    <h4 class="text-base font-bold text-[#F8FAFC] truncate">
                      {{ form.name || 'Seu Nome Executivo' }}
                    </h4>
                    <span
                      class="i-lucide-badge-check size-4 text-emerald-400 shrink-0"
                    />
                  </div>
                  <div class="text-xs text-emerald-400 font-medium truncate">
                    {{ form.role_title || 'Especialista • Meu Super Chat' }}
                  </div>
                  <div
                    class="text-[11px] font-mono text-slate-400 truncate mt-0.5"
                  >
                    {{ previewBookingUrl.replace(/^https?:\/\//, '') }}
                  </div>
                </div>
              </div>

              <p class="text-xs text-slate-300 leading-relaxed line-clamp-2">
                {{
                  form.bio ||
                  'Sessão executiva de arquitetura de IA, automação omnichannel e escala comercial com Meu Super Chat.'
                }}
              </p>

              <div class="flex flex-wrap items-center gap-2 pt-1">
                <span
                  class="px-2.5 py-1 rounded-lg bg-[#081218] border border-[#132631] text-[10px] text-slate-300 flex items-center gap-1"
                >
                  <span class="i-lucide-video size-3 text-emerald-400" />
                  Sala de Vídeo Meu Super Chat
                </span>
                <span
                  class="px-2.5 py-1 rounded-lg bg-[#081218] border border-[#132631] text-[10px] text-slate-300 flex items-center gap-1"
                >
                  <span class="i-lucide-shield-check size-3 text-emerald-400" />
                  Especialista Verificado
                </span>
              </div>
            </div>

            <div class="md:col-span-5 flex flex-col gap-2">
              <span
                class="text-[10px] uppercase tracking-wider text-slate-400 font-semibold"
              >
                Selecione um tipo de atendimento
              </span>
              <div
                v-for="srv in (activeSchedule?.appointment_types || []).slice(
                  0,
                  2
                )"
                :key="srv.id"
                class="p-2.5 rounded-xl bg-[#081218] border border-[#162936] flex items-center justify-between gap-2"
              >
                <div class="min-w-0">
                  <div class="text-xs font-semibold text-white truncate">
                    {{ srv.title }}
                  </div>
                  <div class="text-[10px] text-emerald-400 font-mono">
                    {{ srv.duration_minutes }} min
                  </div>
                </div>
                <span
                  class="i-lucide-chevron-right size-3.5 text-slate-400 shrink-0"
                />
              </div>

              <a
                :href="previewBookingUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="mt-1 w-full py-2.5 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-bold text-xs text-center flex items-center justify-center gap-1.5 shadow-md transition"
              >
                <span>Agendar Agora</span>
                <span class="i-lucide-arrow-right size-3.5" />
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
