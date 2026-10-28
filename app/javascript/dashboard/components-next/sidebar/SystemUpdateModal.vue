<script setup>
import { ref, computed, onUnmounted } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SystemUpdatesAPI from 'dashboard/api/systemUpdates';
import { useAlert } from 'dashboard/composables';

const dialogRef = ref(null);
const isLoading = ref(false);
const isApplying = ref(false);
const activeTab = ref('commits');
const expandedFile = ref(null);
const forceWindowConfirm = ref(false);
const updateData = ref(null);
let pollTimer = null;

const UI_TEXT = {
  modalTitle: 'Central de Atualizações do Sistema (Games Safari)',
  modalDescription:
    'Confira as novidades, commits e diferenças de código na branch prod/gamessafari antes de aplicar.',
  installedLabel: 'Instalado na VPS:',
  arrow: '→',
  availableLabel: 'Disponível:',
  branchPrefix: 'Branch:',
  brtPrefix: '• Horário BRT:',
  checkNow: 'Verificar agora',
  deployNote:
    'O banco passa por backup preventivo automático antes de virar a chave dos contêineres. Esta janela recarregará automaticamente assim que o novo contêiner responder.',
  loadingRepo: 'Consultando repositório e comparando diferenças...',
  versionStatus: 'Status da Versão',
  upToDate: '100% Atualizado',
  changedFiles: 'Arquivos Alterados',
  diffLines: 'Linhas (Diff)',
  noFilesChanged: 'Nenhum arquivo modificado pendente.',
  supportHoursTitle: 'Horário de Atendimento Ativo (11:00 às 22:00 BRT)',
  supportHoursBody:
    'Por padrão, atualizações feitas durante o dia são aplicadas automaticamente às 22:05 BRT para não reiniciar os contêineres durante o expediente.',
  emergencyOverride:
    'Modo de Emergência: Autorizo forçar a atualização agora mesmo dentro do horário comercial',
  offHoursReady:
    'Fora do horário de atendimento (22h–11h BRT): Atualização liberada sem impacto no expediente.',
  close: 'Fechar',
};

const hasUpdates = computed(() => Boolean(updateData.value?.has_updates));
const withinSupportHours = computed(() =>
  Boolean(updateData.value?.within_support_hours)
);
const deployStatus = computed(
  () => updateData.value?.deploy_status || { state: 'idle' }
);
const isDeployRunning = computed(
  () => deployStatus.value?.state === 'running' || isApplying.value
);

const canConfirmUpdate = computed(() => {
  if (isLoading.value || isDeployRunning.value) return false;
  if (withinSupportHours.value && !forceWindowConfirm.value) return false;
  return true;
});

const versionStatusText = computed(() =>
  hasUpdates.value
    ? `${updateData.value?.ahead_by || 0} commit(s) novo(s)`
    : UI_TEXT.upToDate
);

const filesCountText = computed(
  () => `${updateData.value?.files_count || 0} arquivo(s)`
);

const additionsText = computed(
  () => `+${updateData.value?.total_additions || 0}`
);

const deletionsText = computed(
  () => `-${updateData.value?.total_deletions || 0}`
);

const commitsTabLabel = computed(
  () => `Novidades & Commits (${updateData.value?.commits?.length || 0})`
);

const filesTabLabel = computed(
  () => `Diferenças de Arquivos (${updateData.value?.files?.length || 0})`
);

const noCommitsText = computed(
  () =>
    `Nenhuma diferença pendente entre o servidor e a branch ${updateData.value?.target_branch || 'prod/gamessafari'}.`
);

const confirmButtonLabel = computed(() => {
  if (isDeployRunning.value) return 'Atualizando servidor...';
  if (hasUpdates.value) {
    return `Aceitar e Atualizar (${updateData.value?.latest_short_sha})`;
  }
  return 'Reaplicar / Forçar Sincronização';
});

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(async () => {
    try {
      const { data } = await SystemUpdatesAPI.check(true);
      updateData.value = data;
      if (data?.deploy_status?.state === 'completed') {
        stopPolling();
        isApplying.value = false;
        useAlert('Atualização concluída com sucesso! Recarregando o painel...');
        setTimeout(() => window.location.reload(), 1800);
      } else if (data?.deploy_status?.state === 'failed') {
        stopPolling();
        isApplying.value = false;
        useAlert(
          data?.deploy_status?.message ||
            'Falha ao aplicar atualização. Verifique o diagnóstico.'
        );
      }
    } catch (e) {
      // durante o restart do container, aguarda reconectar
    }
  }, 4000);
};

const fetchUpdateInfo = async (refresh = false) => {
  isLoading.value = true;
  try {
    const { data } = await SystemUpdatesAPI.check(refresh);
    updateData.value = data;
    if (data?.deploy_status?.state === 'running') {
      startPolling();
    }
  } catch (error) {
    useAlert(
      'Não foi possível consultar as atualizações no momento. Tente novamente.'
    );
  } finally {
    isLoading.value = false;
  }
};

const open = async () => {
  forceWindowConfirm.value = false;
  activeTab.value = 'commits';
  expandedFile.value = null;
  dialogRef.value?.open();
  await fetchUpdateInfo(true);
};

const close = () => {
  stopPolling();
  dialogRef.value?.close();
};

const toggleFilePatch = filename => {
  expandedFile.value = expandedFile.value === filename ? null : filename;
};

const formatAuthor = author => `Por ${author || 'Sistema'}`;
const formatAdd = count => `+${count || 0}`;
const formatDel = count => `-${count || 0}`;

const formatDate = iso => {
  if (!iso) return '';
  try {
    return new Date(iso).toLocaleString('pt-BR', {
      timeZone: 'America/Sao_Paulo',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch (e) {
    return iso;
  }
};

const triggerSystemUpdate = async () => {
  if (!canConfirmUpdate.value) return;
  isApplying.value = true;
  try {
    const { data } = await SystemUpdatesAPI.apply({
      targetSha: updateData.value?.latest_sha,
      forceWindow: forceWindowConfirm.value,
    });
    if (updateData.value) {
      updateData.value.deploy_status = data.deploy_status;
    }
    useAlert(
      'Atualização disparada! O servidor está aplicando a nova versão...'
    );
    startPolling();
  } catch (error) {
    isApplying.value = false;
    const msg =
      error?.response?.data?.error ||
      'Erro ao iniciar atualização. Verifique suas permissões.';
    useAlert(msg);
  }
};

onUnmounted(() => {
  stopPolling();
});

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    :title="UI_TEXT.modalTitle"
    :description="UI_TEXT.modalDescription"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="stopPolling"
  >
    <div class="flex flex-col gap-4 text-sm">
      <div
        class="flex flex-wrap items-center justify-between gap-3 p-3.5 rounded-xl bg-n-solid-2 border border-n-weak"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex items-center justify-center size-10 rounded-xl bg-n-teal-9/15 text-n-teal-11 shrink-0"
          >
            <span class="i-lucide-git-compare size-5" />
          </div>
          <div class="flex flex-col">
            <div class="flex items-center gap-2">
              <span class="text-xs text-n-slate-11">
                {{ UI_TEXT.installedLabel }}
              </span>
              <code
                class="px-1.5 py-0.5 text-xs font-mono font-semibold rounded bg-n-alpha-2 text-n-slate-12"
              >
                {{ updateData?.current_short_sha || '...' }}
              </code>
              <span class="text-n-slate-10">{{ UI_TEXT.arrow }}</span>
              <span class="text-xs text-n-slate-11">
                {{ UI_TEXT.availableLabel }}
              </span>
              <code
                class="px-1.5 py-0.5 text-xs font-mono font-semibold rounded bg-n-teal-9/20 text-n-teal-11"
              >
                {{ updateData?.latest_short_sha || '...' }}
              </code>
            </div>
            <span class="text-xs text-n-slate-11 mt-0.5">
              {{ UI_TEXT.branchPrefix }}
              <strong class="text-n-slate-12">
                {{ updateData?.target_branch || 'prod/gamessafari' }}
              </strong>
              {{ UI_TEXT.brtPrefix }} {{ updateData?.brasilia_time || '...' }}
            </span>
          </div>
        </div>

        <Button
          size="xs"
          color="slate"
          variant="faded"
          icon="i-lucide-refresh-cw"
          :label="UI_TEXT.checkNow"
          :is-loading="isLoading"
          @click="fetchUpdateInfo(true)"
        />
      </div>

      <div
        v-if="isDeployRunning || deployStatus.state === 'completed'"
        class="p-4 rounded-xl border border-n-teal-9/40 bg-n-teal-9/10 flex flex-col gap-2"
      >
        <div class="flex items-center gap-2.5">
          <span
            v-if="isDeployRunning"
            class="i-lucide-loader-circle size-5 text-n-teal-11 animate-spin shrink-0"
          />
          <span
            v-else
            class="i-lucide-circle-check size-5 text-n-teal-11 shrink-0"
          />
          <span class="font-semibold text-n-slate-12">
            {{
              deployStatus.message ||
              'Aplicando atualização nos contêineres da VPS...'
            }}
          </span>
        </div>
        <p class="text-xs text-n-slate-11 m-0 pl-7">
          {{ UI_TEXT.deployNote }}
        </p>
      </div>

      <div
        v-if="isLoading && !updateData"
        class="py-10 flex flex-col items-center justify-center gap-2 text-n-slate-11"
      >
        <span class="i-lucide-loader-circle size-6 animate-spin" />
        <span>{{ UI_TEXT.loadingRepo }}</span>
      </div>

      <template v-else-if="updateData">
        <div class="grid grid-cols-3 gap-2.5">
          <div
            class="p-3 rounded-xl bg-n-solid-2 border border-n-weak flex flex-col"
          >
            <span class="text-xs text-n-slate-11">
              {{ UI_TEXT.versionStatus }}
            </span>
            <span
              class="text-sm font-bold mt-0.5"
              :class="hasUpdates ? 'text-n-amber-11' : 'text-n-teal-11'"
            >
              {{ versionStatusText }}
            </span>
          </div>
          <div
            class="p-3 rounded-xl bg-n-solid-2 border border-n-weak flex flex-col"
          >
            <span class="text-xs text-n-slate-11">
              {{ UI_TEXT.changedFiles }}
            </span>
            <span class="text-sm font-bold text-n-slate-12 mt-0.5">
              {{ filesCountText }}
            </span>
          </div>
          <div
            class="p-3 rounded-xl bg-n-solid-2 border border-n-weak flex flex-col"
          >
            <span class="text-xs text-n-slate-11">{{ UI_TEXT.diffLines }}</span>
            <div class="flex items-center gap-2 mt-0.5 text-sm font-bold">
              <span class="text-n-teal-11">{{ additionsText }}</span>
              <span class="text-n-ruby-11">{{ deletionsText }}</span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2 border-b border-n-weak pb-2">
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-colors"
            :class="
              activeTab === 'commits'
                ? 'bg-n-teal-9/20 text-n-teal-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="activeTab = 'commits'"
          >
            {{ commitsTabLabel }}
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition-colors"
            :class="
              activeTab === 'files'
                ? 'bg-n-teal-9/20 text-n-teal-11'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="activeTab = 'files'"
          >
            {{ filesTabLabel }}
          </button>
        </div>

        <div
          v-if="activeTab === 'commits'"
          class="max-h-64 overflow-y-auto flex flex-col gap-2 pr-1"
        >
          <div
            v-if="!updateData.commits?.length"
            class="py-8 text-center text-xs text-n-slate-11"
          >
            {{ noCommitsText }}
          </div>
          <div
            v-for="commit in updateData.commits"
            :key="commit.sha"
            class="p-3 rounded-xl bg-n-solid-2 border border-n-weak flex flex-col gap-1"
          >
            <div class="flex items-start justify-between gap-2">
              <span class="font-semibold text-n-slate-12 leading-snug">
                {{ commit.title }}
              </span>
              <code
                class="px-1.5 py-0.5 text-[11px] font-mono rounded bg-n-alpha-2 text-n-teal-11 shrink-0"
              >
                {{ commit.sha }}
              </code>
            </div>
            <p
              v-if="commit.description"
              class="text-xs text-n-slate-11 whitespace-pre-line m-0 mt-0.5"
            >
              {{ commit.description }}
            </p>
            <div
              class="flex items-center justify-between text-[11px] text-n-slate-10 mt-1"
            >
              <span>{{ formatAuthor(commit.author) }}</span>
              <span>{{ formatDate(commit.date) }}</span>
            </div>
          </div>
        </div>

        <div v-else class="max-h-64 overflow-y-auto flex flex-col gap-2 pr-1">
          <div
            v-if="!updateData.files?.length"
            class="py-8 text-center text-xs text-n-slate-11"
          >
            {{ UI_TEXT.noFilesChanged }}
          </div>
          <div
            v-for="file in updateData.files"
            :key="file.filename"
            class="rounded-xl bg-n-solid-2 border border-n-weak overflow-hidden"
          >
            <button
              type="button"
              class="w-full px-3 py-2 flex items-center justify-between gap-2 text-left cursor-pointer hover:bg-n-alpha-1"
              @click="toggleFilePatch(file.filename)"
            >
              <span class="font-mono text-xs text-n-slate-12 truncate">
                {{ file.filename }}
              </span>
              <div class="flex items-center gap-2 shrink-0 text-xs font-mono">
                <span class="text-n-teal-11">
                  {{ formatAdd(file.additions) }}
                </span>
                <span class="text-n-ruby-11">
                  {{ formatDel(file.deletions) }}
                </span>
                <span
                  class="i-lucide-chevron-down size-3.5 text-n-slate-10 transition-transform"
                  :class="{ 'rotate-180': expandedFile === file.filename }"
                />
              </div>
            </button>
            <pre
              v-if="expandedFile === file.filename && file.patch"
              class="m-0 p-3 text-[11px] font-mono leading-relaxed bg-n-solid-1 text-n-slate-11 overflow-x-auto border-t border-n-weak"
            ><code>{{ file.patch }}</code></pre>
          </div>
        </div>

        <div
          v-if="withinSupportHours"
          class="p-3.5 rounded-xl border border-n-amber-9/40 bg-n-amber-9/15 flex flex-col gap-2"
        >
          <div class="flex items-center gap-2 text-n-amber-11 font-semibold">
            <span class="i-lucide-shield-alert size-4 shrink-0" />
            <span>{{ UI_TEXT.supportHoursTitle }}</span>
          </div>
          <p class="text-xs text-n-slate-11 m-0">
            {{ UI_TEXT.supportHoursBody }}
          </p>
          <label
            class="flex items-center gap-2 text-xs font-semibold text-n-slate-12 cursor-pointer mt-1 select-none"
          >
            <input
              v-model="forceWindowConfirm"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ UI_TEXT.emergencyOverride }}</span>
          </label>
        </div>
        <div
          v-else
          class="px-3.5 py-2.5 rounded-xl bg-n-teal-9/10 border border-n-teal-9/30 flex items-center gap-2 text-xs text-n-teal-11"
        >
          <span class="i-lucide-clock-check size-4 shrink-0" />
          <span>{{ UI_TEXT.offHoursReady }}</span>
        </div>
      </template>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3 pt-2">
        <Button
          variant="faded"
          color="slate"
          :label="UI_TEXT.close"
          class="w-full"
          type="button"
          @click="close"
        />
        <Button
          color="teal"
          icon="i-lucide-rocket"
          :label="confirmButtonLabel"
          class="w-full"
          :is-loading="isDeployRunning"
          :disabled="!canConfirmUpdate"
          type="button"
          @click="triggerSystemUpdate"
        />
      </div>
    </template>
  </Dialog>
</template>
