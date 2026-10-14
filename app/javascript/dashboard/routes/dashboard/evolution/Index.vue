<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import EvolutionAPI from 'dashboard/api/evolution';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const store = useStore();

const INPUT_CLASS =
  'reset-base w-full h-9 m-0 px-3 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10';

const EVENT_GROUPS = [
  {
    label: 'Conexão',
    events: ['QRCODE_UPDATED', 'CONNECTION_UPDATE', 'PRESENCE_UPDATE'],
  },
  {
    label: 'Mensagens',
    events: [
      'MESSAGES_UPSERT',
      'MESSAGES_UPDATE',
      'MESSAGES_DELETE',
      'SEND_MESSAGE',
    ],
  },
  {
    label: 'Contatos',
    events: [
      'CONTACTS_UPDATE',
      'CHATS_UPDATE',
      'GROUPS_UPSERT',
      'GROUP_PARTICIPANTS_UPDATE',
    ],
  },
];

const connection = ref({ configured: false, status: 'disconnected' });
const baseUrl = ref('');
const apiKey = ref('');
const checks = ref([]);
const versionNote = ref('');
const saving = ref(false);
const syncing = ref(false);
const instances = ref([]);
const loadingInstances = ref(false);
const instanceName = ref('');
const instanceNumber = ref('');
const createInbox = ref(false);
const importMessages = ref(false);
const creating = ref(false);
const chatwootTarget = ref('');
const connectingChatwoot = ref(false);
const qr = ref(null);
const webhook = ref(null);
const webhookEvents = ref([]);
const savingWebhook = ref(false);
const openMenu = ref('');
const deleteTarget = ref('');
const deleting = ref(false);
const serverDialog = ref(null);
const createDialog = ref(null);
const connectDialog = ref(null);
const webhookDialog = ref(null);
const deleteDialog = ref(null);
const chatwootDialog = ref(null);
let pollTimer = null;

const connected = computed(() => connection.value.status === 'connected');

const groupedEvents = computed(() =>
  EVENT_GROUPS.map(group => ({
    label: group.label,
    events: group.events.filter(event => webhookEvents.value.includes(event)),
  })).filter(group => group.events.length)
);

const readError = error =>
  error?.response?.data?.error || 'Não foi possível falar com a Evolution API.';

const statusLabel = status => {
  if (['open', 'connected'].includes(status)) return 'Conectada';
  if (status === 'connecting') return 'Conectando';
  if (['close', 'closed', 'disconnected'].includes(status))
    return 'Desconectada';
  return status || 'Desconhecida';
};

const statusClass = status => {
  if (['open', 'connected'].includes(status)) {
    return 'bg-n-teal-3 text-n-teal-11';
  }
  if (status === 'connecting') return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

const serverLabel = computed(() => {
  if (connection.value.status === 'connected') return 'Conectado';
  if (connection.value.status === 'error')
    return 'Falhou na última verificação';
  return 'Desconectado';
});

const checkedAt = computed(() => {
  const value = connection.value.last_checked_at;
  if (!value) return '';
  return new Date(value).toLocaleString('pt-BR');
});

const applyConnection = data => {
  const payload = data?.connection ||
    data || {
      configured: false,
      status: 'disconnected',
    };
  connection.value = payload;
  baseUrl.value = payload.base_url || '';
  versionNote.value = payload.version ? `Versão ${payload.version}` : '';
};

const loadInstances = async ({ silent = false } = {}) => {
  if (!connected.value) {
    instances.value = [];
    return;
  }
  if (!silent && !instances.value.length) loadingInstances.value = true;
  try {
    const { data } = await EvolutionAPI.getInstances();
    if (Array.isArray(data.instances)) instances.value = data.instances;
  } catch (error) {
    useAlert(readError(error));
  } finally {
    loadingInstances.value = false;
  }
};

const rememberInstance = name => {
  if (instances.value.some(item => item.name === name)) return;

  instances.value = [
    {
      name,
      status: 'close',
      owner: '',
      profile_name: '',
      profile_picture: '',
      integration: 'WHATSAPP-BAILEYS',
    },
    ...instances.value,
  ];
};

const loadConnection = async () => {
  const { data } = await EvolutionAPI.getConnection();
  applyConnection(data);
  await loadInstances();
};

const saveConnection = async () => {
  saving.value = true;
  checks.value = [];
  versionNote.value = '';
  try {
    const { data } = await EvolutionAPI.saveConnection({
      base_url: baseUrl.value,
      api_key: apiKey.value,
    });
    applyConnection(data.connection);
    checks.value = data.checks || [];
    apiKey.value = '';
    if (data.connection?.status === 'connected') {
      versionNote.value = data.connection.version
        ? `Versão ${data.connection.version} confirmada.`
        : '';
      serverDialog.value?.close();
      await loadInstances();
    }
  } catch (error) {
    const data = error?.response?.data;
    if (data?.checks) {
      applyConnection(data.connection || connection.value);
      checks.value = data.checks;
    }
    useAlert(readError(error));
  } finally {
    saving.value = false;
  }
};

const syncVersion = async () => {
  syncing.value = true;
  try {
    const { data } = await EvolutionAPI.syncConnection();
    applyConnection(data.connection);
    checks.value = data.checks || [];
    versionNote.value = data.connection?.version
      ? `Versão ${data.connection.version} confirmada.`
      : '';
    await loadInstances();
  } catch (error) {
    const data = error?.response?.data;
    if (data?.connection) applyConnection(data.connection);
    if (data?.checks) checks.value = data.checks;
    useAlert(readError(error));
  } finally {
    syncing.value = false;
  }
};

const linkChatwoot = async name => {
  const { data } = await EvolutionAPI.connectChatwoot(name, {
    import_messages: importMessages.value,
  });
  await store.dispatch('inboxes/get');
  useAlert(
    data?.inbox_name
      ? `Caixa ${data.inbox_name} criada no Chatwoot.`
      : 'Caixa de entrada criada no Chatwoot.'
  );
};

const createInstance = async () => {
  creating.value = true;
  const name = instanceName.value.trim();
  const shouldLink = createInbox.value;
  try {
    const { data } = await EvolutionAPI.createInstance({
      name,
      number: instanceNumber.value.trim(),
      connect_chatwoot: shouldLink,
      import_messages: importMessages.value,
    });
    instanceName.value = '';
    instanceNumber.value = '';
    createInbox.value = false;
    importMessages.value = false;
    createDialog.value?.close();
    rememberInstance(name);
    await loadInstances({ silent: true });
    rememberInstance(name);
    if (data?.chatwoot_error) useAlert(data.chatwoot_error);
    else if (shouldLink) {
      await store.dispatch('inboxes/get');
      useAlert(`Caixa ${name} criada no Chatwoot.`);
    }
    return true;
  } catch (error) {
    useAlert(readError(error));
    return false;
  } finally {
    creating.value = false;
  }
};

const stopPoll = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

const closeQr = () => {
  qr.value = null;
  stopPoll();
};

const openConnect = async name => {
  openMenu.value = '';
  stopPoll();
  try {
    const { data } = await EvolutionAPI.connectInstance(name);
    qr.value = { name, ...data };
    connectDialog.value?.open();
    pollTimer = setInterval(async () => {
      try {
        const state = await EvolutionAPI.connectionState(name);
        if (state.data?.state === 'open') {
          stopPoll();
          connectDialog.value?.close();
          qr.value = null;
          await loadInstances();
        }
      } catch {
        stopPoll();
      }
    }, 3000);
  } catch (error) {
    useAlert(readError(error));
  }
};

const runAction = async (action, name) => {
  openMenu.value = '';
  try {
    await action(name);
    await loadInstances();
  } catch (error) {
    useAlert(readError(error));
  }
};

const askDelete = name => {
  openMenu.value = '';
  deleteTarget.value = name;
  deleteDialog.value?.open();
};

const confirmDelete = async () => {
  deleting.value = true;
  const name = deleteTarget.value;
  try {
    await EvolutionAPI.deleteInstance(name);
    instances.value = instances.value.filter(item => item.name !== name);
    deleteDialog.value?.close();
    deleteTarget.value = '';
    await loadInstances({ silent: true });
    if (instances.value.some(item => item.name === name)) {
      await new Promise(resolve => {
        setTimeout(resolve, 1200);
      });
      await loadInstances({ silent: true });
      instances.value = instances.value.filter(item => item.name !== name);
    }
  } catch (error) {
    useAlert(readError(error));
  } finally {
    deleting.value = false;
  }
};

const askChatwoot = name => {
  openMenu.value = '';
  chatwootTarget.value = name;
  importMessages.value = false;
  chatwootDialog.value?.open();
};

const confirmChatwoot = async () => {
  connectingChatwoot.value = true;
  try {
    await linkChatwoot(chatwootTarget.value);
    chatwootDialog.value?.close();
    chatwootTarget.value = '';
    importMessages.value = false;
  } catch (error) {
    useAlert(readError(error));
  } finally {
    connectingChatwoot.value = false;
  }
};

const openWebhook = async name => {
  openMenu.value = '';
  try {
    const { data } = await EvolutionAPI.getWebhook(name);
    webhook.value = {
      name,
      enabled: Boolean(data.webhook?.enabled),
      url: data.webhook?.url || '',
      events: data.webhook?.events || [
        'QRCODE_UPDATED',
        'CONNECTION_UPDATE',
        'MESSAGES_UPSERT',
      ],
    };
    webhookEvents.value = data.events || [];
    webhookDialog.value?.open();
  } catch (error) {
    useAlert(readError(error));
  }
};

const toggleEvent = event => {
  const current = webhook.value.events;
  webhook.value.events = current.includes(event)
    ? current.filter(item => item !== event)
    : [...current, event];
};

const saveWebhook = async () => {
  savingWebhook.value = true;
  try {
    await EvolutionAPI.saveWebhook(webhook.value.name, {
      enabled: webhook.value.enabled,
      url: webhook.value.url,
      events: webhook.value.events,
    });
    webhookDialog.value?.close();
    webhook.value = null;
    useAlert('Webhook salvo.');
  } catch (error) {
    useAlert(readError(error));
  } finally {
    savingWebhook.value = false;
  }
};

onMounted(loadConnection);
onUnmounted(stopPoll);
</script>

<!-- eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template -->
<template>
  <section class="flex flex-col w-full h-full min-h-0 bg-n-surface-1">
    <header
      class="flex items-center justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">Evolution API</h1>
        <p class="mt-1 text-sm text-n-slate-11">
          Conecte o servidor e gerencie as instâncias de WhatsApp.
        </p>
      </div>
    </header>

    <div v-if="openMenu" class="fixed inset-0 z-30" @click="openMenu = ''" />

    <div class="flex-1 min-h-0 p-6 overflow-y-auto">
      <div class="flex flex-col gap-6 max-w-5xl">
        <article class="p-5 border rounded-2xl border-n-weak bg-n-solid-1">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex flex-col gap-1">
              <p
                class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
              >
                Servidor
              </p>
              <h2 class="text-base font-medium text-n-slate-12">
                {{ serverLabel }}
              </h2>
              <p class="text-sm text-n-slate-11">
                <template v-if="connected">
                  {{
                    versionNote ||
                    (connection.version
                      ? `Versão ${connection.version}`
                      : 'Versão não informada')
                  }}
                  <span v-if="connection.client_name">
                    · {{ connection.client_name }}
                  </span>
                  <span> · {{ instances.length }} instâncias</span>
                  <span v-if="checkedAt"> · verificado em {{ checkedAt }}</span>
                </template>
                <template v-else>
                  A chave só é gravada depois que a URL, a versão e a chave
                  passam na verificação.
                </template>
              </p>
              <p v-if="connection.last_error" class="text-sm text-n-ruby-11">
                {{ connection.last_error }}
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                v-if="connection.configured"
                type="button"
                class="h-9 px-3 text-sm rounded-lg text-n-slate-12 outline outline-1 outline-n-weak hover:bg-n-alpha-2 disabled:opacity-60"
                :disabled="syncing"
                @click="syncVersion"
              >
                {{ syncing ? 'Sincronizando…' : 'Sincronizar versão' }}
              </button>
              <button
                type="button"
                class="h-9 px-3 text-sm font-medium rounded-lg bg-n-brand text-white"
                @click="serverDialog.open()"
              >
                Configurar servidor
              </button>
            </div>
          </div>
        </article>

        <section class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-3">
            <h2 class="text-sm font-medium text-n-slate-12">Instâncias</h2>
            <button
              v-if="connected"
              type="button"
              class="h-9 px-3 text-sm font-medium rounded-lg bg-n-brand text-white"
              @click="createDialog.open()"
            >
              Nova instância
            </button>
          </div>

          <p v-if="!connected" class="text-sm text-n-slate-11">
            Conecte o servidor para listar as instâncias.
          </p>
          <p v-else-if="loadingInstances" class="text-sm text-n-slate-11">
            Carregando instâncias…
          </p>
          <div
            v-else-if="!instances.length"
            class="flex flex-col items-start gap-3 p-6 border border-dashed rounded-2xl border-n-weak"
          >
            <p class="text-sm text-n-slate-11">
              Nenhuma instância neste servidor.
            </p>
            <button
              type="button"
              class="h-9 px-3 text-sm font-medium rounded-lg bg-n-brand text-white"
              @click="createDialog.open()"
            >
              Nova instância
            </button>
          </div>
          <div v-else class="grid gap-3 sm:grid-cols-2">
            <article
              v-for="item in instances"
              :key="item.name"
              class="relative flex gap-3 p-4 border rounded-2xl border-n-weak bg-n-solid-1"
              :class="openMenu === item.name ? 'z-40' : ''"
            >
              <img
                v-if="item.profile_picture"
                :src="item.profile_picture"
                alt=""
                class="object-cover rounded-full size-11 shrink-0"
              />
              <span
                v-else
                class="flex items-center justify-center rounded-full size-11 shrink-0 bg-n-alpha-2 text-n-slate-11"
              >
                <span class="i-lucide-smartphone size-5" />
              </span>
              <div class="flex flex-col flex-1 min-w-0 gap-1">
                <div class="flex items-start justify-between gap-2">
                  <p class="text-sm font-medium truncate text-n-slate-12">
                    {{ item.profile_name || item.name }}
                  </p>
                  <button
                    type="button"
                    class="flex items-center justify-center rounded-lg size-8 text-n-slate-11 hover:bg-n-alpha-2"
                    @click="openMenu = openMenu === item.name ? '' : item.name"
                  >
                    <span class="i-lucide-ellipsis size-4" />
                  </button>
                </div>
                <p class="text-xs truncate text-n-slate-11">
                  {{ item.name }}
                  <span v-if="item.owner"> · {{ item.owner }}</span>
                </p>
                <span
                  class="self-start px-2 py-0.5 text-xs font-medium rounded-full"
                  :class="statusClass(item.status)"
                >
                  {{ statusLabel(item.status) }}
                </span>
              </div>
              <div
                v-if="openMenu === item.name"
                class="absolute z-20 flex flex-col w-44 p-1 border rounded-xl shadow-lg end-3 top-12 bg-n-solid-2 border-n-weak"
              >
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                  @click="openConnect(item.name)"
                >
                  Conectar
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                  @click="runAction(EvolutionAPI.logoutInstance, item.name)"
                >
                  Desconectar
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                  @click="runAction(EvolutionAPI.restartInstance, item.name)"
                >
                  Reiniciar
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                  @click="openWebhook(item.name)"
                >
                  Webhook
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                  @click="askChatwoot(item.name)"
                >
                  Conectar ao Chatwoot
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-sm text-start rounded-lg text-n-ruby-11 hover:bg-n-alpha-2"
                  @click="askDelete(item.name)"
                >
                  Excluir
                </button>
              </div>
            </article>
          </div>
        </section>
      </div>
    </div>

    <Dialog
      ref="serverDialog"
      type="edit"
      width="lg"
      title="Configurar servidor"
      description="A chave só fica salva se a URL, a versão e a chave passarem."
      confirm-button-label="Verificar e conectar"
      :is-loading="saving"
      :disable-confirm-button="!baseUrl.trim()"
      @confirm="saveConnection"
    >
      <div class="flex flex-col gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          URL da Evolution API
          <input
            v-model="baseUrl"
            type="url"
            :class="INPUT_CLASS"
            placeholder="https://sua-evolution.com"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          Chave global
          <input
            v-model="apiKey"
            type="password"
            autocomplete="off"
            :class="INPUT_CLASS"
            :placeholder="
              connection.api_key_set
                ? `Salva ••••${connection.api_key_last4}`
                : 'Cole a chave'
            "
          />
        </label>
        <ul v-if="checks.length" class="flex flex-col gap-1 text-sm">
          <li
            v-for="check in checks"
            :key="check.step"
            :class="check.ok ? 'text-n-teal-11' : 'text-n-ruby-11'"
          >
            {{ check.ok ? 'Ok' : 'Falhou' }} — {{ check.detail }}
          </li>
        </ul>
      </div>
    </Dialog>

    <Dialog
      ref="createDialog"
      type="edit"
      width="md"
      title="Nova instância"
      description="O WhatsApp desta instância usa a conexão não oficial do WhatsApp Web."
      confirm-button-label="Criar instância"
      :is-loading="creating"
      :disable-confirm-button="!instanceName.trim()"
      @confirm="createInstance"
    >
      <div class="flex flex-col gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          Nome
          <input
            v-model="instanceName"
            :class="INPUT_CLASS"
            placeholder="loja"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          Número com DDI, opcional
          <input
            v-model="instanceNumber"
            :class="INPUT_CLASS"
            placeholder="5511999999999"
          />
        </label>
        <label class="flex items-start gap-2 text-sm text-n-slate-12">
          <input v-model="createInbox" type="checkbox" class="mt-1" />
          <span>
            Criar a caixa de entrada no Chatwoot
            <span class="block mt-1 text-xs text-n-slate-11">
              A Evolution cria uma caixa do tipo API e passa a entregar as
              mensagens nela.
            </span>
          </span>
        </label>
        <label
          v-if="createInbox"
          class="flex items-start gap-2 text-sm text-n-slate-12"
        >
          <input v-model="importMessages" type="checkbox" class="mt-1" />
          <span>Importar as mensagens dos últimos 7 dias</span>
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="chatwootDialog"
      type="edit"
      width="md"
      :title="
        chatwootTarget
          ? `Conectar ${chatwootTarget} ao Chatwoot`
          : 'Conectar ao Chatwoot'
      "
      description="Cria a caixa de entrada desta instância e liga o recebimento das mensagens."
      confirm-button-label="Criar caixa"
      :is-loading="connectingChatwoot"
      @confirm="confirmChatwoot"
    >
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input v-model="importMessages" type="checkbox" class="mt-1" />
        <span>Importar as mensagens dos últimos 7 dias</span>
      </label>
    </Dialog>

    <Dialog
      ref="connectDialog"
      type="edit"
      width="md"
      title="Conectar WhatsApp"
      :description="qr ? qr.name : ''"
      :show-confirm-button="false"
      cancel-button-label="Fechar"
      @close="closeQr"
    >
      <div v-if="qr" class="flex flex-col items-center gap-3">
        <img
          v-if="qr.base64"
          :src="
            qr.base64.startsWith('data:')
              ? qr.base64
              : `data:image/png;base64,${qr.base64}`
          "
          alt="QR Code"
          class="rounded-xl size-64 bg-white"
        />
        <p v-else class="text-sm text-n-slate-11">
          O QR ainda não chegou. A tela continua consultando o telefone.
        </p>
        <p v-if="qr.pairing_code" class="text-sm text-n-slate-12">
          Código de pareamento: {{ qr.pairing_code }}
        </p>
        <p class="text-sm text-center text-n-slate-11">
          A tela espera o celular confirmar a conexão.
        </p>
      </div>
    </Dialog>

    <Dialog
      ref="webhookDialog"
      type="edit"
      width="lg"
      overflow-y-auto
      :title="webhook ? `Webhook · ${webhook.name}` : 'Webhook'"
      description="A URL precisa ser pública. O QR desta tela atualiza por consulta, sem webhook."
      confirm-button-label="Salvar webhook"
      :is-loading="savingWebhook"
      @confirm="saveWebhook"
    >
      <div v-if="webhook" class="flex flex-col gap-4">
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input v-model="webhook.enabled" type="checkbox" />
          Webhook ativo
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          URL
          <input
            v-model="webhook.url"
            type="url"
            :class="INPUT_CLASS"
            placeholder="https://seu-dominio/webhook"
          />
        </label>
        <div
          v-for="group in groupedEvents"
          :key="group.label"
          class="flex flex-col gap-2"
        >
          <p
            class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
          >
            {{ group.label }}
          </p>
          <div class="grid grid-cols-2 gap-2">
            <label
              v-for="event in group.events"
              :key="event"
              class="flex items-center gap-2 text-xs text-n-slate-12"
            >
              <input
                type="checkbox"
                :checked="webhook.events.includes(event)"
                @change="toggleEvent(event)"
              />
              {{ event }}
            </label>
          </div>
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialog"
      type="alert"
      width="md"
      title="Excluir instância"
      :description="`Excluir ${deleteTarget}? O WhatsApp dessa instância deixa de receber mensagens por aqui.`"
      confirm-button-label="Excluir"
      :is-loading="deleting"
      @confirm="confirmDelete"
    />
  </section>
</template>
