<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, computed, watch } from 'vue';
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
  googleOauthConfigured: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['saved', 'selectSchedule']);

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
      role_title: 'Especialista / Consultor',
      bio: 'Agende seu horário diretamente na minha agenda sincronizada.',
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
      useAlert('Novo profissional e link público criados com sucesso!');
      emit('saved', res.data?.id);
    } else {
      res = await CalendarAPI.updateSchedule(
        activeSchedule.value.id,
        form.value
      );
      useAlert('Perfil, horários e configurações salvos!');
      emit('saved', res.data?.id);
    }
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Erro ao salvar perfil de agenda.');
  } finally {
    saving.value = false;
  }
};

const connectGoogleCalendar = async () => {
  if (!activeSchedule.value) {
    useAlert(
      'Salve o perfil do profissional primeiro para conectar o Google Agenda.'
    );
    return;
  }
  try {
    const { data } = await CalendarAPI.getGoogleAuthUrl(
      activeSchedule.value.id
    );
    if (data.oauth_configured && data.authorization_url) {
      window.location.href = data.authorization_url;
      return;
    }
    if (form.value.google_email.trim()) {
      await CalendarAPI.updateSchedule(activeSchedule.value.id, {
        ...form.value,
        google_connected: true,
      });
      useAlert('Google Agenda vinculada ao profissional!');
      emit('saved', activeSchedule.value.id);
    } else {
      useAlert(
        data.message ||
          'Preencha o e-mail Google abaixo para vincular ou configure OAuth no Super Admin.'
      );
    }
  } catch (err) {
    useAlert('Não foi possível iniciar a conexão com o Google Agenda.');
  }
};

const disconnectGoogle = async () => {
  if (!activeSchedule.value) return;
  try {
    await CalendarAPI.disconnectGoogle(activeSchedule.value.id);
    useAlert('Google Agenda desconectada.');
    emit('saved', activeSchedule.value.id);
  } catch {
    useAlert('Erro ao desconectar Google Agenda.');
  }
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
    'profissional';
  return `${window.location.origin}/agendar/${slug}`;
});

const copyLink = url => {
  navigator.clipboard?.writeText(url);
  useAlert('Link público copiado para a área de transferência!');
};
</script>

<template>
  <div class="flex flex-col gap-5 pb-8">
    <!-- Barra de Seleção de Profissional + Criar Novo -->
    <div
      class="flex flex-wrap items-center justify-between gap-3 bg-[#081218] border border-[#132631] rounded-xl p-3.5"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs text-slate-400 mr-1">Profissional editado:</span>
        <button
          v-for="sched in schedules"
          :key="sched.id"
          type="button"
          class="px-3 py-1.5 rounded-lg text-xs font-medium border transition flex items-center gap-2"
          :class="
            !isCreatingNew && activeSchedule?.id === sched.id
              ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-300'
              : 'bg-[#04090D] border-[#162936] text-slate-300 hover:border-slate-600'
          "
          @click="selectExistingProfessional(sched.id)"
        >
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :style="{ backgroundColor: sched.color || '#10b981' }"
          />
          <span class="truncate max-w-[160px]">{{ sched.name }}</span>
        </button>

        <button
          type="button"
          class="px-3 py-1.5 rounded-lg text-xs font-semibold border border-dashed border-emerald-500/50 text-emerald-400 hover:bg-emerald-500/10 transition"
          @click="startNewProfessional"
        >
          + Adicionar Profissional
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <a
          v-if="activeSchedule && !isCreatingNew"
          :href="activeSchedule.public_booking_url"
          target="_blank"
          rel="noopener noreferrer"
          class="px-3 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] text-xs text-emerald-400 hover:bg-emerald-500/10 transition flex items-center gap-1.5"
        >
          <span class="i-lucide-external-link size-3.5" />
          Abrir Página Pública
        </a>
        <button
          type="button"
          :disabled="saving"
          class="px-4 py-1.5 rounded-lg bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs transition disabled:opacity-50"
          @click="saveProfile"
        >
          {{
            saving
              ? 'Salvando...'
              : isCreatingNew
                ? 'Criar Perfil & Agenda'
                : 'Salvar Alterações'
          }}
        </button>
      </div>
    </div>

    <!-- Layout Principal: Esquerda Configs | Direita Horários + Preview Cal.com -->
    <div class="grid grid-cols-1 xl:grid-cols-12 gap-5">
      <!-- Coluna Esquerda (5 cols): Dados do Perfil, IA & Google Calendar -->
      <div class="xl:col-span-5 flex flex-col gap-4">
        <div
          class="bg-[#081218] border border-[#132631] rounded-xl p-4 flex flex-col gap-3.5"
        >
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-semibold text-[#F8FAFC]">
              1. Perfil Público & Identidade (Estilo Cal.com)
            </h3>
            <div class="flex items-center gap-1.5">
              <button
                v-for="c in COLORS"
                :key="c"
                type="button"
                class="w-4 h-4 rounded-full border-2 transition"
                :class="
                  form.color === c
                    ? 'border-white scale-110'
                    : 'border-transparent opacity-70'
                "
                :style="{ backgroundColor: c }"
                @click="form.color = c"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Nome do Profissional *
              </label>
              <input
                v-model="form.name"
                type="text"
                placeholder="Ex: Dr. Rafael Nogueira"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500 outline-none"
              />
            </div>
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Cargo / Especialidade
              </label>
              <input
                v-model="form.role_title"
                type="text"
                placeholder="Ex: Especialista / Closer"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500 outline-none"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Slug do Link Público
              </label>
              <input
                v-model="form.slug"
                type="text"
                placeholder="samuel-vicente"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs font-mono text-emerald-400 focus:border-emerald-500 outline-none"
              />
            </div>
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Fuso Horário
              </label>
              <select
                v-model="form.timezone"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500 outline-none"
              >
                <option value="America/Sao_Paulo">
                  America/Sao_Paulo (BRT)
                </option>
                <option value="America/Manaus">America/Manaus (AMT)</option>
                <option value="Europe/Lisbon">Europe/Lisbon (WET)</option>
                <option value="Europe/London">Europe/London (UK)</option>
                <option value="America/New_York">America/New_York (EST)</option>
              </select>
            </div>
          </div>

          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Bio / Descrição na Página Pública
            </label>
            <textarea
              v-model="form.bio"
              rows="2"
              placeholder="Descreva como funciona a reunião ou consulta..."
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white focus:border-emerald-500 outline-none resize-none"
            />
          </div>

          <!-- Toggle IA -->
          <label
            class="flex items-center justify-between gap-3 p-3 rounded-lg bg-[#04090D] border border-[#162936] cursor-pointer"
          >
            <div class="flex flex-col">
              <span class="text-xs font-medium text-white">
                Permitir que o Agente IA agende nesta agenda
              </span>
              <span class="text-[11px] text-slate-400">
                A IA consulta horários livres e marca reuniões pelo WhatsApp
                automaticamente
              </span>
            </div>
            <input
              v-model="form.ai_bookable"
              type="checkbox"
              class="accent-emerald-500 w-4 h-4 shrink-0"
            />
          </label>
        </div>

        <!-- Conexão Google Agenda -->
        <div
          class="bg-[#081218] border border-[#132631] rounded-xl p-4 flex flex-col gap-3"
        >
          <div class="flex items-center justify-between gap-2">
            <div>
              <h3 class="text-sm font-semibold text-[#F8FAFC]">
                2. Sincronização Google Agenda & Meet
              </h3>
              <p class="text-[11px] text-slate-400">
                Lê conflitos em tempo real (freeBusy) e cria link do Google Meet
              </p>
            </div>
            <span
              class="px-2.5 py-0.5 rounded-full text-[11px] font-medium shrink-0"
              :class="
                form.google_connected
                  ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                  : 'bg-slate-800 text-slate-400'
              "
            >
              {{ form.google_connected ? 'Conectado' : 'Não conectado' }}
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                E-mail da Conta Google
              </label>
              <input
                v-model="form.google_email"
                type="email"
                placeholder="agenda@empresa.com.br"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white outline-none"
              />
            </div>
            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Calendar ID
              </label>
              <input
                v-model="form.google_calendar_id"
                type="text"
                placeholder="primary"
                class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-xs font-mono text-slate-200 outline-none"
              />
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <button
              type="button"
              class="px-3.5 py-2 rounded-lg bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-500/25 text-xs font-semibold transition"
              @click="connectGoogleCalendar"
            >
              {{
                googleOauthConfigured
                  ? 'Autenticar OAuth com Google Agenda'
                  : 'Vincular Conta Google Agenda'
              }}
            </button>
            <button
              v-if="form.google_connected"
              type="button"
              class="px-3 py-2 rounded-lg bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs"
              @click="disconnectGoogle"
            >
              Desconectar
            </button>
          </div>
        </div>

        <!-- Tipos de Serviço / Reunião -->
        <div
          v-if="activeSchedule && !isCreatingNew"
          class="bg-[#081218] border border-[#132631] rounded-xl p-4 flex flex-col gap-3"
        >
          <h3 class="text-sm font-semibold text-[#F8FAFC]">
            3. Tipos de Atendimento / Serviços do Link Público
          </h3>

          <div class="flex flex-col gap-2">
            <div
              v-for="srv in activeSchedule.appointment_types || []"
              :key="srv.id"
              class="flex items-center justify-between gap-2 p-2.5 rounded-lg bg-[#04090D] border border-[#162936]"
            >
              <div class="min-w-0">
                <div class="text-xs font-semibold text-white truncate">
                  {{ srv.title }}
                </div>
                <div class="text-[11px] text-slate-400">
                  {{ srv.duration_minutes }} min • Buffer
                  {{ srv.buffer_minutes }}m •
                  {{
                    srv.location_type === 'google_meet'
                      ? 'Google Meet'
                      : srv.location_type
                  }}
                </div>
              </div>
              <button
                type="button"
                class="text-rose-400 hover:text-rose-300 text-xs px-2 py-1"
                @click="removeAppointmentType(srv.id)"
              >
                Remover
              </button>
            </div>
          </div>

          <div
            class="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-2 border-t border-[#132631]"
          >
            <input
              v-model="newService.title"
              type="text"
              placeholder="Novo serviço (Ex: Consulta 1h)"
              class="sm:col-span-2 px-2.5 py-1.5 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white outline-none"
            />
            <select
              v-model.number="newService.duration_minutes"
              class="px-2.5 py-1.5 rounded-lg bg-[#04090D] border border-[#162936] text-xs text-white outline-none"
            >
              <option :value="15">15 min</option>
              <option :value="30">30 min</option>
              <option :value="45">45 min</option>
              <option :value="60">60 min</option>
              <option :value="90">90 min</option>
            </select>
          </div>
          <button
            type="button"
            :disabled="savingService"
            class="self-start px-3 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs text-emerald-400 font-medium"
            @click="addAppointmentType"
          >
            + Adicionar Tipo de Atendimento
          </button>
        </div>
      </div>

      <!-- Coluna Direita (7 cols): Grade de Horários Semanal + Preview Link Público -->
      <div class="xl:col-span-7 flex flex-col gap-4">
        <div
          class="bg-[#081218] border border-[#132631] rounded-xl p-4 flex flex-col gap-3"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 class="text-sm font-semibold text-[#F8FAFC]">
                4. Grade de Disponibilidade Semanal & Buffers
              </h3>
              <p class="text-[11px] text-slate-400">
                Defina os turnos de atendimento para cálculo automático de slots
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-2 text-xs">
              <label class="flex items-center gap-1.5 text-slate-300">
                <span>Duração:</span>
                <select
                  v-model.number="form.slot_duration_minutes"
                  class="px-2 py-1 rounded bg-[#04090D] border border-[#162936] text-white"
                >
                  <option :value="15">15m</option>
                  <option :value="30">30m</option>
                  <option :value="45">45m</option>
                  <option :value="60">60m</option>
                </select>
              </label>
              <label class="flex items-center gap-1.5 text-slate-300">
                <span>Buffer:</span>
                <select
                  v-model.number="form.buffer_after_minutes"
                  class="px-2 py-1 rounded bg-[#04090D] border border-[#162936] text-white"
                >
                  <option :value="0">0m</option>
                  <option :value="10">10m</option>
                  <option :value="15">15m</option>
                  <option :value="30">30m</option>
                </select>
              </label>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <div
              v-for="day in WEEKDAYS"
              :key="day.key"
              class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-2.5 rounded-lg bg-[#04090D] border border-[#132631]"
            >
              <label
                class="flex items-center gap-2 cursor-pointer min-w-[130px]"
              >
                <input
                  type="checkbox"
                  :checked="isDayEnabled(day.key)"
                  class="accent-emerald-500 w-4 h-4"
                  @change="toggleDay(day.key)"
                />
                <span
                  class="text-xs font-medium"
                  :class="
                    isDayEnabled(day.key)
                      ? 'text-emerald-400'
                      : 'text-slate-500'
                  "
                >
                  {{ day.label }}
                </span>
              </label>

              <div
                v-if="isDayEnabled(day.key)"
                class="flex flex-wrap items-center gap-2"
              >
                <div
                  v-for="(interval, idx) in form.weekly_hours[day.key]"
                  :key="idx"
                  class="flex items-center gap-1 bg-[#081218] border border-[#162936] rounded-lg px-2 py-1"
                >
                  <input
                    v-model="interval.start"
                    type="time"
                    class="bg-transparent text-xs font-mono text-white outline-none"
                  />
                  <span class="text-slate-500 text-xs">—</span>
                  <input
                    v-model="interval.end"
                    type="time"
                    class="bg-transparent text-xs font-mono text-white outline-none"
                  />
                  <button
                    v-if="form.weekly_hours[day.key].length > 1"
                    type="button"
                    class="text-slate-500 hover:text-rose-400 text-xs ml-1"
                    @click="removeInterval(day.key, idx)"
                  >
                    ×
                  </button>
                </div>
                <button
                  type="button"
                  class="px-2 py-1 rounded bg-[#0A151D] border border-[#162936] text-[11px] text-emerald-400"
                  @click="addInterval(day.key)"
                >
                  + Turno
                </button>
              </div>
              <span v-else class="text-xs text-slate-600 italic">
                Indisponível
              </span>
            </div>
          </div>
        </div>

        <!-- Card de Link Público Pronto -->
        <div
          class="bg-[#081218] border border-emerald-500/30 rounded-xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
        >
          <div class="min-w-0">
            <span
              class="text-[11px] uppercase tracking-wider text-emerald-400 font-semibold"
            >
              Link Público Estilo Cal.com / Calendly
            </span>
            <div class="text-xs font-mono text-white truncate mt-0.5">
              {{ previewBookingUrl }}
            </div>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <button
              type="button"
              class="px-3 py-1.5 rounded-lg bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 text-xs font-semibold"
              @click="copyLink(previewBookingUrl)"
            >
              Copiar Link
            </button>
            <a
              :href="previewBookingUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="px-3 py-1.5 rounded-lg bg-[#10B981] text-[#04090D] text-xs font-semibold"
            >
              Testar Link
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
