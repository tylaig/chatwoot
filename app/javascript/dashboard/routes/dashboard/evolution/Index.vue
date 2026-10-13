<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import EvolutionAPI from 'dashboard/api/evolution';

const INPUT_CLASS =
  'reset-base w-full h-9 m-0 px-3 text-sm rounded-lg bg-n-alpha-black2 border-0 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12 placeholder:text-n-slate-10';

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
const creating = ref(false);
const qr = ref(null);
const webhook = ref(null);
const webhookEvents = ref([]);
const savingWebhook = ref(false);
let pollTimer = null;

const connected = computed(() => connection.value.status === 'connected');

const readError = error =>
  error?.response?.data?.error || 'Não foi possível falar com a Evolution API.';

const statusLabel = status => {
  const value = String(status || '').toLowerCase();
  if (['open', 'connected'].includes(value)) return 'Conectada';
  if (value === 'connecting') return 'Conectando';
  if (['close', 'closed', 'disconnected'].includes(value))
    return 'Desconectada';
  return status || 'Desconhecida';
};

const statusClass = status => {
  const value = String(status || '').toLowerCase();
  if (['open', 'connected'].includes(value)) return 'text-n-teal-11';
  if (value === 'connecting') return 'text-n-amber-11';
  return 'text-n-slate-11';
};

const applyConnection = data => {
  connection.value = data.connection || {
    configured: false,
    status: 'disconnected',
  };
  checks.value = data.checks || checks.value;
  if (connection.value.base_url) baseUrl.value = connection.value.base_url;
  if (data.version_changed) {
    versionNote.value = `A versão mudou de ${data.previous_version} para ${connection.value.version}.`;
  }
};

const loadInstances = async () => {
  loadingInstances.value = true;
  try {
    const { data } = await EvolutionAPI.getInstances();
    instances.value = data.instances || [];
  } catch (error) {
    useAlert(readError(error));
  } finally {
    loadingInstances.value = false;
  }
};

const loadConnection = async () => {
  const { data } = await EvolutionAPI.getConnection();
  applyConnection(data);
  if (connected.value) loadInstances();
};

const saveConnection = async () => {
  saving.value = true;
  versionNote.value = '';
  try {
    const { data } = await EvolutionAPI.saveConnection({
      base_url: baseUrl.value.trim(),
      api_key: apiKey.value,
    });
    apiKey.value = '';
    applyConnection(data);
    useAlert(
      `Conectado. Evolution API ${connection.value.version || ''}`.trim()
    );
    loadInstances();
  } catch (error) {
    checks.value = error?.response?.data?.checks || [];
    connection.value = {
      ...connection.value,
      status: 'error',
      last_error: readError(error),
    };
    useAlert(readError(error));
  } finally {
    saving.value = false;
  }
};

const syncVersion = async () => {
  syncing.value = true;
  try {
    const { data } = await EvolutionAPI.syncConnection();
    applyConnection(data);
    useAlert(
      data.version_changed
        ? `Versão atualizada para ${data.connection.version}.`
        : `Versão confirmada: ${data.connection.version}.`
    );
    loadInstances();
  } catch (error) {
    checks.value = error?.response?.data?.checks || checks.value;
    if (error?.response?.data?.connection) applyConnection(error.response.data);
    useAlert(readError(error));
  } finally {
    syncing.value = false;
  }
};

const createInstance = async () => {
  creating.value = true;
  try {
    await EvolutionAPI.createInstance({
      name: instanceName.value.trim(),
      number: instanceNumber.value.trim(),
    });
    instanceName.value = '';
    instanceNumber.value = '';
    await loadInstances();
  } catch (error) {
    useAlert(readError(error));
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
  stopPoll();
  try {
    const { data } = await EvolutionAPI.connectInstance(name);
    qr.value = { name, ...data };
    pollTimer = setInterval(async () => {
      try {
        const { data: state } = await EvolutionAPI.connectionState(name);
        if (String(state.state).toLowerCase() === 'open') {
          stopPoll();
          qr.value = null;
          useAlert(`${name} conectada.`);
          loadInstances();
        }
      } catch (error) {
        stopPoll();
      }
    }, 3000);
  } catch (error) {
    useAlert(readError(error));
  }
};

const runAction = async (action, name) => {
  try {
    await action(name);
    await loadInstances();
  } catch (error) {
    useAlert(readError(error));
  }
};

const openWebhook = async name => {
  try {
    const { data } = await EvolutionAPI.getWebhook(name);
    webhookEvents.value = data.events || [];
    webhook.value = {
      name,
      enabled: !!data.webhook?.enabled,
      url: data.webhook?.url || '',
      events: data.webhook?.events || [
        'QRCODE_UPDATED',
        'CONNECTION_UPDATE',
        'MESSAGES_UPSERT',
      ],
    };
  } catch (error) {
    useAlert(readError(error));
  }
};

const toggleEvent = eventName => {
  const current = webhook.value.events;
  webhook.value.events = current.includes(eventName)
    ? current.filter(item => item !== eventName)
    : [...current, eventName];
};

const saveWebhook = async () => {
  savingWebhook.value = true;
  try {
    await EvolutionAPI.saveWebhook(webhook.value.name, {
      enabled: webhook.value.enabled,
      url: webhook.value.url.trim(),
      events: webhook.value.events,
    });
    useAlert('Webhook salvo.');
    webhook.value = null;
  } catch (error) {
    useAlert(readError(error));
  } finally {
    savingWebhook.value = false;
  }
};

onMounted(loadConnection);
onUnmounted(stopPoll);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    class="flex flex-1 h-full min-h-0 min-w-0 bg-n-background text-n-slate-12 overflow-hidden"
  >
    <div class="flex flex-1 flex-col min-w-0 overflow-y-auto">
      <header class="px-6 py-5 border-b border-n-weak bg-n-solid-1">
        <h1 class="text-xl font-semibold">Evolution API</h1>
        <p class="mt-0.5 text-sm text-n-slate-11">
          Conecte o servidor, confira a versão e gerencie as instâncias.
        </p>
      </header>

      <section class="px-6 py-5 border-b border-n-weak">
        <div class="grid gap-3 md:grid-cols-2">
          <label class="block text-sm">
            <span class="mb-1 block text-n-slate-11">URL base</span>
            <input
              v-model="baseUrl"
              :class="INPUT_CLASS"
              placeholder="https://evolution.seudominio.com"
            />
          </label>
          <label class="block text-sm">
            <span class="mb-1 block text-n-slate-11">
              Chave de API
              <span v-if="connection.api_key_last4" class="text-n-slate-10">
                · salva ••••{{ connection.api_key_last4 }}
              </span>
            </span>
            <input
              v-model="apiKey"
              type="password"
              autocomplete="off"
              :class="INPUT_CLASS"
              placeholder="Cole a chave global para verificar"
            />
          </label>
        </div>
        <div class="mt-3 flex flex-wrap items-center gap-2">
          <button
            type="button"
            class="h-9 px-3 rounded-lg bg-n-brand text-white text-sm font-medium disabled:opacity-40"
            :disabled="saving || !baseUrl.trim()"
            @click="saveConnection"
          >
            {{ saving ? 'Verificando…' : 'Verificar e conectar' }}
          </button>
          <button
            type="button"
            class="h-9 px-3 rounded-lg bg-n-alpha-2 text-sm font-medium disabled:opacity-40"
            :disabled="syncing || !connection.configured"
            @click="syncVersion"
          >
            {{ syncing ? 'Sincronizando…' : 'Sincronizar versão' }}
          </button>
          <span v-if="connection.version" class="text-sm text-n-slate-11">
            Versão {{ connection.version }}
            <span v-if="connection.client_name">
              · {{ connection.client_name }}
            </span>
          </span>
        </div>
        <p v-if="versionNote" class="mt-2 text-sm text-n-amber-11">
          {{ versionNote }}
        </p>
        <p
          v-if="connection.last_error && !checks.length"
          class="mt-2 text-sm text-n-ruby-11"
        >
          {{ connection.last_error }}
        </p>
        <ul v-if="checks.length" class="mt-3 space-y-1">
          <li
            v-for="check in checks"
            :key="check.id"
            class="flex items-start gap-2 text-sm"
          >
            <span
              class="mt-0.5 size-4"
              :class="
                check.ok
                  ? check.warning
                    ? 'i-lucide-triangle-alert text-n-amber-11'
                    : 'i-lucide-circle-check text-n-teal-11'
                  : 'i-lucide-circle-x text-n-ruby-11'
              "
            />
            <span>
              <span class="font-medium">{{ check.label }}.</span>
              {{ check.detail }}
            </span>
          </li>
        </ul>
      </section>

      <section class="px-6 py-5">
        <div class="flex items-center justify-between gap-3">
          <h2 class="text-base font-semibold">Instâncias</h2>
          <p v-if="!connected" class="text-sm text-n-slate-11">
            A lista abre depois que a chave passar no pre-check.
          </p>
        </div>
        <form
          v-if="connected"
          class="mt-3 flex flex-wrap items-end gap-2"
          @submit.prevent="createInstance"
        >
          <label class="text-sm">
            <span class="mb-1 block text-n-slate-11">Nome</span>
            <input
              v-model="instanceName"
              :class="INPUT_CLASS"
              class="!w-52"
              placeholder="loja"
            />
          </label>
          <label class="text-sm">
            <span class="mb-1 block text-n-slate-11">Número para parear</span>
            <input
              v-model="instanceNumber"
              :class="INPUT_CLASS"
              class="!w-52"
              placeholder="5511999999999"
            />
          </label>
          <button
            type="submit"
            class="h-9 px-3 rounded-lg bg-n-brand text-white text-sm font-medium disabled:opacity-40"
            :disabled="creating || !instanceName.trim()"
          >
            Criar instância
          </button>
        </form>

        <div v-if="loadingInstances" class="mt-4 text-sm text-n-slate-11">
          Carregando instâncias…
        </div>
        <table v-else-if="instances.length" class="mt-4 w-full text-sm">
          <thead class="text-n-slate-11 text-start">
            <tr class="border-b border-n-weak">
              <th class="py-2 font-medium text-start">Nome</th>
              <th class="py-2 font-medium text-start">Número</th>
              <th class="py-2 font-medium text-start">Estado</th>
              <th class="py-2 font-medium text-end">Ações</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="item in instances"
              :key="item.name"
              class="border-b border-n-weak"
            >
              <td class="py-3">
                <p class="font-medium">{{ item.profile_name || item.name }}</p>
                <p class="text-xs text-n-slate-10">{{ item.name }}</p>
              </td>
              <td class="py-3">{{ item.owner || '—' }}</td>
              <td class="py-3" :class="statusClass(item.status)">
                {{ statusLabel(item.status) }}
              </td>
              <td class="py-3">
                <div class="flex justify-end gap-2">
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12"
                    @click="openConnect(item.name)"
                  >
                    Conectar
                  </button>
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12"
                    @click="runAction(EvolutionAPI.logoutInstance, item.name)"
                  >
                    Desconectar
                  </button>
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12"
                    @click="runAction(EvolutionAPI.restartInstance, item.name)"
                  >
                    Reiniciar
                  </button>
                  <button
                    type="button"
                    class="text-n-slate-11 hover:text-n-slate-12"
                    @click="openWebhook(item.name)"
                  >
                    Webhook
                  </button>
                  <button
                    type="button"
                    class="text-n-ruby-11"
                    @click="runAction(EvolutionAPI.deleteInstance, item.name)"
                  >
                    Excluir
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else-if="connected" class="mt-4 text-sm text-n-slate-11">
          Nenhuma instância nesse servidor.
        </p>
      </section>
    </div>

    <aside
      v-if="qr"
      class="w-[22rem] shrink-0 border-s border-n-weak bg-n-solid-1 p-5 overflow-y-auto"
    >
      <div class="flex items-center justify-between">
        <h2 class="font-semibold">Conectar {{ qr.name }}</h2>
        <button type="button" class="text-n-slate-11" @click="closeQr">
          Fechar
        </button>
      </div>
      <img
        v-if="qr.base64"
        :src="qr.base64"
        alt="QR Code"
        class="mt-4 w-full rounded-xl bg-white p-3"
      />
      <p v-else class="mt-4 text-sm text-n-slate-11">
        A Evolution não devolveu um QR. Tente de novo em instantes.
      </p>
      <p v-if="qr.pairing_code" class="mt-3 text-sm">
        Código de pareamento:
        <span class="font-mono">{{ qr.pairing_code }}</span>
      </p>
      <p class="mt-3 text-xs text-n-slate-10">
        A tela atualiza sozinha até o WhatsApp conectar.
      </p>
    </aside>

    <aside
      v-else-if="webhook"
      class="w-[22rem] shrink-0 border-s border-n-weak bg-n-solid-1 p-5 overflow-y-auto"
    >
      <div class="flex items-center justify-between">
        <h2 class="font-semibold">Webhook · {{ webhook.name }}</h2>
        <button type="button" class="text-n-slate-11" @click="webhook = null">
          Fechar
        </button>
      </div>
      <label class="mt-4 flex items-center gap-2 text-sm">
        <input v-model="webhook.enabled" type="checkbox" />
        Receber eventos
      </label>
      <label class="mt-3 block text-sm">
        <span class="mb-1 block text-n-slate-11">URL</span>
        <input
          v-model="webhook.url"
          :class="INPUT_CLASS"
          placeholder="https://seu-chatwoot/webhooks/evolution"
        />
      </label>
      <div class="mt-3 space-y-1">
        <label
          v-for="eventName in webhookEvents"
          :key="eventName"
          class="flex items-center gap-2 text-xs"
        >
          <input
            type="checkbox"
            :checked="webhook.events.includes(eventName)"
            @change="toggleEvent(eventName)"
          />
          {{ eventName }}
        </label>
      </div>
      <button
        type="button"
        class="mt-4 h-9 px-3 rounded-lg bg-n-brand text-white text-sm font-medium disabled:opacity-40"
        :disabled="savingWebhook"
        @click="saveWebhook"
      >
        Salvar webhook
      </button>
    </aside>
  </div>
</template>
