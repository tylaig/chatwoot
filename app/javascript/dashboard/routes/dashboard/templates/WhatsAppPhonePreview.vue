<script setup>
import { computed } from 'vue';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
  },
  contactName: {
    type: String,
    default: 'Games Safari Oficial',
  },
  avatarUrl: {
    type: String,
    default: 'https://gamessafari.com/cdn/shop/files/logo_png_sem_controle.png',
  },
  sampleVariables: {
    type: Object,
    default: () => ({
      1: 'Samuel',
      2: '7420',
      3: 'Concluído',
      nome_completo: 'Samuel Silva',
      primeiro_nome: 'Samuel',
      sobrenome: 'Silva',
      telefone: '+55 17 99117-3157',
      ddd: '17',
      nome_indicador: 'Games Safari',
      link_pedido: 'https://gamessafari.com',
      valor_total: 'R$ 214,50',
      codigo_rastreio: 'GS-8312-BR',
      nome_produto: 'EA SPORTS FC 27',
      chave_ativacao: 'XXXX-YYYY-ZZZZ-WWWW',
    }),
  },
});

const formattedBody = computed(() => {
  let text = props.template.body || 'Digite o corpo da mensagem...';

  // Replace variable placeholders like {{1}} or {{primeiro_nome}}
  text = text.replace(/\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/g, (match, key) => {
    const val =
      props.sampleVariables[key] ||
      props.sampleVariables[key.toLowerCase()] ||
      `[${key}]`;
    return `<span class="bg-amber-100 dark:bg-amber-900/40 text-amber-900 dark:text-amber-200 font-semibold px-1 py-0.5 rounded text-xs inline-block">${val}</span>`;
  });

  // Basic markdown: *bold*, _italic_, ~strike~
  text = text
    .replace(/\*([^*]+)\*/g, '<strong>$1</strong>')
    .replace(/_([^_]+)_/g, '<em>$1</em>')
    .replace(/~([^~]+)~/g, '<del>$1</del>');

  return text;
});

const headerType = computed(() => props.template.header_type || 'NONE');
const headerContent = computed(() => props.template.header_content || '');
const footerText = computed(() => props.template.footer || '');
const buttons = computed(() => {
  if (Array.isArray(props.template.buttons)) {
    return props.template.buttons.filter(b => b && (b.text || b.type));
  }
  return [];
});
</script>

<template>
  <div class="relative mx-auto w-full max-w-[340px] select-none">
    <!-- Phone Mockup Container -->
    <div
      class="relative flex flex-col h-[640px] w-full rounded-[44px] bg-[#1a1c22] p-3 shadow-2xl border-4 border-slate-800 ring-1 ring-white/10"
    >
      <!-- Top Speaker / Dynamic Island Notch -->
      <div
        class="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-5 bg-black rounded-full z-30 flex items-center justify-center"
      >
        <div
          class="w-3 h-3 rounded-full bg-slate-900 mr-2 border border-slate-800"
        />
        <div class="w-12 h-1.5 rounded-full bg-slate-900" />
      </div>

      <!-- Phone Screen -->
      <div
        class="relative flex flex-col flex-1 w-full overflow-hidden rounded-[34px] bg-[#EFEAE2] dark:bg-[#0b141a]"
      >
        <!-- Status Bar -->
        <div
          class="flex items-center justify-between px-6 pt-2 pb-1 text-[11px] font-semibold text-white bg-[#075E54] dark:bg-[#1f2c34] z-20"
        >
          <span>0:24</span>
          <div class="flex items-center gap-1.5 text-xs">
            <span class="text-[10px]">5G</span>
            <span>📶</span>
            <span>🔋</span>
          </div>
        </div>

        <!-- WhatsApp Chat Header -->
        <div
          class="flex items-center gap-2 px-3 py-2 bg-[#075E54] dark:bg-[#1f2c34] text-white shadow-md z-20"
        >
          <button type="button" class="text-white hover:opacity-80 p-0.5">
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2.5"
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>

          <div class="relative shrink-0">
            <img
              :src="avatarUrl"
              alt="Avatar"
              class="w-9 h-9 rounded-full object-cover bg-white border border-white/20 p-0.5"
            />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-1">
              <span class="font-semibold text-sm truncate leading-tight">{{
                contactName
              }}</span>
              <svg
                class="w-3.5 h-3.5 text-emerald-400 shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <p class="text-[10px] text-white/80 leading-tight">Online</p>
          </div>

          <div class="flex items-center gap-3 text-white/90">
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
              />
            </svg>
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
              />
            </svg>
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"
              />
            </svg>
          </div>
        </div>

        <!-- Chat Background Wallpaper & Messages Body -->
        <div
          class="flex-1 overflow-y-auto p-3 flex flex-col justify-end gap-2"
          style="
            background-image: radial-gradient(
              rgba(0, 0, 0, 0.06) 1px,
              transparent 1px
            );
            background-size: 16px 16px;
          "
        >
          <!-- WhatsApp Message Bubble -->
          <div
            class="relative max-w-[92%] self-start bg-white dark:bg-[#1f2c34] text-slate-900 dark:text-slate-100 rounded-2xl rounded-tl-sm p-3 shadow-sm border border-black/5"
          >
            <!-- Header section -->
            <div
              v-if="headerType === 'TEXT' && headerContent"
              class="mb-2 font-bold text-sm text-slate-900 dark:text-white border-b pb-1 border-slate-100 dark:border-slate-700"
            >
              {{ headerContent }}
            </div>

            <div
              v-else-if="headerType === 'IMAGE'"
              class="mb-2 overflow-hidden rounded-lg bg-slate-100 dark:bg-slate-800 max-h-40 flex items-center justify-center"
            >
              <img
                v-if="headerContent"
                :src="headerContent"
                alt="Header Media"
                class="w-full h-36 object-contain p-1"
              />
              <div
                v-else
                class="h-32 flex flex-col items-center justify-center text-slate-400 gap-1"
              >
                <svg
                  class="w-8 h-8"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                <span class="text-xs">Imagem do Cabeçalho</span>
              </div>
            </div>

            <div
              v-else-if="headerType === 'VIDEO'"
              class="mb-2 rounded-lg bg-slate-800 text-white h-32 flex flex-col items-center justify-center gap-1"
            >
              <svg
                class="w-10 h-10 text-white/80"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="text-xs text-white/70">Vídeo do Cabeçalho</span>
            </div>

            <div
              v-else-if="headerType === 'DOCUMENT'"
              class="mb-2 p-2.5 rounded-lg bg-slate-50 dark:bg-slate-800 flex items-center gap-2 border border-slate-200 dark:border-slate-700"
            >
              <div
                class="w-8 h-8 rounded bg-rose-500 text-white flex items-center justify-center font-bold text-xs"
              >
                PDF
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold truncate">
                  {{ headerContent || 'documento_oficial.pdf' }}
                </p>
                <p class="text-[10px] text-slate-400">Documento Anexo</p>
              </div>
            </div>

            <!-- Body Message Section -->
            <div
              class="text-xs text-slate-800 dark:text-slate-100 leading-relaxed whitespace-pre-line"
              v-html="formattedBody"
            />

            <!-- Footer Section -->
            <div
              v-if="footerText"
              class="mt-2 text-[11px] text-slate-400 dark:text-slate-400 italic"
            >
              {{ footerText }}
            </div>

            <!-- Time and double check -->
            <div
              class="mt-1 flex items-center justify-end gap-1 text-[10px] text-slate-400"
            >
              <span>0:24</span>
              <span class="text-sky-500 font-bold">✓✓</span>
            </div>

            <!-- Action Buttons attached to message -->
            <div
              v-if="buttons.length"
              class="mt-2 -mx-3 -mb-3 divide-y divide-slate-100 dark:divide-slate-700/80 border-t border-slate-100 dark:border-slate-700/80"
            >
              <div
                v-for="(btn, idx) in buttons"
                :key="idx"
                class="py-2 px-3 text-center text-xs font-medium text-[#00A884] dark:text-emerald-400 hover:bg-slate-50 dark:hover:bg-slate-800/50 flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <svg
                  v-if="btn.type === 'URL'"
                  class="w-3.5 h-3.5 text-current shrink-0"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                  />
                </svg>
                <svg
                  v-else-if="btn.type === 'PHONE_NUMBER'"
                  class="w-3.5 h-3.5 text-current shrink-0"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
                  />
                </svg>
                <svg
                  v-else
                  class="w-3.5 h-3.5 text-current shrink-0"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"
                  />
                </svg>
                <span class="truncate">{{ btn.text || 'Botão' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Chat Typing Input Bottom Bar -->
        <div
          class="flex items-center gap-2 p-2 bg-[#F0F2F5] dark:bg-[#1f2c34] z-20"
        >
          <button type="button" class="text-slate-500 hover:text-slate-700 p-1">
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
          </button>
          <div
            class="flex-1 bg-white dark:bg-[#2a3942] rounded-full px-3 py-1.5 text-xs text-slate-400"
          >
            Mensagem
          </div>
          <button
            type="button"
            class="w-8 h-8 rounded-full bg-[#00A884] text-white flex items-center justify-center hover:opacity-90"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 100-6 3 3 0 000 6z"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
