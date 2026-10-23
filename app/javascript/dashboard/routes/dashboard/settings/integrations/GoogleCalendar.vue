<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRoute, useRouter } from 'vue-router';
import integrationAPI from 'dashboard/api/integrations';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();

const loading = ref(true);
const hooks = ref([]);
const schedules = ref([]);
const oauthConfigured = ref(false);
const hasCustomOauthCredentials = ref(false);
const redirectUri = ref('https://chat.meusuper.app/callbacks/google_calendar');

const showOauthConfigModal = ref(false);
const oauthClientId = ref('');
const oauthClientSecret = ref('');
const savingOauth = ref(false);

const showConnectModal = ref(false);
const editingHookId = ref(null);
const savingHook = ref(false);
const testingHookId = ref(null);
const syncingHookId = ref(null);
const startingOauthId = ref(null);

const hookForm = ref({
  connection_name: '',
  provider: 'google_calendar',
  calendar_email: '',
  calendar_id: 'primary',
  access_token: '',
  refresh_token: '',
  oauth_client_id: '',
  oauth_client_secret: '',
  schedule_ids: [],
  agent_ids: [],
});

const agents = useMapGetter('agents/getAgents');

const providers = [
  {
    id: 'google_calendar',
    label: 'Google Agenda & Workspace OAuth 2.0',
    badge: 'OAuth 2.0 & API',
    icon: 'i-lucide-calendar-check-2',
  },
  {
    id: 'caldav_ics',
    label: 'CalDAV / Apple iCloud / Agenda Corporativa',
    badge: 'Sincronização Bidirecional',
    icon: 'i-lucide-globe',
  },
  {
    id: 'microsoft_exchange',
    label: 'Microsoft 365 / Outlook Calendar',
    badge: 'OAuth / REST',
    icon: 'i-lucide-building-2',
  },
];

const loadData = async () => {
  try {
    loading.value = true;
    const { data } = await integrationAPI.getGoogleCalendarIntegrations();
    hooks.value = data.hooks || [];
    schedules.value = data.schedules || [];
    oauthConfigured.value = !!data.oauth_configured;
    hasCustomOauthCredentials.value = !!data.has_custom_oauth_credentials;
    if (data.redirect_uri) redirectUri.value = data.redirect_uri;
    if (
      data.oauth_client_id &&
      data.oauth_client_id !== 'configured_globally'
    ) {
      oauthClientId.value = data.oauth_client_id;
    }
  } catch {
    useAlert('Erro ao carregar central de integrações de agenda.');
  } finally {
    loading.value = false;
  }
};

const openNewConnection = () => {
  editingHookId.value = null;
  hookForm.value = {
    connection_name: '',
    provider: 'google_calendar',
    calendar_email: '',
    calendar_id: 'primary',
    access_token: '',
    refresh_token: '',
    oauth_client_id: '',
    oauth_client_secret: '',
    schedule_ids: schedules.value[0] ? [schedules.value[0].id] : [],
    agent_ids: [],
  };
  showConnectModal.value = true;
};

const openEditConnection = hook => {
  editingHookId.value = hook.id;
  hookForm.value = {
    connection_name: hook.settings?.connection_name || '',
    provider: hook.settings?.provider || 'google_calendar',
    calendar_email: hook.settings?.calendar_email || hook.reference_id || '',
    calendar_id: hook.settings?.calendar_id || 'primary',
    access_token: '',
    refresh_token: '',
    oauth_client_id: hook.settings?.oauth_client_id || '',
    oauth_client_secret: '',
    schedule_ids: Array.isArray(hook.settings?.schedule_ids)
      ? hook.settings.schedule_ids.map(Number)
      : [],
    agent_ids: Array.isArray(hook.settings?.agent_ids)
      ? hook.settings.agent_ids.map(Number)
      : [],
  };
  showConnectModal.value = true;
};

const toggleScheduleId = id => {
  const num = Number(id);
  if (hookForm.value.schedule_ids.includes(num)) {
    hookForm.value.schedule_ids = hookForm.value.schedule_ids.filter(
      x => x !== num
    );
  } else {
    hookForm.value.schedule_ids = [...hookForm.value.schedule_ids, num];
  }
};

const toggleAgentId = id => {
  const num = Number(id);
  if (hookForm.value.agent_ids.includes(num)) {
    hookForm.value.agent_ids = hookForm.value.agent_ids.filter(x => x !== num);
  } else {
    hookForm.value.agent_ids = [...hookForm.value.agent_ids, num];
  }
};

const saveOauthCredentials = async () => {
  try {
    savingOauth.value = true;
    const { data } = await integrationAPI.saveGoogleCalendarOauthCredentials({
      clientId: oauthClientId.value,
      clientSecret: oauthClientSecret.value,
    });
    oauthConfigured.value = !!data.oauth_configured;
    hasCustomOauthCredentials.value = !!data.has_custom_oauth_credentials;
    showOauthConfigModal.value = false;
    useAlert(data.message || 'Credenciais OAuth 2.0 salvas com sucesso!');
    await loadData();
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Erro ao salvar credenciais OAuth 2.0.'
    );
  } finally {
    savingOauth.value = false;
  }
};

const submitHookForm = async () => {
  if (
    !hookForm.value.connection_name.trim() &&
    !hookForm.value.calendar_email.trim()
  ) {
    useAlert('Informe o nome da conexão ou o e-mail da conta.');
    return;
  }
  try {
    savingHook.value = true;
    if (editingHookId.value) {
      await integrationAPI.updateGoogleCalendarHook({
        hook_id: editingHookId.value,
        ...hookForm.value,
      });
      useAlert('Conexão de calendário atualizada com sucesso!');
    } else {
      await integrationAPI.connectGoogleCalendarHook(hookForm.value);
      useAlert('Nova conexão de calendário adicionada e sincronizada!');
    }
    showConnectModal.value = false;
    await loadData();
    store.dispatch('integrations/get');
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Erro ao salvar conexão de calendário.'
    );
  } finally {
    savingHook.value = false;
  }
};

const triggerOauthFlow = async hook => {
  try {
    startingOauthId.value = hook?.id || 'new';
    const { data } = await integrationAPI.startGoogleCalendarOauth({
      hookId: hook?.id,
      scheduleId: hook?.settings?.schedule_ids?.[0] || schedules.value[0]?.id,
      returnTo: 'integrations',
    });
    if (data.oauth_configured && data.authorization_url) {
      window.location.href = data.authorization_url;
      return;
    }
    showOauthConfigModal.value = true;
    useAlert(
      data.error ||
        'Configure o Client ID e Client Secret OAuth 2.0 abaixo para autenticar com 1 clique ou adicione via Conexão Direta.'
    );
  } catch {
    useAlert('Não foi possível iniciar o fluxo OAuth 2.0.');
  } finally {
    startingOauthId.value = null;
  }
};

const testConnection = async hook => {
  try {
    testingHookId.value = hook.id;
    const { data } = await integrationAPI.testGoogleCalendarConnection(hook.id);
    useAlert(data.message || 'Conexão verificada com sucesso!');
    await loadData();
  } catch {
    useAlert('Falha ao testar conexão.');
  } finally {
    testingHookId.value = null;
  }
};

const syncConnection = async hook => {
  try {
    syncingHookId.value = hook.id;
    const { data } = await integrationAPI.syncGoogleCalendarEvents(hook.id);
    useAlert(data.message || 'Eventos e disponibilidade sincronizados!');
    await loadData();
  } catch {
    useAlert('Erro ao sincronizar agenda.');
  } finally {
    syncingHookId.value = null;
  }
};

const removeConnection = async hook => {
  try {
    await integrationAPI.deleteGoogleCalendarHook(hook.id, false);
    useAlert('Conexão removida.');
    await loadData();
    store.dispatch('integrations/get');
  } catch {
    useAlert('Erro ao remover conexão.');
  }
};

const copyText = txt => {
  navigator.clipboard?.writeText(txt);
  useAlert('Copiado para a área de transferência!');
};

const goToCalendarModule = () => {
  const accountId = route.params.accountId;
  router.push(`/app/accounts/${accountId}/agendamentos`);
};

const providerLabel = p =>
  providers.find(x => x.id === p)?.label || 'Google Agenda & Workspace';

onMounted(() => {
  store.dispatch('agents/get');
  loadData();
  if (route.query.google_connected) {
    useAlert('Conta autenticada via OAuth 2.0 e sincronizada com sucesso!');
  }
});
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    loading-message="Carregando conexões de agenda e credenciais OAuth 2.0..."
  >
    <template #header>
      <BaseSettingsHeader
        title="Integrações de Agenda & OAuth Multi-Contas"
        description="Conecte múltiplas contas de calendário via OAuth 2.0 ou Token Direto, vincule às agendas dos especialistas e sincronize conflitos em tempo real com o Agente IA."
        feature-name="integrations"
        back-button-label="Integrações"
      >
        <template #actions>
          <div class="flex flex-wrap items-center gap-2">
            <button
              type="button"
              class="px-3.5 py-2 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs font-medium text-slate-200 flex items-center gap-1.5 transition"
              @click="goToCalendarModule"
            >
              <span class="i-lucide-calendar-range size-4 text-emerald-400" />
              <span>Abrir Painel de Agendamentos</span>
            </button>
            <button
              type="button"
              class="px-3.5 py-2 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-xs font-medium text-emerald-300 flex items-center gap-1.5 transition"
              @click="showOauthConfigModal = true"
            >
              <span class="i-lucide-key-round size-4 text-emerald-400" />
              <span>Credenciais OAuth 2.0</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs flex items-center gap-1.5 shadow-lg transition"
              @click="openNewConnection"
            >
              <span class="i-lucide-plus size-4" />
              <span>Adicionar Conexão de Agenda</span>
            </button>
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-5 pb-10">
        <!-- Faixa de KPIs e Status OAuth -->
        <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3.5">
          <div
            class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between"
          >
            <div>
              <span
                class="text-[11px] text-slate-400 uppercase tracking-wider font-semibold"
              >
                Contas Conectadas
              </span>
              <div class="text-2xl font-bold text-[#F8FAFC] mt-1">
                {{ hooks.length }}
              </div>
              <span class="text-[11px] text-emerald-400">
                Multi-contas ativas
              </span>
            </div>
            <div
              class="w-11 h-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400"
            >
              <span class="i-lucide-calendar-check-2 size-5" />
            </div>
          </div>

          <div
            class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between"
          >
            <div>
              <span
                class="text-[11px] text-slate-400 uppercase tracking-wider font-semibold"
              >
                Especialistas c/ Agenda
              </span>
              <div class="text-2xl font-bold text-[#F8FAFC] mt-1">
                {{ schedules.length }}
              </div>
              <span class="text-[11px] text-emerald-400">
                {{ schedules.filter(s => s.google_connected).length }}
                sincronizados em tempo real
              </span>
            </div>
            <div
              class="w-11 h-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400"
            >
              <span class="i-lucide-users size-5" />
            </div>
          </div>

          <div
            class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between"
          >
            <div>
              <span
                class="text-[11px] text-slate-400 uppercase tracking-wider font-semibold"
              >
                Motor OAuth 2.0
              </span>
              <div class="text-base font-bold text-[#F8FAFC] mt-1">
                {{
                  oauthConfigured ? 'OAuth 2.0 Ativo' : 'Modo Direto / Token'
                }}
              </div>
              <button
                type="button"
                class="text-[11px] text-emerald-400 hover:underline mt-0.5"
                @click="showOauthConfigModal = true"
              >
                {{
                  oauthConfigured
                    ? 'Gerenciar Client ID / Secret →'
                    : 'Configurar Client ID OAuth →'
                }}
              </button>
            </div>
            <div
              class="w-11 h-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400"
            >
              <span class="i-lucide-shield-check size-5" />
            </div>
          </div>

          <div
            class="p-4 rounded-2xl bg-[#081218] border border-[#142633] flex items-center justify-between"
          >
            <div class="min-w-0 pr-2">
              <span
                class="text-[11px] text-slate-400 uppercase tracking-wider font-semibold"
              >
                Callback URI OAuth
              </span>
              <div
                class="text-xs font-mono text-emerald-400 truncate mt-1.5"
                :title="redirectUri"
              >
                {{ redirectUri }}
              </div>
              <button
                type="button"
                class="text-[11px] text-slate-300 hover:text-white mt-1"
                @click="copyText(redirectUri)"
              >
                Copiar Redirect URI
              </button>
            </div>
            <div
              class="w-11 h-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
            >
              <span class="i-lucide-webhook size-5" />
            </div>
          </div>
        </div>

        <!-- Lista de Conexões Múltiplas -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4"
        >
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[#132631]"
          >
            <div>
              <h3 class="text-sm font-semibold text-[#F8FAFC]">
                Conexões de Calendário Ativas ({{ hooks.length }})
              </h3>
              <p class="text-xs text-slate-400">
                Adicione quantas contas quiser e associe cada conta a um ou mais
                especialistas da equipe.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                class="px-3 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 text-xs font-semibold flex items-center gap-1.5 hover:bg-emerald-500/25 transition"
                @click="triggerOauthFlow(null)"
              >
                <span class="i-lucide-log-in size-3.5" />
                <span>Autenticar Nova Conta via OAuth 2.0</span>
              </button>
              <button
                type="button"
                class="px-3 py-1.5 rounded-xl bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-slate-200 text-xs font-medium flex items-center gap-1.5 transition"
                @click="openNewConnection"
              >
                <span class="i-lucide-plus size-3.5 text-emerald-400" />
                <span>Conexão Rápida / Token</span>
              </button>
            </div>
          </div>

          <div
            v-if="hooks.length === 0"
            class="py-12 text-center flex flex-col items-center gap-3"
          >
            <div
              class="w-12 h-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400"
            >
              <span class="i-lucide-calendar-plus size-6" />
            </div>
            <div class="text-sm font-semibold text-white">
              Nenhuma conta de calendário conectada ainda
            </div>
            <p class="text-xs text-slate-400 max-w-md">
              Conecte contas Google Agenda, Workspace ou CalDAV para liberar
              verificação de conflitos em tempo real e agendamento automático
              pelo Agente IA.
            </p>
            <button
              type="button"
              class="px-4 py-2 rounded-xl bg-[#10B981] text-[#04090D] font-semibold text-xs"
              @click="openNewConnection"
            >
              + Conectar Primeira Conta
            </button>
          </div>

          <div
            v-else
            class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4"
          >
            <div
              v-for="hook in hooks"
              :key="hook.id"
              class="rounded-2xl bg-[#04090D] border border-[#162936] hover:border-emerald-500/40 p-4 flex flex-col justify-between gap-4 transition shadow-sm"
            >
              <div class="flex flex-col gap-3">
                <div class="flex items-start justify-between gap-2">
                  <div class="flex items-center gap-2.5 min-w-0">
                    <div
                      class="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shrink-0"
                    >
                      <span class="i-lucide-calendar-check size-5" />
                    </div>
                    <div class="min-w-0">
                      <div
                        class="text-sm font-semibold text-[#F8FAFC] truncate"
                      >
                        {{
                          hook.settings?.connection_name ||
                          hook.reference_id ||
                          'Conexão de Agenda'
                        }}
                      </div>
                      <div class="text-[11px] text-slate-400 truncate">
                        {{ providerLabel(hook.settings?.provider) }}
                      </div>
                    </div>
                  </div>
                  <span
                    class="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 shrink-0 flex items-center gap-1"
                  >
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                    Conectado
                  </span>
                </div>

                <div
                  class="rounded-xl bg-[#081218] border border-[#132631] p-3 flex flex-col gap-1.5 text-xs"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-slate-400">Conta / E-mail:</span>
                    <span class="font-mono text-emerald-400 truncate">
                      {{ hook.settings?.calendar_email || hook.reference_id }}
                    </span>
                  </div>
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-slate-400">Calendar ID:</span>
                    <span class="font-mono text-slate-200">
                      {{ hook.settings?.calendar_id || 'primary' }}
                    </span>
                  </div>
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-slate-400">Agendas vinculadas:</span>
                    <span class="text-slate-200 font-medium truncate">
                      {{
                        (hook.settings?.linked_schedule_names || []).join(
                          ', '
                        ) || 'Todas'
                      }}
                    </span>
                  </div>
                </div>
              </div>

              <div
                class="flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-[#132631]"
              >
                <div class="flex items-center gap-1.5">
                  <button
                    type="button"
                    :disabled="testingHookId === hook.id"
                    class="px-2.5 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-[11px] text-slate-200 flex items-center gap-1 transition"
                    @click="testConnection(hook)"
                  >
                    <span
                      class="i-lucide-check-circle-2 size-3.5 text-emerald-400"
                    />
                    <span>{{
                      testingHookId === hook.id ? 'Testando...' : 'Testar'
                    }}</span>
                  </button>
                  <button
                    type="button"
                    :disabled="syncingHookId === hook.id"
                    class="px-2.5 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] hover:border-emerald-500/40 text-[11px] text-slate-200 flex items-center gap-1 transition"
                    @click="syncConnection(hook)"
                  >
                    <span
                      class="i-lucide-refresh-cw size-3.5 text-emerald-400"
                    />
                    <span>{{
                      syncingHookId === hook.id
                        ? 'Sincronizando...'
                        : 'Sincronizar'
                    }}</span>
                  </button>
                  <button
                    type="button"
                    class="px-2.5 py-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/30 text-[11px] text-emerald-300 hover:bg-emerald-500/20 transition"
                    @click="triggerOauthFlow(hook)"
                  >
                    OAuth
                  </button>
                </div>

                <div class="flex items-center gap-1.5">
                  <button
                    type="button"
                    class="px-2.5 py-1.5 rounded-lg bg-[#0A151D] border border-[#162936] text-[11px] text-slate-300 hover:text-white"
                    @click="openEditConnection(hook)"
                  >
                    Editar
                  </button>
                  <button
                    type="button"
                    class="px-2.5 py-1.5 rounded-lg bg-rose-500/10 border border-rose-500/30 text-[11px] text-rose-300 hover:bg-rose-500/20"
                    @click="removeConnection(hook)"
                  >
                    Remover
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Modal: Adicionar / Editar Conexão de Agenda -->
      <div
        v-if="showConnectModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
        @click.self="showConnectModal = false"
      >
        <div
          class="w-full max-w-xl bg-[#081218] border border-[#162936] rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
        >
          <div
            class="flex items-center justify-between px-5 py-4 border-b border-[#132631] bg-[#04090D]"
          >
            <div>
              <h3 class="text-base font-semibold text-[#F8FAFC]">
                {{
                  editingHookId
                    ? 'Editar Conexão de Calendário'
                    : 'Nova Conexão de Calendário Multi-Conta'
                }}
              </h3>
              <p class="text-xs text-slate-400">
                Vincule uma conta Google Agenda, Workspace ou CalDAV aos
                especialistas da sua operação
              </p>
            </div>
            <button
              type="button"
              class="text-slate-400 hover:text-white text-lg px-2"
              @click="showConnectModal = false"
            >
              ×
            </button>
          </div>

          <div class="p-5 overflow-y-auto flex flex-col gap-4 text-xs">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label class="block text-[11px] text-slate-400 mb-1">
                  Nome da Conexão *
                </label>
                <input
                  v-model="hookForm.connection_name"
                  type="text"
                  placeholder="Ex: Agenda Comercial Diretoria"
                  class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white outline-none focus:border-emerald-500"
                />
              </div>
              <div>
                <label class="block text-[11px] text-slate-400 mb-1">
                  Provedor de Calendário
                </label>
                <select
                  v-model="hookForm.provider"
                  class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white outline-none focus:border-emerald-500"
                >
                  <option v-for="p in providers" :key="p.id" :value="p.id">
                    {{ p.label }}
                  </option>
                </select>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label class="block text-[11px] text-slate-400 mb-1">
                  E-mail da Conta de Calendário *
                </label>
                <input
                  v-model="hookForm.calendar_email"
                  type="email"
                  placeholder="especialista@suaempresa.com.br"
                  class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white outline-none focus:border-emerald-500"
                />
              </div>
              <div>
                <label class="block text-[11px] text-slate-400 mb-1">
                  Calendar ID
                </label>
                <input
                  v-model="hookForm.calendar_id"
                  type="text"
                  placeholder="primary"
                  class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white font-mono outline-none focus:border-emerald-500"
                />
              </div>
            </div>

            <!-- Seleção de Agendas de Especialistas Vinculadas -->
            <div>
              <label class="block text-[11px] text-slate-400 mb-1.5">
                Vincular às Agendas de Especialistas (Sincronização
                Bidirecional)
              </label>
              <div class="flex flex-wrap gap-2">
                <button
                  v-for="sched in schedules"
                  :key="sched.id"
                  type="button"
                  class="px-3 py-1.5 rounded-xl border text-xs flex items-center gap-2 transition"
                  :class="
                    hookForm.schedule_ids.includes(Number(sched.id))
                      ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-300 font-semibold'
                      : 'bg-[#04090D] border-[#162936] text-slate-300'
                  "
                  @click="toggleScheduleId(sched.id)"
                >
                  <span
                    class="w-2 h-2 rounded-full"
                    :style="{ backgroundColor: sched.color || '#10b981' }"
                  />
                  <span>{{ sched.name }}</span>
                </button>
              </div>
            </div>

            <!-- Seleção de Agentes Autorizados -->
            <div v-if="agents && agents.length">
              <label class="block text-[11px] text-slate-400 mb-1.5">
                Agentes Responsáveis (Opcional)
              </label>
              <div class="flex flex-wrap gap-2 max-h-28 overflow-y-auto">
                <button
                  v-for="ag in agents"
                  :key="ag.id"
                  type="button"
                  class="px-2.5 py-1 rounded-lg border text-[11px] transition"
                  :class="
                    hookForm.agent_ids.includes(Number(ag.id))
                      ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-300 font-semibold'
                      : 'bg-[#04090D] border-[#162936] text-slate-400'
                  "
                  @click="toggleAgentId(ag.id)"
                >
                  {{ ag.name }}
                </button>
              </div>
            </div>

            <div
              class="p-3.5 rounded-xl bg-[#04090D] border border-[#132631] flex flex-col gap-3"
            >
              <div class="text-[11px] font-semibold text-emerald-400">
                Tokens OAuth / Credenciais Específicas desta Conta (Opcional)
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-[10px] text-slate-400 mb-1">
                    OAuth Access Token (Opcional)
                  </label>
                  <input
                    v-model="hookForm.access_token"
                    type="password"
                    placeholder="ya29.a0AfH6SM..."
                    class="w-full px-3 py-1.5 rounded-lg bg-[#081218] border border-[#162936] text-white font-mono outline-none"
                  />
                </div>
                <div>
                  <label class="block text-[10px] text-slate-400 mb-1">
                    OAuth Refresh Token (Opcional)
                  </label>
                  <input
                    v-model="hookForm.refresh_token"
                    type="password"
                    placeholder="1//0g..."
                    class="w-full px-3 py-1.5 rounded-lg bg-[#081218] border border-[#162936] text-white font-mono outline-none"
                  />
                </div>
              </div>
            </div>
          </div>

          <div
            class="flex items-center justify-end gap-2 px-5 py-3.5 border-t border-[#132631] bg-[#04090D]"
          >
            <button
              type="button"
              class="px-4 py-2 rounded-xl bg-[#0A151D] border border-[#162936] text-xs text-slate-300"
              @click="showConnectModal = false"
            >
              Cancelar
            </button>
            <button
              type="button"
              :disabled="savingHook"
              class="px-4 py-2 rounded-xl bg-[#10B981] text-[#04090D] font-semibold text-xs"
              @click="submitHookForm"
            >
              {{
                savingHook
                  ? 'Salvando...'
                  : editingHookId
                    ? 'Salvar Alterações'
                    : 'Conectar & Sincronizar'
              }}
            </button>
          </div>
        </div>
      </div>

      <!-- Modal: Configurar Credenciais OAuth 2.0 Globais da Conta -->
      <div
        v-if="showOauthConfigModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
        @click.self="showOauthConfigModal = false"
      >
        <div
          class="w-full max-w-lg bg-[#081218] border border-[#162936] rounded-2xl shadow-2xl overflow-hidden flex flex-col"
        >
          <div
            class="flex items-center justify-between px-5 py-4 border-b border-[#132631] bg-[#04090D]"
          >
            <div>
              <h3 class="text-base font-semibold text-[#F8FAFC]">
                Configuração OAuth 2.0 (Google Cloud / Workspace)
              </h3>
              <p class="text-xs text-slate-400">
                Permite autenticar múltiplas contas com 1 clique pelo fluxo
                oficial OAuth 2.0
              </p>
            </div>
            <button
              type="button"
              class="text-slate-400 hover:text-white text-lg px-2"
              @click="showOauthConfigModal = false"
            >
              ×
            </button>
          </div>

          <div class="p-5 flex flex-col gap-3.5 text-xs">
            <div
              class="p-3 rounded-xl bg-[#04090D] border border-[#132631] flex flex-col gap-1"
            >
              <span class="text-[11px] text-slate-400">
                URI de Redirecionamento Autorizado (adicione no console OAuth):
              </span>
              <div class="flex items-center justify-between gap-2 mt-1">
                <code class="text-emerald-400 font-mono text-[11px] truncate">
                  {{ redirectUri }}
                </code>
                <button
                  type="button"
                  class="px-2 py-1 rounded bg-emerald-500/20 text-emerald-300 text-[10px] font-semibold shrink-0"
                  @click="copyText(redirectUri)"
                >
                  Copiar
                </button>
              </div>
            </div>

            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Google OAuth Client ID
              </label>
              <input
                v-model="oauthClientId"
                type="text"
                placeholder="1234567890-abcdef.apps.googleusercontent.com"
                class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white font-mono outline-none focus:border-emerald-500"
              />
            </div>

            <div>
              <label class="block text-[11px] text-slate-400 mb-1">
                Google OAuth Client Secret
              </label>
              <input
                v-model="oauthClientSecret"
                type="password"
                placeholder="GOCSPX-..."
                class="w-full px-3 py-2 rounded-xl bg-[#04090D] border border-[#162936] text-white font-mono outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          <div
            class="flex items-center justify-end gap-2 px-5 py-3.5 border-t border-[#132631] bg-[#04090D]"
          >
            <button
              type="button"
              class="px-4 py-2 rounded-xl bg-[#0A151D] border border-[#162936] text-xs text-slate-300"
              @click="showOauthConfigModal = false"
            >
              Fechar
            </button>
            <button
              type="button"
              :disabled="savingOauth"
              class="px-4 py-2 rounded-xl bg-[#10B981] text-[#04090D] font-semibold text-xs"
              @click="saveOauthCredentials"
            >
              {{ savingOauth ? 'Salvando...' : 'Salvar Credenciais OAuth 2.0' }}
            </button>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
