<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  templates: {
    type: Array,
    default: () => [],
  },
  selectedTemplateName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'select']);

const searchQuery = ref('');
const selectedInbox = ref('ALL');
const selectedLanguage = ref('pt_BR');
const selectedCategory = ref('ALL');
const selectedStatus = ref('APPROVED');
const activeTemplate = ref(null);
const defaultModalPreviewBody =
  'Olá {{1}}! 👋\nBem-vindo à Games Safari!\n\nAqui você encontra os melhores jogos e ofertas exclusivas. Qualquer dúvida, é só nos chamar por aqui. 🚀';

const filteredTemplates = computed(() => {
  return props.templates.filter(tpl => {
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
    const matchesStatus =
      selectedStatus.value === 'ALL' || tpl.status === selectedStatus.value;
    return matchesSearch && matchesCat && matchesLang && matchesStatus;
  });
});

const selectActive = tpl => {
  activeTemplate.value = tpl;
};

const handleConfirm = () => {
  if (activeTemplate.value) {
    emit('select', activeTemplate.value);
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/html-closing-bracket-newline -->
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 select-none text-n-slate-12"
  >
    <div
      class="w-full max-w-4xl h-[620px] rounded-2xl bg-n-solid-1 border border-n-weak shadow-2xl flex flex-col overflow-hidden"
    >
      <!-- HEADER DO MODAL -->
      <div
        class="px-6 py-4 border-b border-n-weak flex items-center justify-between bg-n-solid-1"
      >
        <div class="flex items-center gap-3">
          <div
            class="w-8 h-8 rounded-full bg-[#25D366] flex items-center justify-center shrink-0 shadow-sm"
          >
            <svg class="w-4 h-4 text-white fill-current" viewBox="0 0 24 24">
              <path
                d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"
              />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-bold text-n-slate-12">
              Selecionar Template WhatsApp
            </h3>
            <p class="text-xs text-n-slate-11">
              Escolha um template aprovado pela Meta para enviar aos seus
              contatos.
            </p>
          </div>
        </div>
        <button
          type="button"
          class="text-n-slate-9 hover:text-n-slate-12 text-sm p-1 rounded-lg"
          @click="emit('close')"
        >
          ✕
        </button>
      </div>

      <!-- CORPO COM COLUNA ESQUERDA (BUSCA/LISTA) E DIREITA (PREVIEW) -->
      <div class="flex flex-1 min-h-0 overflow-hidden">
        <!-- COLUNA ESQUERDA -->
        <div
          class="w-3/5 border-r border-n-weak p-5 flex flex-col min-h-0 space-y-4 bg-n-solid-1"
        >
          <!-- BARRA DE PESQUISA -->
          <div class="relative">
            <span class="absolute left-3 top-2.5 text-xs text-n-slate-9"
              >🔍</span
            >
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar templates..."
              class="w-full pl-8 pr-3 py-2 text-xs rounded-xl bg-n-alpha-1 border border-n-weak text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:border-blue-500"
            />
          </div>

          <!-- FILTROS (INBOX, IDIOMA, CATEGORIA, STATUS) -->
          <div class="grid grid-cols-4 gap-2">
            <div>
              <label class="block text-[10px] text-n-slate-11 mb-1"
                >Inbox</label
              >
              <select
                v-model="selectedInbox"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
              >
                <option value="ALL">Suporte - WhatsApp</option>
              </select>
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-11 mb-1"
                >Idioma</label
              >
              <select
                v-model="selectedLanguage"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
              >
                <option value="ALL">Todos</option>
                <option value="pt_BR">Português (Brasil)</option>
                <option value="en_US">Inglês (US)</option>
                <option value="es">Espanhol</option>
              </select>
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-11 mb-1"
                >Categoria</label
              >
              <select
                v-model="selectedCategory"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
              >
                <option value="ALL">Todas</option>
                <option value="MARKETING">Marketing</option>
                <option value="UTILITY">Utility</option>
                <option value="AUTHENTICATION">Authentication</option>
              </select>
            </div>
            <div>
              <label class="block text-[10px] text-n-slate-11 mb-1"
                >Status</label
              >
              <select
                v-model="selectedStatus"
                class="w-full px-2 py-1.5 text-xs rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 focus:outline-none focus:border-blue-500"
              >
                <option value="ALL">Todos</option>
                <option value="APPROVED">Approved</option>
                <option value="PENDING">Pending</option>
                <option value="REJECTED">Rejected</option>
              </select>
            </div>
          </div>

          <!-- LISTA DE TEMPLATES COM BADGES -->
          <div class="flex-1 overflow-y-auto space-y-2 pr-1">
            <div
              v-for="tpl in filteredTemplates"
              :key="tpl.id"
              class="p-3 rounded-xl border transition-all cursor-pointer flex items-center justify-between"
              :class="
                activeTemplate?.id === tpl.id ||
                (!activeTemplate && selectedTemplateName === tpl.name)
                  ? 'bg-blue-600/10 border-blue-500 shadow-sm'
                  : 'bg-n-solid-2 border-n-weak hover:border-n-strong'
              "
              @click="selectActive(tpl)"
            >
              <div class="flex items-start gap-2.5 min-w-0">
                <span class="text-sm mt-0.5">📄</span>
                <div class="min-w-0">
                  <h4 class="text-xs font-bold text-n-slate-12 truncate">
                    {{ tpl.name }}
                  </h4>
                  <p
                    class="text-[11px] text-n-slate-11 line-clamp-1 leading-tight"
                  >
                    {{ tpl.body }}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-1.5 shrink-0 ml-2">
                <span
                  class="text-[10px] px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11 font-medium"
                >
                  {{ tpl.category }}
                </span>
                <span
                  class="text-[10px] px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-11 font-mono"
                >
                  {{ tpl.language }}
                </span>
                <span
                  class="text-[10px] px-2 py-0.5 rounded-full font-bold"
                  :class="
                    tpl.status === 'APPROVED' || tpl.status === 'approved'
                      ? 'bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30'
                      : 'bg-amber-500/20 text-amber-600 dark:text-amber-400'
                  "
                >
                  {{ tpl.status }}
                </span>
                <span class="text-n-slate-9 text-xs ml-1">›</span>
              </div>
            </div>

            <div
              v-if="!filteredTemplates.length"
              class="py-12 text-center text-xs text-n-slate-9"
            >
              Nenhum template encontrado com os filtros atuais.
            </div>
          </div>
        </div>

        <!-- COLUNA DIREITA: PREVIEW DO TEMPLATE SELECIONADO -->
        <div
          class="w-2/5 p-5 flex flex-col justify-between overflow-y-auto bg-n-solid-2"
        >
          <div class="space-y-4">
            <h4
              class="text-xs font-bold text-n-slate-11 uppercase tracking-wider"
            >
              Pré-visualização do Template
            </h4>

            <!-- BALÃO WHATSAPP -->
            <div
              class="p-4 rounded-2xl bg-[#E1F8DC] dark:bg-[#1E2C22] border border-[#C5E8BF] dark:border-[#2D4533] text-slate-900 dark:text-slate-100 text-xs shadow-sm space-y-2 relative"
            >
              <p class="whitespace-pre-line leading-relaxed font-sans">
                {{ activeTemplate?.body || defaultModalPreviewBody }}
              </p>
              <div class="text-[10px] text-n-slate-11 text-right">12:30</div>

              <!-- BOTÕES DO TEMPLATE SE EXISTIREM -->
              <div class="pt-2 border-t border-emerald-600/20 space-y-1.5">
                <button
                  type="button"
                  class="w-full py-1.5 px-3 rounded-lg bg-white/70 dark:bg-n-solid-3/80 text-blue-600 dark:text-blue-400 font-semibold text-center text-[11px] flex items-center justify-center gap-1.5 shadow-sm"
                >
                  <span>🔗</span> Ver ofertas
                </button>
                <button
                  type="button"
                  class="w-full py-1.5 px-3 rounded-lg bg-white/70 dark:bg-n-solid-3/80 text-blue-600 dark:text-blue-400 font-semibold text-center text-[11px] flex items-center justify-center gap-1.5 shadow-sm"
                >
                  <span>💬</span> Falar com suporte
                </button>
              </div>
            </div>

            <!-- INFORMAÇÕES DO TEMPLATE -->
            <div
              class="p-3.5 rounded-xl bg-n-solid-1 border border-n-weak space-y-2 text-xs"
            >
              <h5 class="text-xs font-bold text-n-slate-12">
                Informações do Template
              </h5>
              <div class="grid grid-cols-2 gap-2 text-[11px]">
                <div>
                  <span class="text-n-slate-9">Nome:</span>
                  <p class="font-bold text-n-slate-12">
                    {{ activeTemplate?.name || 'boas_vindas_novo_cliente' }}
                  </p>
                </div>
                <div>
                  <span class="text-n-slate-9">Categoria:</span>
                  <p class="font-semibold text-n-slate-11">
                    {{ activeTemplate?.category || 'Marketing' }}
                  </p>
                </div>
                <div>
                  <span class="text-n-slate-9">Idioma:</span>
                  <p class="font-semibold text-n-slate-11">
                    {{ activeTemplate?.language || 'pt_BR' }}
                  </p>
                </div>
                <div>
                  <span class="text-n-slate-9">Status:</span>
                  <p class="font-bold text-emerald-600 dark:text-emerald-400">
                    {{ activeTemplate?.status || 'Approved' }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- FOOTER ACTION -->
          <div
            class="pt-4 border-t border-n-weak flex items-center justify-end gap-2.5"
          >
            <button
              type="button"
              class="px-4 py-2 rounded-xl border border-n-weak text-xs font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
              @click="emit('close')"
            >
              Cancelar
            </button>
            <button
              type="button"
              class="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20 transition-all disabled:opacity-50"
              :disabled="!activeTemplate"
              @click="handleConfirm"
            >
              Usar Template
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
