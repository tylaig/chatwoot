<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, computed, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import CalendarAPI from 'dashboard/api/calendar';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  schedules: {
    type: Array,
    default: () => [],
  },
  defaultScheduleId: {
    type: [Number, String],
    default: null,
  },
  appointment: {
    type: Object,
    default: null,
  },
  prefillContact: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const saving = ref(false);
const loadingSlots = ref(false);
const availableSlots = ref([]);

const todayIso = () => new Date().toISOString().slice(0, 10);

const form = ref({
  calendar_schedule_id: '',
  appointment_type_id: '',
  date: todayIso(),
  time: '10:00',
  duration_minutes: 30,
  title: '',
  customer_name: '',
  customer_email: '',
  customer_phone: '',
  location_type: 'google_meet',
  notes: '',
});

const isEditMode = computed(() => !!props.appointment?.id);

const selectedSchedule = computed(() =>
  props.schedules.find(
    s => Number(s.id) === Number(form.value.calendar_schedule_id)
  )
);

const scheduleAppointmentTypes = computed(
  () => selectedSchedule.value?.appointment_types || []
);

const loadSlots = async () => {
  if (!form.value.calendar_schedule_id || !form.value.date) return;
  try {
    loadingSlots.value = true;
    const { data } = await CalendarAPI.getAvailability({
      calendar_schedule_id: form.value.calendar_schedule_id,
      appointment_type_id: form.value.appointment_type_id || undefined,
      date: form.value.date,
      days: 1,
    });
    const entry = (data.availability || [])[0];
    availableSlots.value = entry?.slots || [];
    if (
      !isEditMode.value &&
      availableSlots.value.length &&
      !availableSlots.value.some(s => s.time === form.value.time)
    ) {
      form.value.time = availableSlots.value[0].time;
    }
  } catch {
    availableSlots.value = [];
  } finally {
    loadingSlots.value = false;
  }
};

watch(
  () => props.show,
  open => {
    if (!open) return;
    if (props.appointment) {
      form.value = {
        calendar_schedule_id: props.appointment.calendar_schedule_id,
        appointment_type_id: props.appointment.appointment_type_id || '',
        date: props.appointment.date || todayIso(),
        time: props.appointment.start_time || '10:00',
        duration_minutes: props.appointment.duration_minutes || 30,
        title: props.appointment.title || '',
        customer_name: props.appointment.customer_name || '',
        customer_email: props.appointment.customer_email || '',
        customer_phone: props.appointment.customer_phone || '',
        location_type: props.appointment.location_type || 'google_meet',
        notes: props.appointment.notes || '',
      };
    } else {
      const firstId =
        props.defaultScheduleId && props.defaultScheduleId !== 'all'
          ? props.defaultScheduleId
          : props.schedules[0]?.id || '';
      form.value = {
        calendar_schedule_id: firstId,
        appointment_type_id: '',
        date: todayIso(),
        time: '10:00',
        duration_minutes: 30,
        title: '',
        customer_name: props.prefillContact?.name || '',
        customer_email: props.prefillContact?.email || '',
        customer_phone: props.prefillContact?.phone_number || '',
        location_type: 'google_meet',
        notes: '',
      };
    }
    loadSlots();
  }
);

watch(
  () => [
    form.value.calendar_schedule_id,
    form.value.date,
    form.value.appointment_type_id,
  ],
  () => {
    if (props.show) loadSlots();
  }
);

const submitBooking = async () => {
  if (!form.value.calendar_schedule_id || !form.value.customer_name.trim()) {
    useAlert('Selecione o profissional e informe o nome do cliente.');
    return;
  }
  try {
    saving.value = true;
    const startsAt = `${form.value.date}T${form.value.time}`;
    if (isEditMode.value) {
      await CalendarAPI.updateAppointment(props.appointment.id, {
        title: form.value.title,
        customer_name: form.value.customer_name,
        customer_email: form.value.customer_email,
        customer_phone: form.value.customer_phone,
        starts_at: startsAt,
        location_type: form.value.location_type,
        notes: form.value.notes,
      });
      useAlert('Agendamento atualizado com sucesso!');
    } else {
      await CalendarAPI.createAppointment({
        calendar_schedule_id: form.value.calendar_schedule_id,
        appointment_type_id: form.value.appointment_type_id || null,
        contact_id: props.prefillContact?.id || null,
        conversation_id: props.prefillContact?.conversation_id || null,
        title: form.value.title,
        customer_name: form.value.customer_name,
        customer_email: form.value.customer_email,
        customer_phone: form.value.customer_phone,
        starts_at: startsAt,
        duration_minutes: form.value.duration_minutes,
        location_type: form.value.location_type,
        notes: form.value.notes,
        source: 'operator',
      });
      useAlert('Agendamento confirmado e sincronizado!');
    }
    emit('saved');
    emit('close');
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Não foi possível salvar o agendamento.'
    );
  } finally {
    saving.value = false;
  }
};

const handleCancelAppointment = async () => {
  if (!props.appointment?.id) return;
  try {
    saving.value = true;
    await CalendarAPI.cancelAppointment(
      props.appointment.id,
      'Cancelado pelo painel Meu Super Chat'
    );
    useAlert('Agendamento cancelado.');
    emit('saved');
    emit('close');
  } catch {
    useAlert('Erro ao cancelar agendamento.');
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-lg bg-[#081218] border border-[#162936] rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
    >
      <div
        class="flex items-center justify-between px-5 py-4 border-b border-[#132631] bg-[#04090D]"
      >
        <div>
          <h3 class="text-base font-semibold text-[#F8FAFC]">
            {{
              isEditMode ? 'Detalhes / Editar Agendamento' : 'Novo Agendamento'
            }}
          </h3>
          <p class="text-xs text-slate-400">
            Sincronização em tempo real e geração automática de Sala de Vídeo
            Meu Super Chat
          </p>
        </div>
        <button
          type="button"
          class="text-slate-400 hover:text-white text-lg px-2"
          @click="emit('close')"
        >
          ×
        </button>
      </div>

      <div class="p-5 overflow-y-auto flex flex-col gap-3.5 text-xs">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Profissional / Agenda *
            </label>
            <select
              v-model="form.calendar_schedule_id"
              :disabled="isEditMode"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            >
              <option v-for="s in schedules" :key="s.id" :value="s.id">
                {{ s.name }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Tipo de Atendimento
            </label>
            <select
              v-model="form.appointment_type_id"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            >
              <option value="">
                Personalizado ({{ form.duration_minutes }} min)
              </option>
              <option
                v-for="t in scheduleAppointmentTypes"
                :key="t.id"
                :value="t.id"
              >
                {{ t.title }} ({{ t.duration_minutes }}m)
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">Data *</label>
            <input
              v-model="form.date"
              type="date"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            />
          </div>
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Horário (BRT) *
            </label>
            <input
              v-model="form.time"
              type="time"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white font-mono outline-none"
            />
          </div>
        </div>

        <!-- Sugestão de Slots Livres -->
        <div
          v-if="availableSlots.length"
          class="bg-[#04090D] border border-[#132631] rounded-xl p-2.5"
        >
          <span class="block text-[11px] text-slate-400 mb-1.5">
            Horários livres verificados para {{ form.date }}:
          </span>
          <div class="flex flex-wrap gap-1.5 max-h-24 overflow-y-auto">
            <button
              v-for="slot in availableSlots"
              :key="slot.time"
              type="button"
              class="px-2.5 py-1 rounded-md font-mono text-[11px] border transition"
              :class="
                form.time === slot.time
                  ? 'bg-[#10B981] text-[#04090D] border-[#10B981] font-bold'
                  : 'bg-[#081218] border-[#162936] text-slate-200 hover:border-emerald-500/40'
              "
              @click="form.time = slot.time"
            >
              {{ slot.time }}
            </button>
          </div>
        </div>
        <div v-else-if="loadingSlots" class="text-[11px] text-slate-400">
          Consultando horários disponíveis...
        </div>

        <div>
          <label class="block text-[11px] text-slate-400 mb-1">
            Título do Compromisso
          </label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Ex: Demonstração Meu Super App"
            class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Nome do Cliente *
            </label>
            <input
              v-model="form.customer_name"
              type="text"
              placeholder="Nome completo"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            />
          </div>
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              WhatsApp / Telefone
            </label>
            <input
              v-model="form.customer_phone"
              type="text"
              placeholder="+55 11 99999-9999"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            />
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              E-mail (Convite de Calendário)
            </label>
            <input
              v-model="form.customer_email"
              type="email"
              placeholder="cliente@empresa.com"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            />
          </div>
          <div>
            <label class="block text-[11px] text-slate-400 mb-1">
              Modalidade
            </label>
            <select
              v-model="form.location_type"
              class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none"
            >
              <option value="google_meet">Sala de Vídeo Meu Super Chat</option>
              <option value="whatsapp">Chamada WhatsApp</option>
              <option value="in_person">Presencial</option>
              <option value="phone">Telefone</option>
            </select>
          </div>
        </div>

        <div
          v-if="appointment?.meeting_url"
          class="p-2.5 rounded-lg bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-between gap-2"
        >
          <span class="text-emerald-300 truncate font-mono text-[11px]">
            {{ appointment.meeting_url }}
          </span>
          <a
            :href="appointment.meeting_url"
            target="_blank"
            rel="noopener noreferrer"
            class="px-2.5 py-1 rounded bg-[#10B981] text-[#04090D] font-bold text-[11px] shrink-0"
          >
            Abrir Sala
          </a>
        </div>

        <div>
          <label class="block text-[11px] text-slate-400 mb-1">
            Observações
          </label>
          <textarea
            v-model="form.notes"
            rows="2"
            placeholder="Contexto do agendamento..."
            class="w-full px-3 py-2 rounded-lg bg-[#04090D] border border-[#162936] text-white outline-none resize-none"
          />
        </div>
      </div>

      <div
        class="flex flex-wrap items-center justify-between gap-2 px-5 py-3.5 border-t border-[#132631] bg-[#04090D]"
      >
        <button
          v-if="isEditMode && appointment?.status !== 'cancelled'"
          type="button"
          :disabled="saving"
          class="px-3 py-2 rounded-lg bg-rose-500/15 border border-rose-500/30 text-rose-300 text-xs font-medium"
          @click="handleCancelAppointment"
        >
          Cancelar Agendamento
        </button>
        <div v-else />

        <div class="flex items-center gap-2">
          <button
            type="button"
            class="px-3.5 py-2 rounded-lg bg-[#0A151D] border border-[#162936] text-slate-300 text-xs"
            @click="emit('close')"
          >
            Fechar
          </button>
          <button
            type="button"
            :disabled="saving"
            class="px-4 py-2 rounded-lg bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs disabled:opacity-50"
            @click="submitBooking"
          >
            {{
              saving
                ? 'Salvando...'
                : isEditMode
                  ? 'Salvar Alterações'
                  : 'Confirmar Agendamento'
            }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
