<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import WebhookDispatchApi from 'dashboard/api/webhookDispatchTriggers';

const props = defineProps({
  trigger: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'updated']);
const router = useRouter();

const EXAMPLE_PAYLOAD = {
  customer: {
    name: 'Maria',
    phone: '5511999990000',
  },
  order: {
    id: 'ORD-1',
    total: '150.00',
  },
};

const running = ref('');
const errorText = ref('');
const result = ref(null);
const payloadText = ref('');
const copied = ref(false);

const webhookUrl = computed(
  () => `${window.location.origin}/webhooks/trigger/${props.trigger.token}`
);

const sourcePayload = () => {
  const pinned = props.trigger.pinned_payload;
  if (props.trigger.payload_pinned && pinned && Object.keys(pinned).length) {
    return pinned;
  }
  const sample = props.trigger.sample_payload;
  if (sample && Object.keys(sample).length) return sample;
  return EXAMPLE_PAYLOAD;
};

const displayValue = value => {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
};

watch(
  () => props.trigger.id,
  () => {
    payloadText.value = JSON.stringify(sourcePayload(), null, 2);
    result.value = null;
    errorText.value = '';
    running.value = '';
  },
  { immediate: true }
);

const parsePayload = () => {
  let parsed;
  try {
    parsed = JSON.parse(payloadText.value);
  } catch {
    errorText.value = 'Esse texto não é um JSON válido.';
    return null;
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    errorText.value =
      'Cole um objeto JSON, por exemplo { "customer": { "phone": "5511999990000" } }.';
    return null;
  }
  errorText.value = '';
  return parsed;
};

const submit = async mode => {
  const payload = parsePayload();
  if (!payload || running.value) return;
  running.value = mode;
  result.value = null;
  try {
    const { data } = await WebhookDispatchApi.testTrigger(props.trigger.id, {
      payload,
      save: mode === 'save',
      execute: mode === 'execute',
    });
    result.value = data;
    if (data.trigger) emit('updated', data.trigger);
  } catch (error) {
    const data = error.response?.data;
    if (data && typeof data === 'object') {
      result.value = data;
      if (data.trigger) emit('updated', data.trigger);
      errorText.value = data.error || 'Não foi possível testar este webhook.';
    } else {
      errorText.value = 'Não foi possível testar este webhook.';
    }
  } finally {
    running.value = '';
  }
};

const copyUrl = async () => {
  await navigator.clipboard.writeText(webhookUrl.value);
  copied.value = true;
  window.setTimeout(() => {
    copied.value = false;
  }, 2000);
};

const openExecution = () => {
  const executionId = result.value?.workflow_execution_id;
  const workflowId = props.trigger.workflow?.id;
  if (!executionId || !workflowId) return;
  emit('close');
  router.push({
    name: 'workflow_execution_detail',
    params: { workflowId, executionId },
  });
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 p-6"
    @click.self="emit('close')"
  >
    <div
      class="flex w-full max-w-xl max-h-[90vh] flex-col rounded-2xl border border-n-weak bg-n-solid-1"
    >
      <div
        class="flex items-start justify-between gap-3 px-5 py-4 border-b border-n-weak"
      >
        <div class="min-w-0">
          <h2 class="text-base font-semibold text-n-slate-12">
            Testar disparo
          </h2>
          <p class="mt-0.5 truncate text-xs text-n-slate-11">
            {{ trigger.name }}
          </p>
        </div>
        <button
          type="button"
          class="flex size-8 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>

      <div class="flex-1 overflow-auto px-5 py-4 space-y-4">
        <div>
          <label class="mb-1.5 block text-xs font-medium text-n-slate-11">
            Endpoint
          </label>
          <div
            class="flex items-center gap-2 rounded-lg bg-n-alpha-1 px-3 h-9 outline outline-1 outline-n-weak"
          >
            <span class="text-[0.625rem] font-bold text-n-amber-11">POST</span>
            <span
              class="min-w-0 flex-1 truncate font-mono text-[0.6875rem] text-n-slate-12"
            >
              {{ webhookUrl }}
            </span>
            <button
              type="button"
              class="shrink-0 text-n-slate-11 hover:text-n-slate-12"
              @click="copyUrl"
            >
              <span
                class="size-3.5"
                :class="copied ? 'i-lucide-check' : 'i-lucide-copy'"
              />
            </button>
          </div>
        </div>

        <div>
          <label class="mb-1.5 block text-xs font-medium text-n-slate-11">
            JSON enviado
          </label>
          <textarea
            v-model="payloadText"
            rows="9"
            spellcheck="false"
            class="reset-base m-0 w-full rounded-xl bg-n-alpha-1 px-3 py-2 font-mono text-xs text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand border-0"
          />
          <p class="mt-1.5 text-[0.6875rem] text-n-slate-11">
            Simular só lê o mapeamento. Salvar exemplo deixa esse JSON pinado
            para os campos do painel. Executar cria o contato e roda o fluxo.
          </p>
        </div>

        <p v-if="errorText" class="text-xs text-n-ruby-11">{{ errorText }}</p>

        <div
          v-if="result"
          class="space-y-2 rounded-xl border border-n-weak bg-n-alpha-1 p-3 text-xs"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">Telefone</span>
            <span class="font-mono text-n-slate-12">
              {{ displayValue(result.phone) }}
            </span>
          </div>
          <p class="text-[0.6875rem] text-n-slate-10">
            Caminho {{ result.phone_path }}
          </p>
          <div class="flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">Nome</span>
            <span class="font-mono text-n-slate-12">
              {{ displayValue(result.name) }}
            </span>
          </div>
          <div class="flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">E-mail</span>
            <span class="font-mono text-n-slate-12">
              {{ displayValue(result.email) }}
            </span>
          </div>
          <div class="flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">Identificador</span>
            <span class="font-mono text-n-slate-12">
              {{ displayValue(result.identifier) }}
            </span>
          </div>
          <div class="flex items-center justify-between gap-2">
            <span class="font-medium text-n-slate-12">Etiquetas</span>
            <span class="font-mono text-n-slate-12">
              {{ displayValue((result.labels || []).join(', ')) }}
            </span>
          </div>
          <div
            v-for="row in [
              ...(result.attributes || []),
              ...(result.conversation_attributes || []),
            ]"
            :key="`${row.attribute_key}-${row.source_path}`"
            class="flex items-center justify-between gap-2"
          >
            <span class="truncate text-n-slate-11">
              {{ row.attribute_key || row.source_path }}
            </span>
            <span class="truncate font-mono text-n-slate-12">
              {{ displayValue(row.value) }}
            </span>
          </div>
          <p
            v-for="warning in result.warnings || []"
            :key="warning"
            class="text-[0.6875rem] text-n-ruby-11"
          >
            {{ warning }}
          </p>
          <p
            v-if="result.valid === false && !(result.warnings || []).length"
            class="text-[0.6875rem] text-n-ruby-11"
          >
            Não foi possível identificar o contato nesse JSON.
          </p>
          <button
            v-if="result.workflow_execution_id"
            type="button"
            class="inline-flex items-center gap-1.5 font-medium text-n-brand hover:underline"
            @click="openExecution"
          >
            <span class="i-lucide-play size-3.5" />
            Execução #{{ result.workflow_execution_id }}
          </button>
        </div>
      </div>

      <div
        class="flex flex-wrap items-center justify-end gap-2 border-t border-n-weak px-5 py-4"
      >
        <button
          type="button"
          class="h-9 px-3 rounded-lg border border-n-weak text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
          :disabled="Boolean(running)"
          @click="submit('preview')"
        >
          {{ running === 'preview' ? 'Simulando…' : 'Simular' }}
        </button>
        <button
          type="button"
          class="h-9 px-3 rounded-lg border border-n-weak text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
          :disabled="Boolean(running)"
          @click="submit('save')"
        >
          {{ running === 'save' ? 'Salvando…' : 'Salvar exemplo' }}
        </button>
        <button
          type="button"
          class="h-9 px-3 rounded-lg bg-n-brand text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50"
          :disabled="Boolean(running) || !trigger.workflow"
          :title="trigger.workflow ? '' : 'Vincule um fluxo antes de executar'"
          @click="submit('execute')"
        >
          {{ running === 'execute' ? 'Executando…' : 'Executar no fluxo' }}
        </button>
      </div>
    </div>
  </div>
</template>
