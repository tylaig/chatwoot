<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WorkflowsAPI from 'dashboard/api/workflows';
import { flattenPayload } from '../variables';
import { curlExample } from '../webhookMapping';
import WebhookFieldMapping from './WebhookFieldMapping.vue';

const props = defineProps({
  workflowId: {
    type: [String, Number],
    required: true,
  },
  trigger: {
    type: Object,
    default: null,
  },
  inboxes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:trigger']);
const router = useRouter();

const POLL_INTERVAL_MS = 2000;
const LISTEN_TIMEOUT_MS = 180000;
const MAPPING_GUESSES = {
  phone_path: /^(phone|phone_number|telefone|celular|whatsapp|mobile)$/i,
  name_path: /^(name|full_name|nome|nome_completo)$/i,
  email_path: /^(email|e-mail|mail)$/i,
  identifier_path: /^(identifier|external_id|customer_id)$/i,
  labels_path: /^(labels|tags|etiquetas)$/i,
};
const SELECT_CLASS =
  'w-full h-9 m-0 py-0 ps-3 text-xs rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12';

const isSaving = ref(false);
const isListening = ref(false);
const isRunning = ref(false);
const runAfterReceive = ref(false);
const showJson = ref(false);
const pasteOpen = ref(false);
const pasteText = ref('');
const pasteError = ref('');
const selectedInboxId = ref('');
let pollTimer = null;
let listenStartedAt = 0;
let baselineReceivedAt = null;

const webhookUrl = computed(() =>
  props.trigger ? `${window.location.origin}${props.trigger.path}` : ''
);
const activePayload = computed(() => {
  if (
    props.trigger?.payload_pinned &&
    Object.keys(props.trigger?.pinned_payload || {}).length
  ) {
    return props.trigger.pinned_payload;
  }
  return props.trigger?.sample_payload || {};
});
const hasPayload = computed(
  () => Object.keys(activePayload.value || {}).length > 0
);
const payloadFields = computed(() =>
  flattenPayload(activePayload.value, 'webhook').filter(
    field => !['{…}', '[…]'].includes(field.sample)
  )
);
function relativeFieldPath(path) {
  return path.replace(/^webhook\./, '');
}

const mappingFields = computed(() =>
  payloadFields.value.map(field => ({
    path: relativeFieldPath(field.path),
    sample: field.sample,
  }))
);
const prettyPayload = computed(() =>
  JSON.stringify(activePayload.value || {}, null, 2)
);
const mapping = computed(() => props.trigger?.field_mapping || {});
const contactAttributes = useMapGetter('attributes/getAttributesByModel');
const contactAttributeOptions = computed(() =>
  contactAttributes.value('contact_attribute')
);
const conversationAttributeOptions = computed(() =>
  contactAttributes.value('conversation_attribute')
);
const receivedAtLabel = computed(() =>
  props.trigger?.received_at
    ? new Date(props.trigger.received_at).toLocaleString('pt-BR')
    : ''
);
const curlText = computed(() => curlExample(webhookUrl.value, mapping.value));

watch(
  () => [props.trigger?.inbox_id, props.inboxes[0]?.id],
  ([inboxId, firstInboxId]) => {
    const id = inboxId || firstInboxId;
    selectedInboxId.value = id ? String(id) : '';
  },
  { immediate: true }
);

let saveRequestId = 0;

const saveTrigger = async attrs => {
  saveRequestId += 1;
  const requestId = saveRequestId;
  isSaving.value = true;
  try {
    const { data } = await WorkflowsAPI.upsertWebhookTrigger(
      props.workflowId,
      attrs
    );
    if (requestId !== saveRequestId) return null;
    emit('update:trigger', data.webhook_trigger);
    return data.webhook_trigger;
  } catch (error) {
    if (requestId !== saveRequestId) return null;
    useAlert(
      error.response?.status === 404
        ? 'Este fluxo não existe mais. Volte para a lista e abra um fluxo salvo.'
        : error.response?.data?.error?.join?.(' ') ||
            'Erro ao salvar o webhook.'
    );
    return null;
  } finally {
    if (requestId === saveRequestId) isSaving.value = false;
  }
};

const stopListening = () => {
  clearInterval(pollTimer);
  pollTimer = null;
  isListening.value = false;
  runAfterReceive.value = false;
};

const suggestMapping = async trigger => {
  const current = trigger.field_mapping || {};
  const paths = flattenPayload(trigger.sample_payload || {}, 'webhook')
    .filter(field => !['{…}', '[…]'].includes(field.sample))
    .map(field => relativeFieldPath(field.path));
  const guess = pattern =>
    paths.find(path => pattern.test(path.split('.').pop()));
  const suggestion = {};
  Object.entries(MAPPING_GUESSES).forEach(([key, pattern]) => {
    if (current[key]) return;
    const guessed = guess(pattern);
    if (guessed) suggestion[key] = guessed;
  });
  if (Object.keys(suggestion).length) {
    await saveTrigger({ field_mapping: suggestion });
  }
};

async function executeTest() {
  isRunning.value = true;
  try {
    const { data } = await WorkflowsAPI.testWebhook(props.workflowId);
    useAlert(`Teste iniciado. Execução #${data.execution_id}.`);
  } catch (error) {
    useAlert(
      error.response?.data?.error?.join(' ') ||
        'Não foi possível executar o teste.'
    );
  } finally {
    isRunning.value = false;
  }
}

const pollTrigger = async () => {
  if (Date.now() - listenStartedAt > LISTEN_TIMEOUT_MS) {
    stopListening();
    useAlert('Nenhuma requisição recebida em 3 minutos.');
    return;
  }
  const { data } = await WorkflowsAPI.getWebhookTrigger(props.workflowId);
  const trigger = data.webhook_trigger;
  if (!trigger?.received_at || trigger.received_at === baselineReceivedAt) {
    return;
  }

  const shouldRun = runAfterReceive.value;
  stopListening();
  emit('update:trigger', trigger);
  await suggestMapping(trigger);
  if (shouldRun) {
    useAlert('Requisição recebida. Executando o teste…');
    executeTest();
    return;
  }
  useAlert('Requisição recebida! Os campos já estão disponíveis.');
};

const startListening = () => {
  listenStartedAt = Date.now();
  baselineReceivedAt = props.trigger?.received_at || null;
  isListening.value = true;
  pollTimer = setInterval(pollTrigger, POLL_INTERVAL_MS);
};

const runTest = async () => {
  if (!hasPayload.value) {
    runAfterReceive.value = true;
    if (!isListening.value) startListening();
    useAlert('Aguardando uma requisição para executar o teste.');
    return;
  }
  await executeTest();
};

const openPaste = () => {
  pasteText.value = hasPayload.value ? prettyPayload.value : '';
  pasteError.value = '';
  pasteOpen.value = true;
};

const applyPastedJson = async () => {
  let parsed;
  try {
    parsed = JSON.parse(pasteText.value);
  } catch {
    pasteError.value = 'Esse texto não é um JSON válido.';
    return;
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    pasteError.value =
      'Cole um objeto JSON, por exemplo { "customer": { "phone": "5511999990000" } }.';
    return;
  }

  pasteError.value = '';
  const trigger = await saveTrigger({
    sample_payload: parsed,
    payload_pinned: true,
  });
  if (!trigger) return;
  pasteOpen.value = false;
  showJson.value = true;
  await suggestMapping(trigger);
  useAlert('JSON de exemplo salvo e pinado.');
};

const togglePin = () => {
  if (!hasPayload.value && !props.trigger?.payload_pinned) {
    useAlert('Receba um payload antes de pinar.');
    return;
  }
  saveTrigger({ payload_pinned: !props.trigger?.payload_pinned });
};

async function copy(value, message) {
  await copyTextToClipboard(value);
  useAlert(message);
}

const openInWebhooks = () => {
  router.push({
    name: 'webhook_dispatch_index',
    query: { id: props.trigger.id },
  });
};

const updateMapping = (key, value) =>
  saveTrigger({ field_mapping: { [key]: value } });

const saveAttributeRows = rows =>
  saveTrigger({ field_mapping: { custom_attributes: rows } });

const saveConversationRows = rows =>
  saveTrigger({ field_mapping: { conversation_attributes: rows } });

onBeforeUnmount(stopListening);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="space-y-4">
    <div
      v-if="!trigger"
      class="p-4 rounded-xl border border-dashed border-n-strong space-y-3"
    >
      <div class="flex items-center gap-2">
        <span class="i-lucide-webhook size-4 text-n-amber-11" />
        <p class="text-sm font-semibold text-n-slate-12">
          Gerar URL do webhook
        </p>
      </div>
      <p class="text-xs text-n-slate-11">
        Escolha a caixa de entrada onde os contatos e conversas serão criados.
      </p>
      <select v-model="selectedInboxId" :class="SELECT_CLASS">
        <option value="" disabled>Selecione a caixa de entrada</option>
        <option
          v-for="inbox in inboxes"
          :key="inbox.id"
          :value="String(inbox.id)"
        >
          {{ inbox.name }}
        </option>
      </select>
      <button
        type="button"
        class="w-full h-9 rounded-lg bg-n-brand text-white text-sm font-medium hover:opacity-90 disabled:opacity-50 flex items-center justify-center gap-2"
        :disabled="!selectedInboxId || isSaving"
        @click="saveTrigger({ inbox_id: selectedInboxId })"
      >
        <span class="i-lucide-link size-4" />
        Gerar URL
      </button>
    </div>

    <template v-else>
      <div>
        <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
          >URL de produção</label
        >
        <div
          class="flex items-center gap-1.5 p-1 ps-2 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak"
        >
          <span
            class="px-1.5 py-0.5 rounded-md text-[0.625rem] font-bold bg-n-amber-9/15 text-n-amber-11"
            >POST</span
          >
          <span
            class="flex-1 min-w-0 truncate font-mono text-[0.6875rem] text-n-slate-12"
            >{{ webhookUrl }}</span
          >
          <button
            type="button"
            class="flex items-center justify-center size-7 rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
            title="Copiar URL"
            @click="copy(webhookUrl, 'URL copiada.')"
          >
            <span class="i-lucide-copy size-3.5" />
          </button>
        </div>
        <button
          type="button"
          class="mt-2 inline-flex items-center gap-1.5 text-xs font-medium text-n-brand hover:underline"
          @click="openInWebhooks"
        >
          <span class="i-lucide-webhook size-3.5" />
          {{ trigger.name || 'Webhook' }} · abrir na aba Webhooks
        </button>
      </div>

      <div>
        <label class="block mb-1.5 text-xs font-medium text-n-slate-12"
          >Caixa de entrada</label
        >
        <select
          :value="selectedInboxId"
          :class="SELECT_CLASS"
          @change="saveTrigger({ inbox_id: $event.target.value })"
        >
          <option
            v-for="inbox in inboxes"
            :key="inbox.id"
            :value="String(inbox.id)"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <div
        class="p-3 rounded-xl border space-y-3"
        :class="isListening ? 'border-n-brand bg-n-brand/5' : 'border-n-weak'"
      >
        <div class="flex items-center gap-2">
          <span
            class="size-2.5 rounded-full shrink-0"
            :class="
              isListening
                ? 'bg-n-brand animate-pulse'
                : trigger.received_at
                  ? 'bg-green-500'
                  : 'bg-n-slate-8'
            "
          />
          <p class="text-xs font-semibold text-n-slate-12 truncate">
            {{
              isListening
                ? runAfterReceive
                  ? 'Aguardando para executar…'
                  : 'Aguardando requisição…'
                : trigger.received_at
                  ? `Último payload: ${receivedAtLabel}`
                  : 'Nenhuma requisição recebida'
            }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-1.5">
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-xs font-medium bg-green-500 text-white hover:opacity-90 disabled:opacity-50 flex items-center gap-1.5"
            :disabled="isRunning"
            @click="runTest"
          >
            <span
              class="size-3.5"
              :class="
                isRunning
                  ? 'i-lucide-loader-circle animate-spin'
                  : 'i-lucide-play'
              "
            />
            Executar teste
          </button>
          <button
            type="button"
            class="h-8 px-2.5 rounded-lg text-xs font-medium flex items-center gap-1.5"
            :class="
              trigger.payload_pinned
                ? 'bg-n-amber-9/15 text-n-amber-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="togglePin"
          >
            <span class="i-lucide-pin size-3.5" />
            {{ trigger.payload_pinned ? 'Pinado' : 'Pinar dados' }}
          </button>
          <button
            type="button"
            class="h-8 px-2.5 rounded-lg text-xs font-medium flex items-center gap-1.5"
            :class="
              pasteOpen
                ? 'bg-n-alpha-2 text-n-slate-12'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="openPaste"
          >
            <span class="i-lucide-clipboard-paste size-3.5" />
            Colar JSON
          </button>
          <button
            type="button"
            class="h-8 px-2.5 rounded-lg text-xs font-medium flex items-center gap-1.5"
            :class="
              showJson
                ? 'bg-n-alpha-2 text-n-slate-12'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            :disabled="!hasPayload"
            @click="showJson = !showJson"
          >
            <span class="font-mono text-sm font-bold leading-none">{ }</span>
            JSON
          </button>
          <button
            v-if="!isListening"
            type="button"
            class="h-8 px-2.5 rounded-lg text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2 flex items-center gap-1.5"
            @click="startListening"
          >
            <span class="i-lucide-radio size-3.5" />
            Escutar
          </button>
          <button
            v-else
            type="button"
            class="h-8 px-2.5 rounded-lg text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2"
            @click="stopListening"
          >
            Cancelar
          </button>
        </div>
        <p
          v-if="trigger.payload_pinned"
          class="text-[0.6875rem] text-n-amber-11"
        >
          O teste e o mapeamento usam o payload pinado. Novas requisições não
          substituem esses dados.
        </p>
        <div v-if="isListening" class="space-y-1.5">
          <p class="text-[0.6875rem] text-n-slate-11">
            Envie uma requisição POST para a URL acima. Exemplo:
          </p>
          <pre
            class="p-2 rounded-lg bg-n-alpha-black2 text-[0.625rem] font-mono text-n-slate-12 whitespace-pre-wrap break-all"
            >{{ curlText }}</pre
          >
        </div>
      </div>

      <div v-if="pasteOpen" class="space-y-2">
        <label class="block text-xs font-medium text-n-slate-12">
          JSON de exemplo
        </label>
        <textarea
          v-model="pasteText"
          rows="8"
          spellcheck="false"
          placeholder='{"order":{"id":1234},"customer":{"name":"Maria","phone":"5511999990000"}}'
          class="reset-base w-full m-0 px-3 py-2 text-xs font-mono rounded-xl bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
        />
        <p v-if="pasteError" class="text-[0.6875rem] text-n-ruby-11">
          {{ pasteError }}
        </p>
        <p class="text-[0.6875rem] text-n-slate-11">
          O exemplo fica pinado, como no n8n. A árvore, o mapeamento e o teste
          usam esse JSON até você desafixar.
        </p>
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="h-8 px-3 rounded-lg bg-n-brand text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
            :disabled="isSaving || !pasteText.trim()"
            @click="applyPastedJson"
          >
            Usar este JSON
          </button>
          <button
            type="button"
            class="h-8 px-3 rounded-lg text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
            @click="pasteOpen = false"
          >
            Fechar
          </button>
        </div>
      </div>

      <div v-if="showJson && hasPayload" class="space-y-2">
        <div class="flex items-center justify-between">
          <p class="text-xs font-medium text-n-slate-12">Payload</p>
          <button
            type="button"
            class="inline-flex items-center gap-1 text-xs font-medium text-n-brand hover:underline"
            @click="copy(prettyPayload, 'JSON copiado.')"
          >
            <span class="i-lucide-copy size-3" />
            Copiar
          </button>
        </div>
        <pre
          class="max-h-48 overflow-auto p-3 rounded-xl bg-n-alpha-black2 text-[0.625rem] font-mono text-n-slate-12 whitespace-pre-wrap break-all"
          >{{ prettyPayload }}</pre
        >
      </div>

      <WebhookFieldMapping
        :mapping="mapping"
        :fields="mappingFields"
        :payload="hasPayload ? activePayload : null"
        :contact-attributes="contactAttributeOptions"
        :conversation-attributes="conversationAttributeOptions"
        @update-field="updateMapping"
        @update-contact-rows="saveAttributeRows"
        @update-conversation-rows="saveConversationRows"
      />
    </template>
  </div>
</template>
