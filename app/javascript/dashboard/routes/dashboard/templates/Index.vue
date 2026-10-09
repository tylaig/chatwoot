<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import whatsappTemplatesApi from 'dashboard/api/whatsappTemplates';

const templates = ref([]);
const stats = ref({ total: 0, approved: 0, pending: 0, rejected: 0 });
const isLoading = ref(true);
const searchQuery = ref('');
const selectedInbox = ref('ALL');
const selectedLanguage = ref('ALL');
const selectedCategory = ref('ALL');
const selectedStatus = ref('ALL');
const previewTemplate = ref(null);
const activeDrawerTab = ref('details'); // 'details', 'edit', 'history'
const defaultPreviewBody =
  'Olá {{1}}! 👋\nBem-vindo à Games Safari!\n\nAqui você encontra os melhores jogos e ofertas exclusivas. Qualquer dúvida, é só nos chamar por aqui. 🚀';

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const res = await whatsappTemplatesApi.getTemplates();
    templates.value = res.data.templates || [];
    stats.value = res.data.stats || {
      total: 0,
      approved: 0,
      pending: 0,
      rejected: 0,
    };
    if (templates.value.length && !previewTemplate.value) {
      previewTemplate.value = templates.value[0];
    }
  } catch (err) {
    useAlert('Erro ao carregar templates.');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchTemplates();
});

const filteredTemplates = computed(() => {
  return templates.value.filter(tpl => {
    const matchesSearch =
      !searchQuery.value ||
      tpl.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      tpl.body?.toLowerCase().includes(searchQuery.value.toLowerCase());
    const matchesCat =
      selectedCategory.value === 'ALL' ||
      tpl.category === selectedCategory.value;
    const matchesLang =
      selectedLanguage.value === 'ALL' ||
      tpl.language === selectedLanguage.value;
    const matchesStat =
      selectedStatus.value === 'ALL' || tpl.status === selectedStatus.value;
    return matchesSearch && matchesCat && matchesLang && matchesStat;
  });
});

const handleSelectTemplate = tpl => {
  previewTemplate.value = tpl;
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    class="flex h-full bg-[#0D1017] text-slate-100 overflow-hidden select-none"
  >
    <!-- COLUNA ESQUERDA: LISTA & FILTROS DE TEMPLATES -->
    <div class="flex-1 flex flex-col min-w-0 border-r border-slate-800">
      <!-- HEADER -->
      <header
        class="p-6 border-b border-slate-800 bg-[#14171F] flex items-center justify-between"
      >
        <div>
          <h1 class="text-xl font-bold text-white tracking-tight">
            Templates WhatsApp
          </h1>
          <p class="text-xs text-slate-400 mt-1">
            Gerencie modelos de mensagens aprovados pela Meta para usar nos seus
            workflows.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <button
            type="button"
            class="px-3.5 py-2 rounded-xl border border-slate-700 bg-[#14171F] hover:bg-slate-800 text-xs font-semibold text-slate-300 transition-colors flex items-center gap-1.5"
            @click="fetchTemplates"
          >
            <span>🔄</span>
            <span>Sincronizar com a Meta</span>
          </button>

          <button
            type="button"
            class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center gap-1.5"
          >
            <span>+</span>
            <span>Criar Template</span>
          </button>
        </div>
      </header>

      <!-- BARRA DE PESQUISA E FILTROS HORIZONTAIS (ESTILO REFERENCE PACK) -->
      <div
        class="p-6 pb-4 flex flex-col md:flex-row gap-3 items-center justify-between"
      >
        <div class="relative flex-1 w-full">
          <span class="absolute left-3.5 top-2.5 text-xs text-slate-500"
            >🔍</span
          >
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar templates..."
            class="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-[#14171F] border border-slate-800 text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div class="flex items-center gap-3 w-full md:w-auto">
          <div class="flex items-center gap-2">
            <span class="text-xs text-slate-400">Inbox</span>
            <select
              v-model="selectedInbox"
              class="px-3 py-1.5 text-xs rounded-xl bg-[#14171F] border border-slate-800 text-slate-300 focus:outline-none"
            >
              <option value="ALL">Todos</option>
              <option value="1">Suporte - WhatsApp</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-slate-400">Idioma</span>
            <select
              v-model="selectedLanguage"
              class="px-3 py-1.5 text-xs rounded-xl bg-[#14171F] border border-slate-800 text-slate-300 focus:outline-none"
            >
              <option value="ALL">Todos</option>
              <option value="pt_BR">pt_BR</option>
              <option value="en_US">en_US</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-slate-400">Categoria</span>
            <select
              v-model="selectedCategory"
              class="px-3 py-1.5 text-xs rounded-xl bg-[#14171F] border border-slate-800 text-slate-300 focus:outline-none"
            >
              <option value="ALL">Todas</option>
              <option value="MARKETING">Marketing</option>
              <option value="UTILITY">Utility</option>
              <option value="AUTHENTICATION">Authentication</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <span class="text-xs text-slate-400">Status</span>
            <select
              v-model="selectedStatus"
              class="px-3 py-1.5 text-xs rounded-xl bg-[#14171F] border border-slate-800 text-slate-300 focus:outline-none"
            >
              <option value="ALL">Todos</option>
              <option value="APPROVED">Approved</option>
              <option value="PENDING">Pending</option>
              <option value="REJECTED">Rejected</option>
            </select>
          </div>
        </div>
      </div>

      <!-- TABELA DE TEMPLATES -->
      <div class="flex-1 overflow-y-auto px-6 pb-6">
        <div
          class="border border-slate-800/80 rounded-2xl bg-[#14171F] overflow-hidden"
        >
          <table class="w-full text-left border-collapse text-xs">
            <thead>
              <tr
                class="border-b border-slate-800/80 text-[11px] font-semibold text-slate-400 uppercase tracking-wider"
              >
                <th class="py-3 px-4">Nome do Template</th>
                <th class="py-3 px-4">Categoria</th>
                <th class="py-3 px-4">Idioma</th>
                <th class="py-3 px-4">Status</th>
                <th class="py-3 px-4">Última Atualização</th>
                <th class="py-3 px-4 text-right">Ações</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60">
              <tr
                v-for="tpl in filteredTemplates"
                :key="tpl.id"
                class="hover:bg-slate-800/30 transition-colors cursor-pointer"
                :class="previewTemplate?.id === tpl.id ? 'bg-blue-600/10' : ''"
                @click="handleSelectTemplate(tpl)"
              >
                <!-- NOME COM ÍCONE -->
                <td
                  class="py-3.5 px-4 font-bold text-slate-100 flex items-center gap-3"
                >
                  <div
                    class="w-8 h-8 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center font-bold text-sm shrink-0"
                  >
                    📄
                  </div>
                  <div class="min-w-0">
                    <p class="truncate">{{ tpl.name }}</p>
                    <p
                      class="text-[11px] text-slate-400 font-normal truncate max-w-[220px]"
                    >
                      {{ tpl.body }}
                    </p>
                  </div>
                </td>

                <!-- CATEGORIA -->
                <td class="py-3.5 px-4">
                  <span
                    class="px-2.5 py-0.5 rounded-full bg-purple-500/20 text-purple-400 text-[10px] font-bold"
                  >
                    {{ tpl.category || 'Marketing' }}
                  </span>
                </td>

                <!-- IDIOMA -->
                <td class="py-3.5 px-4 font-mono text-slate-300">
                  {{ tpl.language || 'pt_BR' }}
                </td>

                <!-- STATUS -->
                <td class="py-3.5 px-4">
                  <span
                    class="px-2.5 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1.5 w-max"
                    :class="
                      tpl.status === 'APPROVED' || tpl.status === 'approved'
                        ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                        : tpl.status === 'PENDING'
                          ? 'bg-amber-500/20 text-amber-400'
                          : 'bg-rose-500/20 text-rose-400'
                    "
                  >
                    <span
                      class="w-1.5 h-1.5 rounded-full"
                      :class="
                        tpl.status === 'APPROVED' || tpl.status === 'approved'
                          ? 'bg-emerald-400'
                          : tpl.status === 'PENDING'
                            ? 'bg-amber-400'
                            : 'bg-rose-400'
                      "
                    />
                    {{ tpl.status }}
                  </span>
                </td>

                <!-- DATA -->
                <td class="py-3.5 px-4 text-slate-400 font-mono text-[11px]">
                  10 out 2026, 14:32
                </td>

                <!-- AÇÕES -->
                <td class="py-3.5 px-4 text-right">
                  <button
                    type="button"
                    class="text-slate-400 hover:text-white p-1 rounded-lg"
                  >
                    •••
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- COLUNA DIREITA: DRAWER DE DETALHES & PREVIEW WHATSAPP (100% FIEL AO REFERENCE PACK) -->
    <div
      v-if="previewTemplate"
      class="w-96 bg-[#14171F] flex flex-col justify-between overflow-y-auto p-6 space-y-6 select-none shrink-0"
    >
      <div class="space-y-6">
        <!-- HEADER DO DRAWER -->
        <div
          class="flex items-center justify-between pb-4 border-b border-slate-800"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="w-9 h-9 rounded-xl bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-lg"
            >
              📄
            </div>
            <div class="min-w-0">
              <h3 class="text-sm font-bold text-white truncate">
                {{ previewTemplate.name }}
              </h3>
              <div class="flex items-center gap-2 mt-0.5">
                <span
                  class="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-400 font-bold"
                >
                  {{ previewTemplate.category || 'Marketing' }}
                </span>
                <span
                  class="text-[10px] text-emerald-400 font-bold flex items-center gap-1"
                >
                  ● Approved
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- TABS DO DRAWER -->
        <div class="flex border-b border-slate-800 text-xs">
          <button
            type="button"
            class="pb-2 px-3 font-semibold transition-colors"
            :class="
              activeDrawerTab === 'details'
                ? 'text-blue-400 border-b-2 border-blue-500'
                : 'text-slate-400'
            "
            @click="activeDrawerTab = 'details'"
          >
            Detalhes
          </button>
          <button
            type="button"
            class="pb-2 px-3 font-semibold transition-colors"
            :class="
              activeDrawerTab === 'edit'
                ? 'text-blue-400 border-b-2 border-blue-500'
                : 'text-slate-400'
            "
            @click="activeDrawerTab = 'edit'"
          >
            Editar
          </button>
          <button
            type="button"
            class="pb-2 px-3 font-semibold transition-colors"
            :class="
              activeDrawerTab === 'history'
                ? 'text-blue-400 border-b-2 border-blue-500'
                : 'text-slate-400'
            "
            @click="activeDrawerTab = 'history'"
          >
            Histórico
          </button>
        </div>

        <!-- INFORMAÇÕES DO TEMPLATE -->
        <div
          class="p-3.5 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 text-xs"
        >
          <h4 class="font-bold text-slate-300">Informações do Template</h4>
          <div class="grid grid-cols-2 gap-2 text-[11px] text-slate-400">
            <div>
              <span class="text-slate-500 block">Nome:</span>
              <span class="font-bold text-slate-200">{{
                previewTemplate.name
              }}</span>
            </div>
            <div>
              <span class="text-slate-500 block">Categoria:</span>
              <span class="text-slate-200">{{
                previewTemplate.category || 'Marketing'
              }}</span>
            </div>
            <div>
              <span class="text-slate-500 block">Idioma:</span>
              <span class="text-slate-200">{{
                previewTemplate.language || 'pt_BR'
              }}</span>
            </div>
            <div>
              <span class="text-slate-500 block">Status:</span>
              <span class="text-emerald-400 font-bold">Approved</span>
            </div>
          </div>
        </div>

        <!-- CONTEÚDO DO TEMPLATE / BALÃO WHATSAPP -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <h4 class="text-xs font-bold text-slate-300">
              Conteúdo do Template
            </h4>
            <div
              class="flex rounded-lg bg-[#0D1017] p-0.5 border border-slate-800"
            >
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-semibold bg-blue-600 text-white rounded"
              >
                Visualização
              </button>
              <button
                type="button"
                class="px-2 py-0.5 text-[10px] font-semibold text-slate-400 rounded"
              >
                Código JSON
              </button>
            </div>
          </div>

          <!-- BALÃO WHATSAPP -->
          <div
            class="p-4 rounded-2xl bg-[#E1F8DC] dark:bg-[#1E2C22] border border-[#C5E8BF] dark:border-[#2D4533] text-slate-900 dark:text-slate-100 text-xs shadow-sm space-y-2 relative"
          >
            <p class="whitespace-pre-line leading-relaxed font-sans">
              {{ previewTemplate.body || defaultPreviewBody }}
            </p>
            <div class="text-[10px] text-slate-400 text-right">12:30</div>

            <div class="pt-2 border-t border-emerald-600/20 space-y-1.5">
              <button
                type="button"
                class="w-full py-1.5 px-3 rounded-lg bg-white/70 dark:bg-slate-800/80 text-blue-600 dark:text-blue-400 font-semibold text-center text-[11px] flex items-center justify-center gap-1.5 shadow-sm"
              >
                <span>🔗</span> Ver ofertas
              </button>
              <button
                type="button"
                class="w-full py-1.5 px-3 rounded-lg bg-white/70 dark:bg-slate-800/80 text-blue-600 dark:text-blue-400 font-semibold text-center text-[11px] flex items-center justify-center gap-1.5 shadow-sm"
              >
                <span>💬</span> Falar com suporte
              </button>
            </div>
          </div>
        </div>

        <!-- VARIÁVEIS DO TEMPLATE -->
        <div
          class="p-3.5 rounded-xl bg-[#0D1017] border border-slate-800 space-y-2 text-xs"
        >
          <h4 class="font-bold text-slate-300">Variáveis do Template</h4>
          <div class="space-y-1 text-[11px]">
            <div class="flex items-center justify-between text-slate-300">
              <span class="font-mono text-slate-400"
                >&#123;&#123;1&#125;&#125;</span
              >
              <span>Nome do cliente</span>
              <span class="text-slate-500 font-mono">Exemplo: João</span>
            </div>
            <div class="flex items-center justify-between text-slate-300">
              <span class="font-mono text-slate-400"
                >&#123;&#123;2&#125;&#125;</span
              >
              <span>Link personalizado</span>
              <span class="text-slate-500 font-mono">Exemplo: https://...</span>
            </div>
          </div>
        </div>
      </div>

      <!-- BOTÕES DE AÇÃO DO DRAWER -->
      <div class="pt-4 border-t border-slate-800 space-y-2">
        <button
          type="button"
          class="w-full py-2.5 px-4 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20 transition-all flex items-center justify-center gap-2"
        >
          <span>⚡</span>
          <span>Usar no Workflow</span>
        </button>

        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="py-2 px-3 rounded-xl border border-slate-800 text-xs font-semibold text-slate-300 hover:bg-slate-800 transition-colors"
          >
            Duplicar
          </button>
          <button
            type="button"
            class="py-2 px-3 rounded-xl border border-rose-500/30 text-xs font-semibold text-rose-400 hover:bg-rose-500/10 transition-colors"
          >
            Excluir Template
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
