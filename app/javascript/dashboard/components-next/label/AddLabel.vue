<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

defineProps({
  labelMenuItems: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updateLabel']);

const { t } = useI18n();

const showDropdown = ref(false);
</script>

<template>
  <div class="relative">
    <button
      type="button"
      class="flex items-center gap-1.5 px-3 py-1 rounded-lg border border-dashed border-[#264252] hover:border-[#10B981] bg-[#050C10] hover:bg-[#10B981]/10 h-7 transition-colors cursor-pointer"
      :class="{ '!border-[#10B981] !bg-[#10B981]/10': showDropdown }"
      @click="showDropdown = !showDropdown"
    >
      <span class="i-lucide-plus size-3.5 text-[#10B981]" />
      <span class="text-xs font-medium text-slate-200">
        {{ t('LABEL.TAG_BUTTON') }}
      </span>
    </button>
    <DropdownMenu
      v-if="showDropdown"
      v-on-clickaway="() => (showDropdown = false)"
      :menu-items="labelMenuItems"
      show-search
      class="z-[100] w-48 mt-2 ltr:left-0 rtl:right-0 top-full max-h-52"
      @action="emit('updateLabel', $event)"
    >
      <template #thumbnail="{ item }">
        <div
          class="rounded-sm size-2"
          :style="{ backgroundColor: item.thumbnail.color }"
        />
      </template>
    </DropdownMenu>
  </div>
</template>
