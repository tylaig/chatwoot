<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ContactSortMenu from './components/ContactSortMenu.vue';
import ContactMoreActions from './components/ContactMoreActions.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

defineProps({
  showSearch: { type: Boolean, default: true },
  searchValue: { type: String, default: '' },
  headerTitle: { type: String, required: true },
  totalItems: { type: Number, default: 0 },
  buttonLabel: { type: String, default: '' },
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
  isSegmentsView: { type: Boolean, default: false },
  hasActiveFilters: { type: Boolean, default: false },
  isLabelView: { type: Boolean, default: false },
  isActiveView: { type: Boolean, default: false },
  canManageActiveSegment: { type: Boolean, default: true },
});

const emit = defineEmits([
  'search',
  'filter',
  'update:sort',
  'add',
  'import',
  'export',
  'createSegment',
  'deleteSegment',
]);
</script>

<template>
  <header
    class="sticky top-0 z-20 px-4 sm:px-6 bg-[#050C10]/95 backdrop-blur-md border-b border-[#142633]"
  >
    <div
      class="flex flex-col lg:flex-row lg:items-center justify-between w-full py-3.5 sm:py-4 gap-3 mx-auto max-w-5xl"
    >
      <div class="flex items-center gap-3 min-w-0">
        <span class="text-xl font-bold tracking-tight truncate text-white">
          {{ headerTitle }}
        </span>
        <span
          v-if="totalItems"
          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-[#10B981]/15 text-[#10B981] border border-[#10B981]/30 shrink-0"
        >
          {{ totalItems }}
        </span>
      </div>
      <div class="flex items-center flex-wrap sm:flex-nowrap justify-between lg:justify-end gap-2 sm:gap-2.5 w-full lg:w-auto">
        <div
          v-if="showSearch"
          class="flex items-center gap-2 w-full sm:flex-1 lg:w-64 xl:w-72 min-w-0"
        >
          <Input
            :model-value="searchValue"
            type="search"
            :placeholder="$t('CONTACTS_LAYOUT.HEADER.SEARCH_PLACEHOLDER')"
            :custom-input-class="[
              'h-9 !bg-[#081218] !border !border-[#1A303D] focus:!border-[#10B981] !outline-none rounded-lg ltr:!pl-9 !py-1.5 rtl:!pr-9 text-sm text-white placeholder:text-slate-400',
            ]"
            class="w-full"
            @input="emit('search', $event.target.value)"
          >
            <template #prefix>
              <Icon
                icon="i-lucide-search"
                class="absolute -translate-y-1/2 text-slate-400 size-4 top-1/2 ltr:left-3 rtl:right-3"
              />
            </template>
          </Input>
        </div>
        <div class="flex items-center flex-shrink-0 gap-2 sm:gap-2.5 ml-auto sm:ml-0">
          <div class="flex items-center gap-1.5">
            <div
              v-if="
                !isLabelView &&
                !isActiveView &&
                (!isSegmentsView || canManageActiveSegment)
              "
              class="relative"
            >
              <Button
                id="toggleContactsFilterButton"
                :icon="
                  isSegmentsView ? 'i-lucide-pen-line' : 'i-lucide-list-filter'
                "
                color="slate"
                size="sm"
                class="relative !h-9 !w-9 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-lg"
                variant="ghost"
                @click="emit('filter')"
              >
                <div
                  v-if="hasActiveFilters && !isSegmentsView"
                  class="absolute top-1 right-1 w-2 h-2 rounded-full bg-[#10B981]"
                />
              </Button>
              <slot name="filter" />
            </div>
            <Button
              v-if="
                hasActiveFilters &&
                !isSegmentsView &&
                !isLabelView &&
                !isActiveView
              "
              icon="i-lucide-save"
              color="slate"
              size="sm"
              class="!h-9 !w-9 !bg-[#081218] !border !border-[#1A303D] hover:!border-[#10B981]/50 rounded-lg"
              variant="ghost"
              @click="emit('createSegment')"
            />
            <Button
              v-if="
                isSegmentsView &&
                !isLabelView &&
                !isActiveView &&
                canManageActiveSegment
              "
              icon="i-lucide-trash"
              color="slate"
              size="sm"
              class="!h-9 !w-9 !bg-[#081218] !border !border-[#1A303D] hover:!border-red-500/50 rounded-lg"
              variant="ghost"
              @click="emit('deleteSegment')"
            />
            <Button
              v-if="
                isSegmentsView &&
                !isLabelView &&
                !isActiveView &&
                !canManageActiveSegment
              "
              v-tooltip.bottom-end="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.READ_ONLY_TOOLTIP'
                )
              "
              :aria-label="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.READ_ONLY_TOOLTIP'
                )
              "
              icon="i-lucide-info"
              color="slate"
              size="sm"
              class="!h-9 !w-9 !bg-[#081218] !border !border-[#1A303D] rounded-lg"
              variant="ghost"
            />
            <ContactSortMenu
              :active-sort="activeSort"
              :active-ordering="activeOrdering"
              @update:sort="emit('update:sort', $event)"
            />
            <ContactMoreActions
              @add="emit('add')"
              @import="emit('import')"
              @export="emit('export')"
            />
          </div>
          <div class="w-px h-5 bg-[#1A303D]" />
          <ComposeConversation>
            <template #trigger>
              <Button
                :label="buttonLabel"
                icon="i-lucide-send"
                size="sm"
                class="!h-9 !bg-[#10B981] hover:!bg-[#059669] !text-[#031911] font-semibold shadow-[0_0_14px_rgba(16,185,129,0.25)]"
              />
            </template>
          </ComposeConversation>
        </div>
      </div>
    </div>
  </header>
</template>
