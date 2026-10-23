<script setup>
import { computed, ref, watch } from 'vue';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
  },
  contactName: {
    type: String,
    default: 'WhatsApp Oficial',
  },
  avatarUrl: {
    type: String,
    default: '',
  },
  sampleVariables: {
    type: Object,
    default: () => ({
      1: 'Samuel',
      2: 'Meu Super App',
      3: '14:30',
      nome_completo: 'Samuel Silva',
      primeiro_nome: 'Samuel',
      sobrenome: 'Silva',
      telefone: '+55 17 99117-3157',
      ddd: '17',
      nome_indicador: 'Meu Super App',
      link_pedido: 'https://meusuper.app',
      valor_total: 'R$ 497,00',
      codigo_rastreio: 'MSC-8312-BR',
      nome_produto: 'Raio-X Digital 360º',
      chave_ativacao: 'XXXX-YYYY-ZZZZ-WWWW',
    }),
  },
});

const mediaBroken = ref(false);
watch(
  () => props.template.header_content,
  () => {
    mediaBroken.value = false;
  }
);

const samples = computed(() => ({
  1: 'Samuel',
  2: 'Meu Super App',
  3: '14:30',
  nome_completo: 'Samuel Silva',
  primeiro_nome: 'Samuel',
  sobrenome: 'Silva',
  telefone: '+55 17 99117-3157',
  ddd: '17',
  nome_indicador: 'Meu Super App',
  link_pedido: 'https://meusuper.app',
  valor_total: 'R$ 497,00',
  codigo_rastreio: 'MSC-8312-BR',
  nome_produto: 'Raio-X Digital 360º',
  chave_ativacao: 'XXXX-YYYY-ZZZZ-WWWW',
  ...props.sampleVariables,
}));

const escapeHtml = value =>
  value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const headerContent = computed(() => props.template.header_content || '');

const avatarInitials = computed(() => {
  const parts = String(props.contactName || 'WhatsApp')
    .trim()
    .split(/\s+/)
    .slice(0, 2);
  return parts.map(part => part.charAt(0).toUpperCase()).join('') || 'WA';
});

const renderText = value => {
  let text = escapeHtml(value || '');
  text = text.replace(/\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/g, (match, key) => {
    const provided = props.sampleVariables || {};
    let providedKey = null;
    if (Object.prototype.hasOwnProperty.call(provided, key)) {
      providedKey = key;
    } else if (
      Object.prototype.hasOwnProperty.call(provided, key.toLowerCase())
    ) {
      providedKey = key.toLowerCase();
    }
    const val = providedKey
      ? provided[providedKey] || `{{${key}}}`
      : samples.value[key] || samples.value[key.toLowerCase()] || `{{${key}}}`;
    return `<span class="bg-emerald-400/20 text-emerald-200 border border-emerald-400/35 font-semibold px-1.5 py-0.5 rounded-md text-xs inline-block">${escapeHtml(String(val))}</span>`;
  });
  return text
    .replace(/\*([^*]+)\*/g, '<strong class="text-white font-bold">$1</strong>')
    .replace(/_([^_]+)_/g, '<em>$1</em>')
    .replace(/~([^~]+)~/g, '<del>$1</del>');
};

const formattedBody = computed(() =>
  renderText(props.template.body || 'Digite o corpo da mensagem...')
);
const formattedHeader = computed(() => renderText(headerContent.value));
const fileName = computed(() => {
  if (props.template.header_media_name) return props.template.header_media_name;
  const raw = headerContent.value.split('/').pop()?.split('?')[0] || '';
  try {
    return decodeURIComponent(raw) || 'documento.pdf';
  } catch {
    return raw || 'documento.pdf';
  }
});

const headerType = computed(() => props.template.header_type || 'NONE');
const footerText = computed(() => props.template.footer || '');
const buttons = computed(() => {
  if (Array.isArray(props.template.buttons)) {
    return props.template.buttons.filter(b => b && (b.text || b.type));
  }
  return [];
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="relative mx-auto w-full max-w-[340px] select-none">
    <!-- Phone Mockup Container -->
    <div
      class="relative flex flex-col h-[28rem] sm:h-[36rem] lg:h-[40rem] w-full rounded-[44px] bg-[#070E13] p-3 shadow-[0_24px_60px_rgba(0,0,0,0.85),0_0_32px_rgba(16,185,129,0.12)] border-4 border-[#13222B] ring-1 ring-emerald-500/25"
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
        class="relative flex flex-col flex-1 w-full overflow-hidden rounded-[34px] bg-[#0B141A]"
      >
        <!-- Status Bar -->
        <div
          class="flex items-center justify-between px-6 pt-2 pb-1 text-[11px] font-semibold text-white bg-[#111B21] z-20"
        >
          <span>14:32</span>
          <div class="flex items-center gap-1.5 text-xs">
            <span class="text-[10px] text-emerald-400 font-bold">5G</span>
            <span class="i-lucide-signal size-3" />
            <span class="i-lucide-battery-full size-3 text-emerald-400" />
          </div>
        </div>

        <!-- WhatsApp Chat Header -->
        <div
          class="flex items-center gap-2.5 px-3 py-2.5 bg-[#111B21] border-b border-white/[0.06] text-white shadow-md z-20"
        >
          <button type="button" class="text-slate-300 hover:text-white p-0.5">
            <span class="i-lucide-chevron-left size-5" />
          </button>

          <div class="relative shrink-0">
            <img
              v-if="avatarUrl"
              :src="avatarUrl"
              alt=""
              class="w-9 h-9 rounded-full object-cover bg-emerald-500/20 border border-emerald-500/40"
            />
            <div
              v-else
              class="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 text-xs font-bold text-[#03120D] shadow-[0_0_12px_rgba(16,185,129,0.4)]"
            >
              {{ avatarInitials }}
            </div>
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-1">
              <span class="font-semibold text-xs sm:text-sm truncate leading-tight">{{
                contactName
              }}</span>
              <span
                class="i-lucide-badge-check size-3.5 text-emerald-400 shrink-0"
              />
            </div>
            <p class="text-[10px] text-emerald-400/90 leading-tight font-medium">
              Conta comercial oficial
            </p>
          </div>

          <div class="flex items-center gap-2.5 text-slate-300">
            <span class="i-lucide-video size-4" />
            <span class="i-lucide-phone size-4" />
            <span class="i-lucide-ellipsis-vertical size-4" />
          </div>
        </div>

        <!-- Chat Background Wallpaper & Messages Body -->
        <div
          class="flex-1 overflow-y-auto p-3 flex flex-col justify-end gap-2 bg-[#0B141A] bg-[radial-gradient(rgba(16,185,129,0.08)_1px,transparent_1px)] bg-[length:18px_18px]"
        >
          <div class="mx-auto mb-1 px-2.5 py-0.5 rounded-full bg-[#182229] border border-white/[0.06] text-[10px] font-medium text-slate-300">
            Hoje
          </div>

          <!-- WhatsApp Message Bubble (Dark Mode Official Emerald Style) -->
          <div
            class="relative max-w-[94%] w-full self-start rounded-2xl rounded-tl-sm bg-gradient-to-br from-[#005C4B] to-[#04473B] border border-emerald-400/25 p-3.5 text-slate-100 shadow-[0_10px_28px_rgba(0,0,0,0.45)]"
          >
            <!-- Header section -->
            <div
              v-if="headerType === 'TEXT' && headerContent"
              class="mb-2 font-bold text-xs sm:text-sm text-white border-b pb-1.5 border-white/10"
              v-html="formattedHeader"
            />

            <div
              v-else-if="headerType === 'IMAGE'"
              class="mb-2.5 overflow-hidden rounded-xl bg-[#071F1A] border border-emerald-400/20 max-h-40 flex items-center justify-center"
            >
              <img
                v-if="headerContent && !mediaBroken"
                :src="headerContent"
                alt="Imagem do cabeçalho"
                class="w-full h-36 object-cover"
                @error="mediaBroken = true"
              />
              <div
                v-else
                class="h-32 flex flex-col items-center justify-center text-emerald-300/70 gap-1.5"
              >
                <span class="i-lucide-image size-7" />
                <span class="text-[11px] font-medium">Imagem do Cabeçalho</span>
              </div>
            </div>

            <div
              v-else-if="headerType === 'VIDEO'"
              class="mb-2.5 overflow-hidden rounded-xl bg-[#071F1A] border border-emerald-400/20 text-white h-32 flex flex-col items-center justify-center gap-1.5"
            >
              <video
                v-if="headerContent && !mediaBroken"
                :src="headerContent"
                class="w-full h-32 object-cover"
                controls
                @error="mediaBroken = true"
              />
              <template v-else>
                <span class="i-lucide-circle-play size-8 text-emerald-300/80" />
                <span class="text-[11px] text-emerald-200/70">Vídeo do Cabeçalho</span>
              </template>
            </div>

            <div
              v-else-if="headerType === 'DOCUMENT'"
              class="mb-2.5 p-2.5 rounded-xl bg-[#071F1A]/90 flex items-center gap-2.5 border border-emerald-400/20"
            >
              <div
                class="w-8 h-8 rounded-lg bg-rose-500/20 border border-rose-500/40 text-rose-300 flex items-center justify-center font-bold text-[10px]"
              >
                PDF
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-white truncate">
                  {{ fileName }}
                </p>
                <p class="text-[10px] text-emerald-200/70">Documento Anexo</p>
              </div>
            </div>

            <!-- Body Message Section -->
            <div
              class="text-xs text-slate-100 leading-relaxed whitespace-pre-line break-words"
              v-html="formattedBody"
            />

            <!-- Footer Section -->
            <div
              v-if="footerText"
              class="mt-2 text-[11px] text-emerald-200/70 italic"
            >
              {{ footerText }}
            </div>

            <!-- Time and double check -->
            <div
              class="mt-1.5 flex items-center justify-end gap-1 text-[10px] text-emerald-200/75"
            >
              <span>14:32</span>
              <span class="i-lucide-check-check size-3.5 text-cyan-300" />
            </div>

            <!-- Action Buttons attached to message -->
            <div
              v-if="buttons.length"
              class="mt-2.5 pt-2 border-t border-white/15 space-y-1.5"
            >
              <div
                v-for="(btn, idx) in buttons"
                :key="idx"
                class="py-2 px-3 rounded-xl bg-[#06352C]/90 border border-emerald-400/25 text-center text-xs font-semibold text-emerald-300 hover:bg-[#084237] flex items-center justify-center gap-1.5 cursor-pointer transition-colors"
              >
                <span
                  v-if="btn.type === 'URL'"
                  class="i-lucide-external-link size-3.5 shrink-0"
                />
                <span
                  v-else-if="btn.type === 'PHONE_NUMBER'"
                  class="i-lucide-phone size-3.5 shrink-0"
                />
                <span
                  v-else
                  class="i-lucide-reply size-3.5 shrink-0"
                />
                <span class="truncate">{{ btn.text || 'Botão de Ação' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Chat Typing Input Bottom Bar -->
        <div
          class="flex items-center gap-2 p-2.5 bg-[#111B21] border-t border-white/[0.06] z-20"
        >
          <button type="button" class="text-slate-400 hover:text-slate-200 p-1">
            <span class="i-lucide-plus size-5" />
          </button>
          <div
            class="flex-1 bg-[#1F2C34] border border-white/[0.06] rounded-full px-3.5 py-1.5 text-xs text-slate-400"
          >
            Mensagem
          </div>
          <button
            type="button"
            class="w-8 h-8 rounded-full bg-emerald-500 text-[#03120D] flex items-center justify-center shadow-[0_0_12px_rgba(16,185,129,0.4)]"
          >
            <span class="i-lucide-mic size-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
