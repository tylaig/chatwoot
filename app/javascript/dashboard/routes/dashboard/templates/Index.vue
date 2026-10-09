<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import WhatsAppPhonePreview from './WhatsAppPhonePreview.vue';
import whatsappTemplatesApi from 'dashboard/api/whatsappTemplates';

const router = useRouter();

const templates = ref([]);
const stats = ref({ total: 0, approved: 0, pending: 0, rejected: 0 });
const isLoading = ref(true);
const searchQuery = ref('');
const selectedCategory = ref('ALL');
const selectedStatus = ref('ALL');
const previewTemplate = ref(null);

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const res = await whatsappTemplatesApi.getTemplates();
    templates.value = res.data.templates || [];
    stats.value = res.data.stats || { total: 0, approved: 0, pending: 0, rejected: 0 };
    if (templates.value.length && !previewTemplate.value) {
      previewTemplate.value = templates.value[0];
    }
  } catch (err) {
    useAlert('Erro ao carregar templates.');
  } finally {
    isLoading.value = false;
  }
};

const filteredTemplates = computed(() => {
  return templates.value.filter(tpl => {
    const matchesSearch =
      tpl.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      tpl.body.toLowerCase().includes(searchQuery.value.toLowerCase());
    const matchesCat = selectedCategory.value === 'ALL' || tpl.category === selectedCategory.value;
    const matchesStat = selectedStatus.value === 'ALL' || tpl.status === selectedStatus.value;
    return matchesSearch && matchesCat && matchesStat;
  });
});

const handleApprove = async (tpl) => {
  try {
    await whatsappTemplatesApi.approveTemplate(tpl.id);
    useAlert(`Template "${tpl.name}" aprovado com sucesso!`);
    await fetchTemplates();
  } catch (err) {
    useAlert('Erro ao aprovar template.');
  }
};

const handleSubmitReview = async (tpl) => {
  try {
    await whatsappTemplatesApi.submitReview(tpl.id);
    useAlert(`Template "${tpl.name}" enviado para revisão da Meta.`);
    await fetchTemplates();
  } catch (err) {
    useAlert('Erro ao enviar para revisão.');
  }
};

const handleDelete = async (tpl) => {
  if (!confirm(`Tem certeza que deseja excluir o template "${tpl.name}"?`)) return;
  try {
    await whatsappTemplatesApi.deleteTemplate(tpl.id);
    useAlert('Template excluído com sucesso.');
    if (previewTemplate.value?.id === tpl.id) {
      previewTemplate.value = null;
    }
    await fetchTemplates();
  } catch (err) {
    useAlert('Erro ao excluir template.');
  }
};

const selectPreview = (tpl) => {
  previewTemplate.value = tpl;
};

onMounted(() => {
  fetchTemplates();
});
</script>

<template>
  <div class="flex-1 flex flex-col bg-slate-50 dark:bg-slate-900 min-h-screen">
    <!-- Header Principal -->
    <header class="border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 px-8 py-5">
      <div class="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <span>Gerenciador de Templates WhatsApp</span>
              <span class="text-xs px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 font-semibold">
                Oficial Meta & Cloud API
              </span>
            </h1>
          </div>
          <p class="text-sm text-slate-500 mt-1">
            Crie, aprove, edite e acompanhe os modelos HSM com variáveis dinâmicas e preview em tempo real.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <button
            type="button"
            class="px-4 py-2 text-xs font-semibold rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors flex items-center gap-2"
            @click="fetchTemplates"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <span>Atualizar</span>
          </button>

          <button
            type="button"
            class="px-5 py-2.5 rounded-xl bg-primary-600 hover:bg-primary-700 text-white font-semibold text-sm shadow-md transition-all flex items-center gap-2"
            @click="$router.push({ name: 'whatsapp_templates_new' })"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            <span>Novo Template</span>
          </button>
        </div>
      </div>

      <!-- Métricas / Contadores em Cards -->
      <div class="max-w-7xl mx-auto grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6">
        <div class="p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/50">
          <p class="text-xs text-slate-500 font-medium">Total de Modelos</p>
          <p class="text-xl font-bold text-slate-900 dark:text-white mt-1">{{ stats.total }}</p>
        </div>
        <div class="p-3.5 rounded-2xl border border-emerald-200 dark:border-emerald-950/50 bg-emerald-50/50 dark:bg-emerald-950/20">
          <p class="text-xs text-emerald-600 dark:text-emerald-400 font-medium">Aprovados</p>
          <p class="text-xl font-bold text-emerald-700 dark:text-emerald-300 mt-1">{{ stats.approved }}</p>
        </div>
        <div class="p-3.5 rounded-2xl border border-amber-200 dark:border-amber-950/50 bg-amber-50/50 dark:bg-amber-950/20">
          <p class="text-xs text-amber-600 dark:text-amber-400 font-medium">Em Revisão (Meta)</p>
          <p class="text-xl font-bold text-amber-700 dark:text-amber-300 mt-1">{{ stats.pending }}</p>
        </div>
        <div class="p-3.5 rounded-2xl border border-rose-200 dark:border-rose-950/50 bg-rose-50/50 dark:bg-rose-950/20">
          <p class="text-xs text-rose-600 dark:text-rose-400 font-medium">Rejeitados</p>
          <p class="text-xl font-bold text-rose-700 dark:text-rose-300 mt-1">{{ stats.rejected }}</p>
        </div>
      </div>
    </header>

    <!-- Área de Conteúdo Principal -->
    <main class="flex-1 max-w-7xl w-full mx-auto p-6 md:p-8">
      <!-- Filtros e Busca -->
      <div class="flex flex-col sm:flex-row items-center justify-between gap-4 mb-6">
        <div class="relative w-full sm:w-80">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por nome ou conteúdo..."
            class="w-full pl-9 pr-4 py-2 rounded-xl text-sm border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
          <svg class="w-4 h-4 text-slate-400 absolute left-3 top-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>

        <div class="flex items-center gap-2 w-full sm:w-auto">
          <select
            v-model="selectedCategory"
            class="px-3 py-2 rounded-xl text-xs font-medium border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 focus:outline-none"
          >
            <option value="ALL">Todas as Categorias</option>
            <option value="MARKETING_LITE">Marketing Lite</option>
            <option value="MARKETING">Marketing</option>
            <option value="UTILITY">Utilidade</option>
          </select>

          <select
            v-model="selectedStatus"
            class="px-3 py-2 rounded-xl text-xs font-medium border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 focus:outline-none"
          >
            <option value="ALL">Todos os Status</option>
            <option value="APPROVED">Aprovados</option>
            <option value="PENDING">Em Revisão</option>
            <option value="REJECTED">Rejeitados</option>
          </select>
        </div>
      </div>

      <!-- Lista e Preview Lado a Lado -->
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        <!-- Lista de Templates (7 colunas) -->
        <div class="lg:col-span-7 space-y-3">
          <div v-if="isLoading" class="p-8 text-center text-sm text-slate-400">
            Carregando templates...
          </div>

          <div
            v-else-if="!filteredTemplates.length"
            class="p-12 text-center rounded-2xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
          >
            <p class="text-base font-semibold text-slate-700 dark:text-slate-200">Nenhum template encontrado</p>
            <p class="text-xs text-slate-400 mt-1">Crie um novo template ou ajuste seus filtros.</p>
            <button
              type="button"
              class="mt-4 px-4 py-2 rounded-xl bg-primary-600 text-white font-medium text-xs hover:bg-primary-700"
              @click="$router.push({ name: 'whatsapp_templates_new' })"
            >
              Criar Primeiro Template
            </button>
          </div>

          <div
            v-for="tpl in filteredTemplates"
            v-else
            :key="tpl.id"
            class="p-5 rounded-2xl border transition-all cursor-pointer bg-white dark:bg-slate-800"
            :class="previewTemplate?.id === tpl.id ? 'border-primary-500 shadow-md ring-2 ring-primary-500/20' : 'border-slate-200 dark:border-slate-700/80 hover:border-slate-300'"
            @click="selectPreview(tpl)"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <div class="flex items-center gap-2 flex-wrap">
                  <h3 class="text-sm font-bold text-slate-900 dark:text-white font-mono">
                    {{ tpl.name }}
                  </h3>
                  <!-- Badge de Categoria -->
                  <span
                    class="px-2 py-0.5 text-[10px] font-semibold rounded-md uppercase"
                    :class="tpl.category === 'UTILITY' ? 'bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300' : 'bg-purple-100 text-purple-700 dark:bg-purple-950 dark:text-purple-300'"
                  >
                    {{ tpl.category }}
                  </span>

                  <!-- Badge de Status -->
                  <span
                    class="px-2 py-0.5 text-[10px] font-semibold rounded-md"
                    :class="{
                      'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300': tpl.status === 'APPROVED',
                      'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300': tpl.status === 'PENDING',
                      'bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300': tpl.status === 'REJECTED',
                    }"
                  >
                    {{ tpl.status === 'APPROVED' ? 'Aprovado' : tpl.status === 'PENDING' ? 'Em Análise' : 'Rejeitado' }}
                  </span>
                </div>

                <p class="text-xs text-slate-600 dark:text-slate-300 mt-2 line-clamp-2 leading-relaxed">
                  {{ tpl.body }}
                </p>

                <div class="flex items-center gap-3 mt-3 text-[11px] text-slate-400">
                  <span>Idioma: {{ tpl.language }}</span>
                  <span>•</span>
                  <span>Cabeçalho: {{ tpl.header_type || 'Nenhum' }}</span>
                  <span v-if="tpl.buttons && tpl.buttons.length">•</span>
                  <span v-if="tpl.buttons && tpl.buttons.length">{{ tpl.buttons.length }} botões</span>
                </div>
              </div>

              <!-- Ações Rápidas -->
              <div class="flex items-center gap-1.5 shrink-0" @click.stop>
                <button
                  v-if="tpl.status !== 'APPROVED'"
                  type="button"
                  title="Aprovar Template"
                  class="p-2 rounded-xl text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-950"
                  @click="handleApprove(tpl)"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </button>

                <button
                  v-if="tpl.status === 'APPROVED'"
                  type="button"
                  title="Enviar para Revisão Meta"
                  class="p-2 rounded-xl text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-950"
                  @click="handleSubmitReview(tpl)"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                </button>

                <button
                  type="button"
                  title="Excluir Template"
                  class="p-2 rounded-xl text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-950"
                  @click="handleDelete(tpl)"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Preview Direita (5 colunas) -->
        <div class="lg:col-span-5 sticky top-8 flex flex-col items-center">
          <div class="w-full flex items-center justify-between mb-3 px-2">
            <span class="text-xs font-bold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
              Visualização Interativa
            </span>
            <span v-if="previewTemplate" class="text-xs font-mono font-semibold text-primary-600">
              {{ previewTemplate.name }}
            </span>
          </div>

          <WhatsAppPhonePreview
            v-if="previewTemplate"
            :template="previewTemplate"
            contact-name="Games Safari Oficial"
            avatar-url="https://gamessafari.com/cdn/shop/files/logo_png_sem_controle.png"
          />

          <div
            v-else
            class="h-96 w-full rounded-3xl border-2 border-dashed border-slate-200 dark:border-slate-800 flex items-center justify-center text-slate-400 text-xs"
          >
            Selecione um template ao lado para ver o preview.
          </div>
        </div>
      </div>
    </main>
  </div>
</template>
