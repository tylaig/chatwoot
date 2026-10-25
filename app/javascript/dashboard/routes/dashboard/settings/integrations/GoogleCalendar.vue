<script setup>
/* eslint-disable @intlify/vue-i18n/no-raw-text, vue/no-bare-strings-in-template */
import { ref, computed, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRoute, useRouter } from 'vue-router';
import integrationAPI from 'dashboard/api/integrations';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import CalendarSetupVideo from './CalendarSetupVideo.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();

const VIDEO_BASE_URL = '/brand-assets/videos/google-calendar';

const loading = ref(true);
const hooks = ref([]);
const schedules = ref([]);
const oauthConfigured = ref(false);
const hasCustomOauthCredentials = ref(false);
const redirectUri = ref('https://chat.meusuper.app/callbacks/google_calendar');

// Guided Video Onboarding state (WhatsApp Manual Setup style)
const currentStep = ref(1);
const showWizard = ref(true);

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

const wizardSteps = [
  {
    id: 1,
    badge: 'Etapa 1 de 4',
    title: 'Credenciais OAuth 2.0 & Redirect URI',
    subtitle:
      'Ative a Google Calendar API no Google Cloud Console, configure a tela OAuth e informe seu Client ID e Client Secret.',
    videoSlug: 'step-1-oauth-credentials',
    videoTitle: 'Passo 1 — Como gerar o Client ID e Client Secret OAuth 2.0',
    videoDescription:
      'Copie a URI de redirecionamento oficial do Meu Super Chat e adicione nas credenciais OAuth 2.0 do seu painel Google Cloud.',
  },
  {
    id: 2,
    badge: 'Etapa 2 de 4',
    title: 'Autenticar Conta Google Agenda ou Token',
    subtitle:
      'Conecte sua conta com 1 clique pelo fluxo oficial OAuth 2.0 ou cadastre uma conexão rápida para sua agenda.',
    videoSlug: 'step-2-connect-account',
    videoTitle: 'Passo 2 — Autenticação OAuth 2.0 em 1 Clique ou Token Direto',
    videoDescription:
      'Inicie a autorização segura ou vincule sua conta de calendário corporativa diretamente ao Meu Super Chat.',
  },
  {
    id: 3,
    badge: 'Etapa 3 de 4',
    title: 'Vincular Especialistas & Agente IA',
    subtitle:
      'Associe as contas conectadas aos especialistas da equipe para leitura automática de conflitos (freeBusy) e reservas pela IA.',
    videoSlug: 'step-3-link-schedules',
    videoTitle: 'Passo 3 — Sincronizando Especialistas e Agente IA 24/7',
    videoDescription:
      'Cada especialista pode ter sua própria agenda conectada e página exclusiva /agendar/slug.',
  },
  {
    id: 4,
    badge: 'Etapa 4 de 4',
    title: 'Verificação em Tempo Real & Página Pública',
    subtitle:
      'Teste a disponibilidade em tempo real, valide a criação de salas de vídeo e compartilhe o link público do Meu Super Chat.',
    videoSlug: 'step-4-verify-and-test',
    videoTitle: 'Passo 4 — Homologação e Link Público Ao Vivo',
    videoDescription:
      'Confirme o status dos serviços e teste o agendamento público sincronizado com sua agenda.',
  },
];

const activeStepConfig = computed(
  () => wizardSteps.find(s => s.id === currentStep.value) || wizardSteps[0]
);

const stepVideoSrc = slug => `${VIDEO_BASE_URL}/${slug}.mp4`;
const stepVideoPoster = slug => `${VIDEO_BASE_URL}/${slug}-poster.jpg`;

const setStep = step => {
  currentStep.value = Math.min(4, Math.max(1, step));
};

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
    if (!hookForm.value.schedule_ids.length && schedules.value[0]) {
      hookForm.value.schedule_ids = [schedules.value[0].id];
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

const saveOauthCredentials = async advanceAfter => {
  try {
    savingOauth.value = true;
    const { data } = await integrationAPI.saveGoogleCalendarOauthCredentials({
      clientId: oauthClientId.value,
      clientSecret: oauthClientSecret.value,
    });
    oauthConfigured.value = !!data.oauth_configured;
    hasCustomOauthCredentials.value = !!data.has_custom_oauth_credentials;
    useAlert(data.message || 'Credenciais OAuth 2.0 salvas com sucesso!');
    await loadData();
    if (advanceAfter) {
      setStep(2);
    }
  } catch (err) {
    useAlert(
      err?.response?.data?.error || 'Erro ao salvar credenciais OAuth 2.0.'
    );
  } finally {
    savingOauth.value = false;
  }
};

const submitHookForm = async advanceAfter => {
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
    if (advanceAfter) {
      setStep(3);
    }
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
    showWizard.value = true;
    setStep(1);
    useAlert(
      data.error ||
        'Siga a Etapa 1 do Onboarding abaixo para informar seu Client ID e Client Secret OAuth 2.0 ou use a Conexão Rápida na Etapa 2.'
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
  if (route.query.step) {
    setStep(Number(route.query.step) || 1);
  }
  if (route.query.google_connected) {
    setStep(4);
    useAlert('Conta autenticada via OAuth 2.0 e sincronizada com sucesso!');
  }
});
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    loading-message="Carregando conexões de agenda e onboarding OAuth 2.0..."
  >
    <template #header>
      <BaseSettingsHeader
        title="Onboarding & Autenticação de Agendas (OAuth 2.0)"
        description="Siga o passo a passo em vídeo para configurar suas credenciais OAuth 2.0, conectar contas Google Agenda e vincular os especialistas ao Agente IA."
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
              <span>Voltar ao Painel de Agendamentos</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs flex items-center gap-1.5 shadow-lg transition"
              @click="openNewConnection"
            >
              <span class="i-lucide-plus size-4" />
              <span>Nova Conta de Agenda</span>
            </button>
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-6 pb-12">
        <!-- ASSISTENTE GUIADO EM VÍDEO (4 ETAPAS — PADRÃO WHATSAPP MANUAL SETUP) -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 sm:p-6 flex flex-col gap-5 shadow-lg"
        >
          <!-- Topo do Wizard: Indicadores de Etapa -->
          <div
            class="flex flex-col lg:flex-row lg:items-center justify-between gap-4 pb-4 border-b border-[#132631]"
          >
            <div>
              <div class="flex items-center gap-2">
                <span
                  class="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                >
                  {{ activeStepConfig.badge }}
                </span>
                <span class="text-xs text-slate-400">
                  Configuração guiada em vídeo • Meu Super Chat
                </span>
              </div>
              <h2 class="text-base sm:text-lg font-bold text-[#F8FAFC] mt-1.5">
                {{ activeStepConfig.title }}
              </h2>
              <p class="text-xs text-slate-400 mt-0.5">
                {{ activeStepConfig.subtitle }}
              </p>
            </div>

            <!-- Pílulas das 4 Etapas -->
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 shrink-0">
              <button
                v-for="st in wizardSteps"
                :key="st.id"
                type="button"
                class="px-3 py-2 rounded-xl border text-left transition flex items-center gap-2"
                :class="
                  currentStep === st.id
                    ? 'bg-emerald-500/15 border-emerald-500 text-emerald-300 shadow-sm'
                    : currentStep > st.id
                      ? 'bg-[#04090D] border-emerald-500/40 text-slate-200'
                      : 'bg-[#04090D] border-[#162936] text-slate-400 hover:border-slate-700'
                "
                @click="setStep(st.id)"
              >
                <span
                  class="w-6 h-6 rounded-full text-[11px] font-bold flex items-center justify-center shrink-0"
                  :class="
                    currentStep === st.id
                      ? 'bg-[#10B981] text-[#04090D]'
                      : currentStep > st.id
                        ? 'bg-emerald-500/20 text-emerald-400'
                        : 'bg-[#0A151D] text-slate-400'
                  "
                >
                  {{ currentStep > st.id ? '✓' : st.id }}
                </span>
                <div class="min-w-0">
                  <div class="text-[10px] uppercase tracking-wider opacity-75">
                    Passo {{ st.id }}
                  </div>
                  <div class="text-xs font-semibold truncate">
                    {{
                      st.id === 1
                        ? 'Credenciais'
                        : st.id === 2
                          ? 'Conectar'
                          : st.id === 3
                            ? 'Especialistas'
                            : 'Verificar'
                    }}
                  </div>
                </div>
              </button>
            </div>
          </div>

          <!-- Corpo do Wizard: Esquerda Ação Interativa | Direita Vídeo Demonstrativo -->
          <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            <!-- Coluna Esquerda (7 cols): Conteúdo da Etapa Atual -->
            <div class="lg:col-span-7 flex flex-col gap-4">
              <!-- ETAPA 1: CREDENCIAIS OAUTH 2.0 -->
              <div v-if="currentStep === 1" class="flex flex-col gap-4">
                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-2"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-xs font-semibold text-emerald-400">
                      1. URI de Redirecionamento Autorizado (Callback OAuth)
                    </span>
                    <button
                      type="button"
                      class="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-300 text-[11px] font-semibold hover:bg-emerald-500/30 transition"
                      @click="copyText(redirectUri)"
                    >
                      Copiar URI
                    </button>
                  </div>
                  <p class="text-[11px] text-slate-400">
                    No Google Cloud Console (APIs e Serviços → Credenciais → ID
                    do cliente OAuth 2.0), cole exatamente este endereço:
                  </p>
                  <code
                    class="px-3 py-2 rounded-lg bg-[#081218] border border-[#132631] text-emerald-400 font-mono text-xs select-all break-all"
                  >
                    {{ redirectUri }}
                  </code>
                </div>

                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-3"
                >
                  <div class="text-xs font-semibold text-[#F8FAFC]">
                    2. Informe o Client ID e Client Secret da sua conta
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label class="block text-[11px] text-slate-400 mb-1">
                        Google OAuth Client ID
                      </label>
                      <input
                        v-model="oauthClientId"
                        type="text"
                        placeholder="Ex: 829401-app.apps.googleusercontent.com"
                        class="w-full px-3 py-2 rounded-xl bg-[#081218] border border-[#162936] text-xs text-white font-mono outline-none focus:border-emerald-500"
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
                        class="w-full px-3 py-2 rounded-xl bg-[#081218] border border-[#162936] text-xs text-white font-mono outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>
                  <div
                    class="flex flex-wrap items-center justify-between gap-2 pt-1"
                  >
                    <span class="text-[11px] text-slate-400">
                      Status atual:
                      <strong
                        :class="
                          oauthConfigured
                            ? 'text-emerald-400'
                            : 'text-amber-400'
                        "
                      >
                        {{
                          oauthConfigured
                            ? 'OAuth 2.0 Configurado'
                            : 'Usando Conexão Direta / Aguardando Client ID'
                        }}
                      </strong>
                    </span>
                    <button
                      type="button"
                      :disabled="savingOauth"
                      class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs transition"
                      @click="saveOauthCredentials(true)"
                    >
                      {{
                        savingOauth
                          ? 'Salvando...'
                          : 'Salvar Credenciais & Avançar →'
                      }}
                    </button>
                  </div>
                </div>
              </div>

              <!-- ETAPA 2: CONECTAR CONTA -->
              <div v-else-if="currentStep === 2" class="flex flex-col gap-4">
                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                >
                  <div>
                    <div class="text-xs font-semibold text-[#F8FAFC]">
                      Opção A — Autenticação Oficial Google OAuth 2.0 (1 Clique)
                    </div>
                    <p class="text-[11px] text-slate-400 mt-0.5">
                      Redireciona para a tela oficial do Google para autorizar a
                      leitura e criação de eventos na agenda.
                    </p>
                  </div>
                  <button
                    type="button"
                    class="px-4 py-2.5 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-bold text-xs shrink-0 flex items-center gap-1.5"
                    @click="triggerOauthFlow(null)"
                  >
                    <span class="i-lucide-log-in size-4" />
                    <span>Autorizar com Google OAuth</span>
                  </button>
                </div>

                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-3"
                >
                  <div class="text-xs font-semibold text-emerald-400">
                    Opção B — Conexão Direta / Conta de Calendário Corporativa
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label class="block text-[11px] text-slate-400 mb-1">
                        Nome de Identificação *
                      </label>
                      <input
                        v-model="hookForm.connection_name"
                        type="text"
                        placeholder="Ex: Agenda Principal Samuel"
                        class="w-full px-3 py-2 rounded-xl bg-[#081218] border border-[#162936] text-xs text-white outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label class="block text-[11px] text-slate-400 mb-1">
                        E-mail da Agenda *
                      </label>
                      <input
                        v-model="hookForm.calendar_email"
                        type="email"
                        placeholder="samuel@meusuper.app"
                        class="w-full px-3 py-2 rounded-xl bg-[#081218] border border-[#162936] text-xs text-white outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>
                  <div class="flex justify-end">
                    <button
                      type="button"
                      :disabled="savingHook"
                      class="px-4 py-2 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-500/30 font-semibold text-xs transition"
                      @click="submitHookForm(true)"
                    >
                      {{
                        savingHook
                          ? 'Conectando...'
                          : 'Conectar Agenda & Avançar →'
                      }}
                    </button>
                  </div>
                </div>
              </div>

              <!-- ETAPA 3: VINCULAR ESPECIALISTAS -->
              <div v-else-if="currentStep === 3" class="flex flex-col gap-3">
                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-3"
                >
                  <div class="text-xs font-semibold text-[#F8FAFC]">
                    Especialistas Sincronizados no Meu Super Chat ({{
                      schedules.length
                    }})
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                    <div
                      v-for="sched in schedules"
                      :key="sched.id"
                      class="p-3 rounded-xl bg-[#081218] border border-[#132631] flex items-center justify-between gap-2"
                    >
                      <div class="min-w-0">
                        <div class="text-xs font-semibold text-white truncate">
                          {{ sched.name }}
                        </div>
                        <div
                          class="text-[11px] font-mono text-emerald-400 truncate"
                        >
                          /agendar/{{ sched.slug }}
                        </div>
                      </div>
                      <span
                        class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 shrink-0"
                      >
                        Sincronizado
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- ETAPA 4: VERIFICAÇÃO E TESTE -->
              <div v-else class="flex flex-col gap-3">
                <div
                  class="p-4 rounded-xl bg-[#04090D] border border-[#162936] flex flex-col gap-2.5"
                >
                  <div class="text-xs font-semibold text-emerald-400">
                    Checklist de Homologação da Integração
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-xs">
                    <div
                      class="p-3 rounded-xl bg-[#081218] border border-[#132631] flex items-center justify-between"
                    >
                      <span class="text-slate-300">
                        Contas de Agenda Ativas
                      </span>
                      <strong class="text-emerald-400">
                        {{ hooks.length }} conectada(s)
                      </strong>
                    </div>
                    <div
                      class="p-3 rounded-xl bg-[#081218] border border-[#132631] flex items-center justify-between"
                    >
                      <span class="text-slate-300">
                        Leitura de Conflitos IA
                      </span>
                      <strong class="text-emerald-400">
                        Tempo Real (Ativo)
                      </strong>
                    </div>
                    <div
                      class="p-3 rounded-xl bg-[#081218] border border-[#132631] flex items-center justify-between"
                    >
                      <span class="text-slate-300">
                        Salas de Vídeo Automáticas
                      </span>
                      <strong class="text-emerald-400">Habilitado</strong>
                    </div>
                    <div
                      class="p-3 rounded-xl bg-[#081218] border border-[#132631] flex items-center justify-between"
                    >
                      <span class="text-slate-300">Página Pública Online</span>
                      <a
                        href="/agendar/samuel-vicente"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-emerald-400 font-semibold hover:underline"
                      >
                        Testar Página →
                      </a>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Barra Inferior de Navegação entre Etapas -->
              <div
                class="flex items-center justify-between pt-3 border-t border-[#132631]"
              >
                <button
                  type="button"
                  :disabled="currentStep === 1"
                  class="px-3.5 py-2 rounded-xl bg-[#0A151D] border border-[#162936] text-xs text-slate-300 disabled:opacity-40"
                  @click="setStep(currentStep - 1)"
                >
                  ← Etapa Anterior
                </button>
                <button
                  v-if="currentStep < 4"
                  type="button"
                  class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs"
                  @click="setStep(currentStep + 1)"
                >
                  Próxima Etapa →
                </button>
                <button
                  v-else
                  type="button"
                  class="px-4 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] font-semibold text-xs"
                  @click="goToCalendarModule"
                >
                  Concluir & Ir para Agendamentos →
                </button>
              </div>
            </div>

            <!-- Coluna Direita (5 cols): Player de Vídeo da Etapa -->
            <div class="lg:col-span-5">
              <CalendarSetupVideo
                :src="stepVideoSrc(activeStepConfig.videoSlug)"
                :poster="stepVideoPoster(activeStepConfig.videoSlug)"
                :title="activeStepConfig.videoTitle"
                :description="activeStepConfig.videoDescription"
              />
            </div>
          </div>
        </div>

        <!-- Lista de Conexões Múltiplas Ativas -->
        <div
          class="bg-[#081218] border border-[#142633] rounded-2xl p-5 flex flex-col gap-4"
        >
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[#132631]"
          >
            <div>
              <h3 class="text-sm font-semibold text-[#F8FAFC]">
                Contas de Calendário Conectadas ({{ hooks.length }})
              </h3>
              <p class="text-xs text-slate-400">
                Gerencie todas as agendas sincronizadas com sua equipe e Agente
                IA.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                class="px-3.5 py-2 rounded-xl bg-[#10B981] hover:bg-emerald-400 text-[#04090D] text-xs font-semibold flex items-center gap-1.5 transition"
                @click="openNewConnection"
              >
                <span class="i-lucide-plus size-3.5" />
                <span>Conectar Nova Agenda</span>
              </button>
            </div>
          </div>

          <div
            v-if="hooks.length === 0"
            class="py-10 text-center flex flex-col items-center gap-3"
          >
            <div class="text-sm font-semibold text-white">
              Nenhuma conta conectada ainda
            </div>
            <p class="text-xs text-slate-400 max-w-md">
              Use a Etapa 2 acima ou clique no botão abaixo para vincular sua
              primeira agenda.
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

            <div>
              <label class="block text-[11px] text-slate-400 mb-1.5">
                Vincular às Agendas de Especialistas
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
              @click="submitHookForm(false)"
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
    </template>
  </SettingsLayout>
</template>
