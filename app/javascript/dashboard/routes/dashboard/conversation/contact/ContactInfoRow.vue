<script>
import { useAlert } from 'dashboard/composables';
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import NextButton from 'dashboard/components-next/button/Button.vue';
import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';

export default {
  components: {
    EmojiOrIcon,
    NextButton,
    InlineInput,
  },
  props: {
    href: {
      type: String,
      default: '',
    },
    icon: {
      type: String,
      required: true,
    },
    emoji: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      default: '',
    },
    showCopy: {
      type: Boolean,
      default: false,
    },
    editable: {
      type: Boolean,
      default: false,
    },
    title: {
      type: String,
      default: '',
    },
  },
  emits: ['update'],
  data() {
    return {
      isEditing: false,
      editValue: '',
    };
  },
  methods: {
    async onCopy(e) {
      e.preventDefault();
      e.stopPropagation();
      if (!this.value) return;
      await copyTextToClipboard(this.value);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
    },
    startEditing(e) {
      if (e) {
        e.preventDefault();
        e.stopPropagation();
      }
      if (!this.editable) return;
      this.editValue = this.value || '';
      this.isEditing = true;
      this.$nextTick(() => {
        this.$refs.editInput?.focus();
      });
    },
    saveEdit() {
      if (!this.isEditing) return;
      this.isEditing = false;
      const trimmed = this.editValue.trim();
      if (trimmed !== (this.value || '')) {
        this.$emit('update', trimmed);
      }
    },
    cancelEdit() {
      this.isEditing = false;
    },
  },
};
</script>

<template>
  <div
    class="group/row msc-contact-info-pill flex items-center justify-between w-full p-2.5 rounded-xl bg-[#0F171C]/90 border border-white/[0.07] hover:border-emerald-500/30 transition-all duration-200"
  >
    <!-- Inline edit mode -->
    <div v-if="isEditing" class="flex items-center w-full min-w-0 gap-3">
      <div
        class="w-9 h-9 rounded-lg bg-emerald-500/10 border border-emerald-500/25 flex items-center justify-center text-emerald-400 flex-shrink-0"
      >
        <EmojiOrIcon :icon="icon" :emoji="emoji" icon-size="16" />
      </div>
      <div class="flex flex-col flex-1 min-w-0">
        <span
          v-if="title"
          class="text-[11px] font-medium text-slate-400 leading-tight mb-0.5"
        >
          {{ title }}
        </span>
        <InlineInput
          ref="editInput"
          v-model="editValue"
          :placeholder="title"
          @enter-press="saveEdit"
          @escape-press="cancelEdit"
          @blur="saveEdit"
        />
      </div>
    </div>

    <!-- Read mode -->
    <template v-else>
      <component
        :is="href && value ? 'a' : 'div'"
        :href="href && value ? href : undefined"
        class="flex items-center gap-3 min-w-0 flex-1 no-underline hover:no-underline"
        @DoubleClick="startEditing"
      >
        <div
          class="w-9 h-9 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 flex-shrink-0 shadow-[inset_0_1px_0_rgba(167,243,208,0.12)]"
        >
          <EmojiOrIcon :icon="icon" :emoji="emoji" icon-size="16" />
        </div>
        <div class="flex flex-col min-w-0 flex-1 text-left">
          <span
            v-if="title"
            class="text-[11px] font-medium text-slate-400 leading-tight"
          >
            {{ title }}
          </span>
          <span
            v-if="value"
            v-dompurify-html="value"
            class="overflow-hidden text-sm font-medium text-slate-100 whitespace-nowrap text-ellipsis leading-snug"
            :title="value"
          />
          <span v-else class="text-xs text-slate-500 leading-snug">
            {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
          </span>
        </div>
      </component>

      <div class="flex items-center gap-1 flex-shrink-0 ml-2">
        <button
          v-if="editable"
          type="button"
          class="w-7 h-7 rounded-lg bg-white/[0.02] border border-transparent hover:border-white/[0.1] hover:bg-white/[0.06] flex items-center justify-center text-slate-400 hover:text-emerald-300 opacity-0 group-hover/row:opacity-100 transition-all"
          :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
          @click="startEditing"
        >
          <span class="i-lucide-pencil text-xs" />
        </button>
        <button
          v-if="(showCopy || value) && value"
          type="button"
          class="w-8 h-8 rounded-lg bg-white/[0.03] border border-white/[0.08] hover:border-emerald-500/35 hover:bg-emerald-500/10 flex items-center justify-center text-slate-300 hover:text-emerald-300 transition-all"
          :title="$t('CONTACT_PANEL.COPY_SUCCESSFUL')"
          @click="onCopy"
        >
          <span class="i-lucide-copy text-xs" />
        </button>
      </div>
    </template>
  </div>
</template>
