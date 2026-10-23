<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { formatDistanceToNow, fromUnixTime } from 'date-fns';
import { enUS, ptBR } from 'date-fns/locale';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import InboxConversationAPI from 'dashboard/api/inbox/conversation';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { locale } = useI18n();
const router = useRouter();
const store = useStore();
const { accountId } = useAccount();

const allInboxes = useMapGetter('inboxes/getInboxes');
const allAgents = useMapGetter('agents/getAgents');
const allLabels = useMapGetter('labels/getLabels');

const dateFnsLocales = { pt_BR: ptBR, en: enUS };

const COLUMNS = [
  {
    id: 'open',
    title: 'Abertas',
    subtitle: 'Em atendimento ativo',
    icon: 'i-lucide-message-circle',
    accentColor: '#10B981',
    badgeClass: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
  },
  {
    id: 'pending',
    title: 'Pendentes',
    subtitle: 'Aguardando retorno',
    icon: 'i-lucide-clock',
    accentColor: '#F59E0B',
    badgeClass: 'bg-amber-500/15 text-amber-400 border-amber-500/30',
  },
  {
    id: 'snoozed',
    title: 'Adiadas',
    subtitle: 'Programadas para depois',
    icon: 'i-lucide-alarm-clock',
    accentColor: '#38BDF8',
    badgeClass: 'bg-sky-500/15 text-sky-400 border-sky-500/30',
  },
  {
    id: 'resolved',
    title: 'Resolvidas',
    subtitle: 'Atendimentos concluídos',
    icon: 'i-lucide-check-circle-2',
    accentColor: '#D4FF00',
    badgeClass: 'bg-lime-400/15 text-lime-300 border-lime-400/30',
  },
];

const PRIORITY_OPTIONS = [
  { value: null, label: 'Sem prioridade', color: 'text-slate-400' },
  { value: 'urgent', label: 'Urgente', color: 'text-rose-400' },
  { value: 'high', label: 'Alta', color: 'text-amber-400' },
  { value: 'medium', label: 'Média', color: 'text-sky-400' },
  { value: 'low', label: 'Baixa', color: 'text-emerald-400' },
];

const isLoading = ref(false);
const searchQuery = ref('');
const selectedInboxId = ref('');
const selectedAssigneeType = ref('all');
const selectedPriority = ref('');
const activeMobileColumn = ref('open');
const draggedConversation = ref(null);
const dragOverColumnId = ref(null);

const columnItems = ref({
  open: [],
  pending: [],
  snoozed: [],
  resolved: [],
});

const columnCounts = ref({
  open: 0,
  pending: 0,
  snoozed: 0,
  resolved: 0,
});

const fetchBoardData = async () => {
  isLoading.value = true;
  try {
    const baseParams = {
      inboxId: selectedInboxId.value || undefined,
      assigneeType: selectedAssigneeType.value || 'all',
      page: 1,
      sortBy: 'latest',
    };

    const responses = await Promise.all(
      COLUMNS.map(col =>
        InboxConversationAPI.get({
          ...baseParams,
          status: col.id,
        }).catch(() => ({ data: { data: { payload: [], meta: {} } } }))
      )
    );

    COLUMNS.forEach((col, index) => {
      const resData = responses[index]?.data?.data || responses[index]?.data || {};
      const payload = Array.isArray(resData.payload) ? resData.payload : [];
      const meta = resData.meta || {};
      columnItems.value[col.id] = payload;
      columnCounts.value[col.id] =
        typeof meta.all_count === 'number' ? meta.all_count : payload.length;
    });
  } catch {
    useAlert('Não foi possível carregar os cartões do Kanban.');
  } finally {
    isLoading.value = false;
  }
};

const filteredColumnItems = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  const prio = selectedPriority.value;
  const result = {};

  COLUMNS.forEach(col => {
    const list = columnItems.value[col.id] || [];
    result[col.id] = list.filter(conv => {
      if (prio && (conv.priority || '') !== prio) return false;
      if (!query) return true;
      const senderName = (conv.meta?.sender?.name || '').toLowerCase();
      const senderEmail = (conv.meta?.sender?.email || '').toLowerCase();
      const senderPhone = (conv.meta?.sender?.phone_number || '').toLowerCase();
      const idStr = String(conv.id || '');
      const lastMsg = (
        conv.last_non_activity_message?.content ||
        conv.messages?.[0]?.content ||
        ''
      ).toLowerCase();
      return (
        senderName.includes(query) ||
        senderEmail.includes(query) ||
        senderPhone.includes(query) ||
        idStr.includes(query) ||
        lastMsg.includes(query)
      );
    });
  });

  return result;
});

const totalConversations = computed(() =>
  COLUMNS.reduce(
    (acc, col) => acc + (filteredColumnItems.value[col.id]?.length || 0),
    0
  )
);

const getInboxName = inboxId => {
  if (!inboxId) return 'Canal';
  const found = (allInboxes.value || []).find(i => i.id === inboxId);
  return found?.name || 'Canal';
};

const getLabelStyle = labelTitle => {
  const found = (allLabels.value || []).find(l => l.title === labelTitle);
  const color = found?.color || '#10B981';
  return {
    borderColor: `${color}55`,
    backgroundColor: `${color}1F`,
    color,
  };
};

const formatLastActivity = ts => {
  if (!ts) return '';
  try {
    return formatDistanceToNow(fromUnixTime(ts), {
      addSuffix: true,
      locale: dateFnsLocales[locale.value] || ptBR,
    });
  } catch {
    return '';
  }
};

const getLastMessageText = conv => {
  const msg = conv.last_non_activity_message || conv.messages?.[0];
  if (!msg) return 'Sem mensagens recentes';
  if (msg.content) return msg.content;
  if (msg.attachments?.length) return '📎 Anexo enviado';
  return 'Mensagem sem texto';
};

const openConversation = conv => {
  const path = frontendURL(
    conversationUrl({ accountId: accountId.value, id: conv.id })
  );
  router.push(path);
};

const moveConversationToStatus = async (conv, targetStatus) => {
  const sourceStatus = conv.status;
  if (!conv || sourceStatus === targetStatus) return;

  // Optimistic update
  columnItems.value[sourceStatus] = (
    columnItems.value[sourceStatus] || []
  ).filter(item => item.id !== conv.id);
  const updatedConv = { ...conv, status: targetStatus };
  columnItems.value[targetStatus] = [
    updatedConv,
    ...(columnItems.value[targetStatus] || []),
  ];

  try {
    await InboxConversationAPI.toggleStatus({
      conversationId: conv.id,
      status: targetStatus,
    });
    useAlert(`Conversa #${conv.id} movida para ${targetStatus.toUpperCase()}`);
  } catch {
    fetchBoardData();
    useAlert('Erro ao mover conversa no Kanban.');
  }
};

const updateConversationPriority = async (conv, newPriority) => {
  const prevPriority = conv.priority;
  conv.priority = newPriority || null;
  try {
    await InboxConversationAPI.togglePriority({
      conversationId: conv.id,
      priority: newPriority || null,
    });
  } catch {
    conv.priority = prevPriority;
    useAlert('Não foi possível alterar a prioridade.');
  }
};

const onDragStart = (event, conv) => {
  draggedConversation.value = conv;
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', String(conv.id));
  }
};

const onDragOver = (event, colId) => {
  event.preventDefault();
  dragOverColumnId.value = colId;
};

const onDragLeave = colId => {
  if (dragOverColumnId.value === colId) {
    dragOverColumnId.value = null;
  }
};

const onDrop = async (event, targetColId) => {
  event.preventDefault();
  dragOverColumnId.value = null;
  const conv = draggedConversation.value;
  draggedConversation.value = null;
  if (conv && conv.status !== targetColId) {
    await moveConversationToStatus(conv, targetColId);
  }
};

watch([selectedInboxId, selectedAssigneeType], () => {
  fetchBoardData();
});

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  store.dispatch('labels/get');
  fetchBoardData();
});
</script>

<template>
  <section
    class="msc-kanban-root flex flex-col w-full h-full min-w-0 overflow-hidden select-none"
  >
    <!-- Top Header & Controls -->
    <header
      class="flex flex-col gap-3 px-4 py-3.5 md:px-6 md:py-4 border-b border-emerald-500/15 bg-[#060C14]/90 backdrop-blur-md flex-shrink-0"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-3 min-w-0">
          <div
            class="flex items-center justify-center size-10 rounded-xl bg-gradient-to-br from-emerald-500/20 to-lime-400/10 border border-emerald-500/30 shadow-[0_0_20px_rgba(16,185,129,0.2)] flex-shrink-0"
          >
            <Icon
              icon="i-lucide-kanban"
              class="size-5 text-emerald-400 flex-shrink-0"
            />
          </div>
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h1
                class="text-base md:text-lg font-bold tracking-tight text-white truncate"
              >
                Kanban de Atendimento
              </h1>
              <span
                class="inline-flex items-center px-2 py-0.5 text-[11px] font-semibold rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/30"
              >
                {{ totalConversations }} conversas
              </span>
            </div>
            <p class="text-xs text-slate-400 truncate">
              Gerencie o funil de conversas em tempo real no Meu Super Chat
            </p>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-emerald-300 bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/25 transition-all cursor-pointer"
            :disabled="isLoading"
            @click="fetchBoardData"
          >
            <Icon
              icon="i-lucide-refresh-cw"
              class="size-3.5"
              :class="{ 'animate-spin': isLoading }"
            />
            <span>Atualizar</span>
          </button>
        </div>
      </div>

      <!-- Filter Bar -->
      <div
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5 items-center"
      >
        <!-- Search -->
        <div class="relative flex items-center">
          <Icon
            icon="i-lucide-search"
            class="size-4 text-emerald-400/80 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none z-10"
          />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar contato, #ID ou mensagem..."
            style="padding-left: 2.25rem !important; margin-bottom: 0 !important;"
            class="w-full pr-3 py-1.5 h-9 text-xs text-slate-100 placeholder-slate-500 rounded-lg bg-[#09131F] border border-emerald-500/20 focus:border-emerald-400 focus:outline-none"
          />
        </div>

        <!-- Inbox Filter -->
        <select
          v-model="selectedInboxId"
          style="margin-bottom: 0 !important; padding-right: 2rem !important;"
          class="w-full px-3 py-1.5 h-9 text-xs text-slate-100 rounded-lg bg-[#09131F] border border-emerald-500/20 focus:border-emerald-400 focus:outline-none"
        >
          <option value="">Todas as Caixas de Entrada</option>
          <option
            v-for="inbox in allInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>

        <!-- Assignee Type Filter -->
        <select
          v-model="selectedAssigneeType"
          style="margin-bottom: 0 !important; padding-right: 2rem !important;"
          class="w-full px-3 py-1.5 h-9 text-xs text-slate-100 rounded-lg bg-[#09131F] border border-emerald-500/20 focus:border-emerald-400 focus:outline-none"
        >
          <option value="all">Todos os Responsáveis</option>
          <option value="me">Atribuídas a mim</option>
          <option value="unassigned">Não atribuídas</option>
        </select>

        <!-- Priority Filter -->
        <select
          v-model="selectedPriority"
          style="margin-bottom: 0 !important; padding-right: 2rem !important;"
          class="w-full px-3 py-1.5 h-9 text-xs text-slate-100 rounded-lg bg-[#09131F] border border-emerald-500/20 focus:border-emerald-400 focus:outline-none"
        >
          <option value="">Todas as Prioridades</option>
          <option value="urgent">Urgente</option>
          <option value="high">Alta</option>
          <option value="medium">Média</option>
          <option value="low">Baixa</option>
        </select>
      </div>

      <!-- Mobile Stage Switcher (visible on < md screens) -->
      <div class="flex md:hidden items-center gap-1.5 overflow-x-auto pb-1">
        <button
          v-for="col in COLUMNS"
          :key="col.id"
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap border transition-all"
          :class="
            activeMobileColumn === col.id
              ? 'bg-emerald-500/20 text-emerald-300 border-emerald-400/50'
              : 'bg-[#09131F]/80 text-slate-400 border-white/5'
          "
          @click="activeMobileColumn = col.id"
        >
          <Icon :icon="col.icon" class="size-3.5" />
          <span>{{ col.title }}</span>
          <span
            class="px-1.5 py-0.2 text-[10px] rounded-full bg-black/40 text-slate-200"
          >
            {{ (filteredColumnItems[col.id] || []).length }}
          </span>
        </button>
      </div>
    </header>

    <!-- Main Kanban Columns Grid -->
    <div
      class="flex-1 min-h-0 overflow-y-auto md:overflow-hidden p-3 md:p-5 bg-[#04080E]"
    >
      <div
        class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3.5 h-full min-h-0"
      >
        <div
          v-for="col in COLUMNS"
          :key="col.id"
          class="flex flex-col min-h-0 rounded-2xl border transition-all duration-200 bg-[#08101B]/90 backdrop-blur-md"
          :class="[
            dragOverColumnId === col.id
              ? 'border-emerald-400 shadow-[0_0_25px_rgba(16,185,129,0.22)]'
              : 'border-emerald-500/15',
            activeMobileColumn === col.id ? 'flex' : 'hidden md:flex',
          ]"
          @dragover="onDragOver($event, col.id)"
          @dragleave="onDragLeave(col.id)"
          @drop="onDrop($event, col.id)"
        >
          <!-- Column Header -->
          <div
            class="flex items-center justify-between px-3.5 py-3 border-b border-white/5 flex-shrink-0"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span
                class="size-2.5 rounded-full flex-shrink-0"
                :style="{
                  backgroundColor: col.accentColor,
                  boxShadow: `0 0 10px ${col.accentColor}`,
                }"
              />
              <div class="min-w-0">
                <h2 class="text-xs font-bold uppercase tracking-wider text-white truncate">
                  {{ col.title }}
                </h2>
                <p class="text-[11px] text-slate-400 truncate">
                  {{ col.subtitle }}
                </p>
              </div>
            </div>
            <span
              class="px-2 py-0.5 text-xs font-bold rounded-full border flex-shrink-0"
              :class="col.badgeClass"
            >
              {{ (filteredColumnItems[col.id] || []).length }}
            </span>
          </div>

          <!-- Column Cards List -->
          <div class="flex-1 min-h-0 overflow-y-auto p-2.5 space-y-2.5">
            <!-- Empty state per column -->
            <div
              v-if="!(filteredColumnItems[col.id] || []).length && !isLoading"
              class="flex flex-col items-center justify-center h-44 text-center px-4 rounded-xl border border-dashed border-white/10 bg-[#050B12]/50"
            >
              <Icon
                :icon="col.icon"
                class="size-6 text-slate-500 mb-2 opacity-60"
              />
              <p class="text-xs font-medium text-slate-300">
                Nenhuma conversa em {{ col.title }}
              </p>
              <p class="text-[11px] text-slate-500 mt-0.5">
                Arraste um card para cá ou aguarde novos atendimentos
              </p>
            </div>

            <!-- Conversation Card -->
            <article
              v-for="conv in filteredColumnItems[col.id]"
              :key="conv.id"
              draggable="true"
              class="group relative flex flex-col gap-2 p-3 rounded-xl border border-emerald-500/15 bg-[#0B1523]/95 hover:border-emerald-400/50 hover:bg-[#0E1B2D] transition-all cursor-grab active:cursor-grabbing shadow-sm"
              @dragstart="onDragStart($event, conv)"
            >
              <!-- Card Top Row: Contact + ID -->
              <div class="flex items-start justify-between gap-2">
                <div
                  class="flex items-center gap-2 min-w-0 flex-1 cursor-pointer"
                  @click="openConversation(conv)"
                >
                  <Avatar
                    :name="conv.meta?.sender?.name || 'Contato'"
                    :src="conv.meta?.sender?.thumbnail || ''"
                    :size="28"
                    rounded-full
                    class="flex-shrink-0"
                  />
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center gap-1.5">
                      <span
                        class="text-xs font-semibold text-white truncate group-hover:text-emerald-300 transition-colors"
                      >
                        {{ conv.meta?.sender?.name || 'Visitante' }}
                      </span>
                      <span class="text-[10px] font-mono text-slate-400 flex-shrink-0">
                        #{{ conv.display_id || conv.id }}
                      </span>
                    </div>
                    <span class="block text-[10px] text-emerald-400/80 truncate">
                      {{ getInboxName(conv.inbox_id) }}
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  title="Abrir conversa"
                  class="p-1 rounded-md text-slate-400 hover:text-emerald-300 hover:bg-emerald-500/10 transition-colors cursor-pointer flex-shrink-0"
                  @click="openConversation(conv)"
                >
                  <Icon icon="i-lucide-external-link" class="size-3.5" />
                </button>
              </div>

              <!-- Last Message Preview -->
              <p
                class="text-xs text-slate-300 line-clamp-2 leading-relaxed cursor-pointer"
                @click="openConversation(conv)"
              >
                {{ getLastMessageText(conv) }}
              </p>

              <!-- Labels -->
              <div
                v-if="conv.labels && conv.labels.length"
                class="flex flex-wrap gap-1"
              >
                <span
                  v-for="label in conv.labels.slice(0, 4)"
                  :key="label"
                  class="px-1.5 py-0.5 text-[10px] font-medium rounded-md border"
                  :style="getLabelStyle(label)"
                >
                  {{ label }}
                </span>
              </div>

              <!-- Card Footer: Assignee, Priority & Quick Stage Move -->
              <div
                class="flex items-center justify-between gap-2 pt-2 border-t border-white/5 text-[11px] text-slate-400"
              >
                <div class="flex items-center gap-1.5 min-w-0">
                  <Icon
                    icon="i-lucide-user-check"
                    class="size-3 text-emerald-400 flex-shrink-0"
                  />
                  <span class="truncate max-w-[110px]">
                    {{ conv.meta?.assignee?.name || 'Sem agente' }}
                  </span>
                </div>

                <div class="flex items-center gap-1.5 flex-shrink-0">
                  <!-- Quick Priority Selector -->
                  <select
                    :value="conv.priority || ''"
                    class="px-1.5 py-0.5 text-[10px] rounded bg-[#060C14] border border-white/10 text-slate-300 focus:outline-none cursor-pointer"
                    title="Prioridade"
                    @change="
                      updateConversationPriority(conv, $event.target.value)
                    "
                  >
                    <option
                      v-for="p in PRIORITY_OPTIONS"
                      :key="String(p.value)"
                      :value="p.value || ''"
                    >
                      {{ p.label }}
                    </option>
                  </select>

                  <!-- Quick Status Stage Selector -->
                  <select
                    :value="conv.status"
                    class="px-1.5 py-0.5 text-[10px] rounded bg-emerald-500/10 border border-emerald-500/25 text-emerald-300 focus:outline-none cursor-pointer"
                    title="Mover etapa"
                    @change="
                      moveConversationToStatus(conv, $event.target.value)
                    "
                  >
                    <option
                      v-for="stage in COLUMNS"
                      :key="stage.id"
                      :value="stage.id"
                    >
                      {{ stage.title }}
                    </option>
                  </select>
                </div>
              </div>

              <!-- Timestamp & Unread count -->
              <div class="flex items-center justify-between text-[10px] text-slate-500">
                <span>{{ formatLastActivity(conv.last_activity_at) }}</span>
                <span
                  v-if="conv.unread_count > 0"
                  class="px-1.5 py-0.2 rounded-full bg-emerald-500 text-black font-bold"
                >
                  {{ conv.unread_count }} nova(s)
                </span>
              </div>
            </article>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
