<script setup>
const props = defineProps({
  type: {
    type: String,
    required: true,
  },
  config: {
    type: Object,
    required: true,
  },
  inboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updateField']);

const SELECT_CLASS =
  'w-full h-9 m-0 py-0 ps-3 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12';
const LABEL_CLASS = 'block mb-1.5 text-xs font-medium text-n-slate-12';
const HINT_CLASS = 'mt-1 text-[0.6875rem] text-n-slate-10';

const visibleInboxes = () =>
  props.type === 'widget_opened_trigger'
    ? props.inboxes.filter(inbox => inbox.channel_type === 'Channel::WebWidget')
    : props.inboxes;

const update = (field, value) => emit('updateField', field, value);

const toggleStatus = status => {
  const current = new Set(props.config.from_statuses || []);
  if (current.has(status)) current.delete(status);
  else current.add(status);
  update('from_statuses', [...current]);
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-4">
    <div>
      <label :class="LABEL_CLASS">Caixa de entrada</label>
      <select
        :value="config.inbox_id || ''"
        :class="SELECT_CLASS"
        @change="update('inbox_id', Number($event.target.value) || null)"
      >
        <option value="" disabled>Selecione a caixa de entrada</option>
        <option
          v-for="inbox in visibleInboxes()"
          :key="inbox.id"
          :value="inbox.id"
        >
          {{ inbox.name }}
        </option>
      </select>
      <p :class="HINT_CLASS">
        O fluxo só começa nessa caixa, depois de publicado.
      </p>
    </div>

    <div v-if="type === 'incoming_message_trigger'">
      <label :class="LABEL_CLASS">Quando começar</label>
      <select
        :value="config.occurrence || 'first'"
        :class="SELECT_CLASS"
        @change="update('occurrence', $event.target.value)"
      >
        <option value="first">Na primeira mensagem do contato</option>
        <option value="every">Em cada mensagem do contato</option>
      </select>
      <p :class="HINT_CLASS">
        Uma execução em andamento não é interrompida por outra mensagem. A
        resposta do contato continua no bloco Aguardar resposta.
      </p>
    </div>

    <div v-if="type === 'incoming_message_trigger'">
      <label :class="LABEL_CLASS">Palavra na mensagem</label>
      <input
        :value="config.keyword || ''"
        type="text"
        placeholder="Opcional, por exemplo: pedido"
        class="reset-base w-full h-9 m-0 px-3 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10"
        @input="update('keyword', $event.target.value)"
      />
      <p :class="HINT_CLASS">
        Em branco, qualquer texto do contato inicia o fluxo.
      </p>
    </div>

    <div v-if="type === 'conversation_created_trigger'">
      <p :class="HINT_CLASS">
        Dispara uma vez, no momento em que a conversa é criada nessa caixa.
      </p>
    </div>

    <div v-if="type === 'widget_opened_trigger'">
      <label :class="LABEL_CLASS">Frequência</label>
      <select
        :value="config.frequency || 'once_per_contact'"
        :class="SELECT_CLASS"
        @change="update('frequency', $event.target.value)"
      >
        <option value="once_per_contact">Uma vez por contato</option>
        <option value="every_open">Toda vez que o widget abrir</option>
      </select>
      <p v-if="!visibleInboxes().length" :class="HINT_CLASS">
        Nenhuma caixa de widget está conectada nesta conta.
      </p>
      <p v-else :class="HINT_CLASS">
        Se o visitante ainda não tiver conversa aberta, o fluxo abre uma.
      </p>
    </div>

    <div v-if="type === 'conversation_reopened_trigger'" class="space-y-2">
      <label :class="LABEL_CLASS">Reabrir a partir de</label>
      <label class="flex items-center gap-2 text-xs text-n-slate-12">
        <input
          type="checkbox"
          class="accent-n-brand"
          :checked="(config.from_statuses || []).includes('resolved')"
          @change="toggleStatus('resolved')"
        />
        Resolvida
      </label>
      <label class="flex items-center gap-2 text-xs text-n-slate-12">
        <input
          type="checkbox"
          class="accent-n-brand"
          :checked="(config.from_statuses || []).includes('snoozed')"
          @change="toggleStatus('snoozed')"
        />
        Adiada
      </label>
    </div>
  </div>
</template>
