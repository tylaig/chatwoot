<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import WorkflowsAPI from 'dashboard/api/workflows';

const props = defineProps({
  workflowId: {
    type: [String, Number],
    required: true,
  },
});

const emit = defineEmits(['close', 'highlight']);

const STATUS_LABELS = {
  running: 'Executando',
  waiting: 'Aguardando você',
  completed: 'Encerrado',
  failed: 'Falhou',
  cancelled: 'Cancelado',
};

const session = ref(null);
const draft = ref('');
const loading = ref(true);
const busy = ref(false);
const errorText = ref('');
const thread = ref(null);

const transcript = computed(() => session.value?.transcript || []);
const waiting = computed(() => session.value?.status === 'waiting');
const choices = computed(() =>
  waiting.value ? session.value?.choices || [] : []
);

const applySession = value => {
  session.value = value;
  emit('highlight', value?.current_node_id || null);
  nextTick(() => {
    if (thread.value) thread.value.scrollTop = thread.value.scrollHeight;
  });
};

const readError = error =>
  error?.response?.data?.error?.[0] || 'Não foi possível continuar o teste.';

const restart = async () => {
  busy.value = true;
  errorText.value = '';
  try {
    const { data } = await WorkflowsAPI.startFlowTest(props.workflowId);
    draft.value = '';
    applySession(data.session);
  } catch (error) {
    errorText.value = readError(error);
  } finally {
    busy.value = false;
  }
};

const send = async (choiceId = null) => {
  const content = choiceId ? '' : draft.value.trim();
  if (!choiceId && !content) return;
  busy.value = true;
  errorText.value = '';
  try {
    const { data } = await WorkflowsAPI.replyFlowTest(props.workflowId, {
      content,
      choice_id: choiceId,
    });
    draft.value = '';
    applySession(data.session);
  } catch (error) {
    errorText.value = readError(error);
  } finally {
    busy.value = false;
  }
};

const simulateTimeout = async () => {
  busy.value = true;
  errorText.value = '';
  try {
    const { data } = await WorkflowsAPI.timeoutFlowTest(props.workflowId);
    applySession(data.session);
  } catch (error) {
    errorText.value = readError(error);
  } finally {
    busy.value = false;
  }
};

onMounted(async () => {
  try {
    const { data } = await WorkflowsAPI.getFlowTest(props.workflowId);
    if (data.session?.status === 'waiting') applySession(data.session);
    else await restart();
  } catch (error) {
    errorText.value = readError(error);
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <aside
    class="flex flex-col w-[24rem] shrink-0 h-full border-s border-n-weak bg-n-solid-1"
  >
    <header
      class="h-14 px-4 border-b border-n-weak flex items-center justify-between gap-2 shrink-0"
    >
      <div class="min-w-0">
        <p class="text-sm font-semibold text-n-slate-12">Teste do fluxo</p>
        <p class="text-[0.6875rem] text-n-slate-10 truncate">
          {{ STATUS_LABELS[session?.status] || 'Rascunho atual' }}
        </p>
      </div>
      <div class="flex items-center gap-1">
        <button
          type="button"
          class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40"
          title="Recomeçar"
          :disabled="busy"
          @click="restart"
        >
          <span class="i-lucide-rotate-ccw size-4" />
        </button>
        <button
          type="button"
          class="flex items-center justify-center size-8 rounded-lg text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
          title="Fechar"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </header>

    <div
      ref="thread"
      class="flex-1 min-h-0 overflow-y-auto px-4 py-4 space-y-3"
    >
      <p v-if="loading" class="text-sm text-n-slate-10 flex items-center gap-2">
        <span class="i-lucide-loader-circle size-4 animate-spin" />
        Preparando o chat…
      </p>

      <template v-for="entry in transcript" :key="entry.id">
        <p
          v-if="entry.kind === 'step' || entry.activity"
          class="text-center text-[0.6875rem] text-n-slate-10"
        >
          {{ entry.content }}
        </p>
        <p
          v-else-if="entry.kind === 'error'"
          class="text-center text-xs text-n-ruby-11"
        >
          {{ entry.content }}
        </p>
        <div
          v-else
          class="flex"
          :class="entry.kind === 'contact' ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[85%] rounded-2xl px-3 py-2 text-sm whitespace-pre-wrap"
            :class="
              entry.kind === 'contact'
                ? 'bg-n-brand text-white'
                : 'bg-n-alpha-2 text-n-slate-12'
            "
          >
            <p
              v-if="entry.private"
              class="mb-1 text-[0.6875rem] font-semibold text-n-slate-10"
            >
              Nota interna
            </p>
            {{ entry.content }}
          </div>
        </div>
      </template>

      <p v-if="waiting" class="text-center text-[0.6875rem] text-n-slate-10">
        Aguardando a resposta do contato
      </p>
      <p
        v-else-if="session?.status === 'completed'"
        class="text-center text-[0.6875rem] text-n-slate-10"
      >
        Fluxo encerrado
      </p>
      <p
        v-if="session?.error"
        class="rounded-xl bg-n-ruby-9/10 px-3 py-2 text-xs text-n-ruby-11"
      >
        {{ session.error }}
      </p>
      <p v-if="errorText" class="text-xs text-n-ruby-11">{{ errorText }}</p>
    </div>

    <div class="shrink-0 border-t border-n-weak p-3 space-y-2">
      <p class="text-[0.6875rem] text-n-slate-10 leading-4">
        Usa o rascunho salvo. Não envia WhatsApp e não aparece na caixa. Atrasos
        são pulados. Aguardar resposta fica parado até você escrever.
      </p>
      <div v-if="choices.length" class="flex flex-wrap gap-1.5">
        <button
          v-for="choice in choices"
          :key="choice.id"
          type="button"
          class="h-8 px-3 rounded-full border border-n-weak text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40"
          :disabled="busy"
          @click="send(choice.id)"
        >
          {{ choice.title }}
        </button>
      </div>
      <form class="flex items-end gap-2" @submit.prevent="send()">
        <textarea
          v-model="draft"
          rows="1"
          class="reset-base m-0 min-h-10 max-h-24 flex-1 resize-none rounded-xl bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand disabled:opacity-50"
          placeholder="Escreva como o contato"
          :disabled="!waiting || busy"
          @keydown.enter.exact.prevent="send()"
        />
        <button
          type="submit"
          class="flex items-center justify-center size-10 rounded-xl bg-n-brand text-white disabled:opacity-40"
          :disabled="!waiting || busy || !draft.trim()"
          title="Enviar"
        >
          <span
            class="size-4"
            :class="
              busy ? 'i-lucide-loader-circle animate-spin' : 'i-lucide-send'
            "
          />
        </button>
      </form>
      <button
        v-if="waiting"
        type="button"
        class="text-[0.6875rem] font-medium text-n-slate-11 hover:text-n-slate-12"
        :disabled="busy"
        @click="simulateTimeout"
      >
        Simular tempo esgotado
      </button>
    </div>
  </aside>
</template>
