<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, watch, onMounted } from 'vue';
import { useFunctionGetter, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CalendarAPI from 'dashboard/api/calendar';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  conversationId: {
    type: [Number, String],
    default: null,
  },
});

const contact = useFunctionGetter('contacts/getContact', props.contactId);
const currentChat = useMapGetter('getSelectedChat');

const appointments = ref([]);
const schedules = ref([]);
const loading = ref(false);
const showQuickForm = ref(false);
const saving = ref(false);

const todayIso = () => new Date().toISOString().slice(0, 10);

const quickForm = ref({
  calendar_schedule_id: '',
  date: todayIso(),
  time: '14:30',
  title: 'Reunião / Atendimento',
});

const fetchContactAppointments = async () => {
  if (!props.contactId) return;
  try {
    loading.value = true;
    const [schedRes, apptRes] = await Promise.all([
      CalendarAPI.getSchedules(),
      CalendarAPI.getAppointments({ contact_id: props.contactId }),
    ]);
    schedules.value = schedRes.data?.schedules || [];
    if (!quickForm.value.calendar_schedule_id && schedules.value.length) {
      quickForm.value.calendar_schedule_id = schedules.value[0].id;
    }
    appointments.value = (apptRes.data?.appointments || []).filter(
      a => a.status !== 'cancelled'
    );
  } catch {
    appointments.value = [];
  } finally {
    loading.value = false;
  }
};

const createQuickBooking = async () => {
  if (!quickForm.value.calendar_schedule_id) return;
  try {
    saving.value = true;
    await CalendarAPI.createAppointment({
      calendar_schedule_id: quickForm.value.calendar_schedule_id,
      contact_id: props.contactId,
      conversation_id: props.conversationId || currentChat.value?.id || null,
      customer_name: contact.value?.name || 'Cliente',
      customer_email: contact.value?.email || '',
      customer_phone: contact.value?.phone_number || '',
      title: quickForm.value.title || 'Reunião',
      starts_at: `${quickForm.value.date}T${quickForm.value.time}`,
      location_type: 'google_meet',
      source: 'operator',
    });
    useAlert('Compromisso agendado com sucesso!');
    showQuickForm.value = false;
    await fetchContactAppointments();
  } catch (err) {
    useAlert(err?.response?.data?.error || 'Conflito ou erro ao agendar.');
  } finally {
    saving.value = false;
  }
};

const cancelBooking = async id => {
  try {
    await CalendarAPI.cancelAppointment(id, 'Cancelado na barra lateral');
    useAlert('Agendamento cancelado.');
    await fetchContactAppointments();
  } catch {
    useAlert('Erro ao cancelar.');
  }
};

watch(
  () => props.contactId,
  () => {
    fetchContactAppointments();
  }
);

onMounted(() => {
  fetchContactAppointments();
});
</script>

<template>
  <div class="px-4 py-2 text-xs flex flex-col gap-2.5">
    <div class="flex items-center justify-between">
      <span class="text-[11px] text-slate-400">
        {{ appointments.length }} compromisso(s) ativo(s)
      </span>
      <button
        type="button"
        class="px-2.5 py-1 rounded-md bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 font-semibold text-[11px]"
        @click="showQuickForm = !showQuickForm"
      >
        {{ showQuickForm ? 'Fechar' : '+ Agendar' }}
      </button>
    </div>

    <!-- Formulário Rápido Inline -->
    <div
      v-if="showQuickForm"
      class="p-2.5 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-2"
    >
      <select
        v-model="quickForm.calendar_schedule_id"
        class="w-full px-2.5 py-1.5 rounded bg-[#081218] border border-[#162936] text-white text-xs outline-none"
      >
        <option v-for="s in schedules" :key="s.id" :value="s.id">
          {{ s.name }}
        </option>
      </select>
      <input
        v-model="quickForm.title"
        type="text"
        placeholder="Assunto da reunião"
        class="w-full px-2.5 py-1.5 rounded bg-[#081218] border border-[#162936] text-white text-xs outline-none"
      />
      <div class="grid grid-cols-2 gap-1.5">
        <input
          v-model="quickForm.date"
          type="date"
          class="px-2 py-1.5 rounded bg-[#081218] border border-[#162936] text-white text-[11px] outline-none"
        />
        <input
          v-model="quickForm.time"
          type="time"
          class="px-2 py-1.5 rounded bg-[#081218] border border-[#162936] text-white text-[11px] font-mono outline-none"
        />
      </div>
      <button
        type="button"
        :disabled="saving"
        class="w-full py-1.5 rounded-lg bg-[#10B981] text-[#04090D] font-bold text-xs"
        @click="createQuickBooking"
      >
        {{ saving ? 'Agendando...' : 'Confirmar no Google Agenda' }}
      </button>
    </div>

    <!-- Lista de Agendamentos do Contato -->
    <div v-if="loading" class="text-slate-500 py-2">Carregando agenda...</div>
    <div
      v-else-if="appointments.length === 0"
      class="text-slate-500 py-2 text-[11px]"
    >
      Nenhum agendamento futuro para este contato.
    </div>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="appt in appointments"
        :key="appt.id"
        class="p-2.5 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-1"
      >
        <div class="flex items-center justify-between gap-1">
          <span class="font-mono font-bold text-emerald-400 text-[11px]">
            {{ appt.date }} • {{ appt.start_time }}
          </span>
          <span
            class="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/15 text-emerald-300"
          >
            {{ appt.source === 'ai_agent' ? 'Agente IA' : 'Confirmado' }}
          </span>
        </div>
        <div class="font-semibold text-white truncate">{{ appt.title }}</div>
        <div
          class="text-[11px] text-slate-400 truncate flex items-center gap-1"
        >
          <span class="i-lucide-user size-3 shrink-0" />
          <span class="truncate">{{ appt.professional_name }}</span>
        </div>
        <div class="flex items-center gap-1.5 mt-1">
          <a
            v-if="appt.meeting_url"
            :href="appt.meeting_url"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 text-center py-1 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 font-semibold text-[11px]"
          >
            Abrir Meet
          </a>
          <button
            type="button"
            class="px-2 py-1 rounded bg-rose-500/10 border border-rose-500/30 text-rose-300 text-[10px]"
            @click="cancelBooking(appt.id)"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
