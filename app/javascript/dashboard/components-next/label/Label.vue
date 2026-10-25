<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: {
    type: [Object, String],
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  color: {
    type: String,
    default: 'slate',
    validator: value =>
      ['slate', 'amber', 'teal', 'ruby', 'blue', 'iris'].includes(value),
  },
});

const COLOR_CLASSES = {
  slate: 'bg-n-label-color outline-n-label-border text-n-slate-12',
  amber: 'bg-n-amber-2 outline-n-amber-4 text-n-amber-11',
  teal: 'bg-n-teal-2 outline-n-teal-4 text-n-teal-11',
  ruby: 'bg-n-ruby-2 outline-n-ruby-4 text-n-ruby-11',
  blue: 'bg-n-blue-2 outline-n-blue-4 text-n-blue-11',
  iris: 'bg-n-iris-2 outline-n-iris-4 text-n-iris-11',
};

const isStringLabel = computed(() => typeof props.label === 'string');

const labelTitle = computed(() => {
  return isStringLabel.value ? props.label : props.label?.title;
});

const labelDescription = computed(() => {
  return (!isStringLabel.value && props.label?.description) || '';
});

const labelColor = computed(() => {
  return isStringLabel.value ? null : props.label.color;
});

const labelStyle = computed(() => {
  if (!labelColor.value) return {};
  return {
    '--msc-label-color': labelColor.value,
  };
});

const colorClasses = computed(() => COLOR_CLASSES[props.color]);
</script>

<template>
  <div
    :title="labelDescription"
    :style="labelStyle"
    class="rounded-full -outline-offset-1 outline outline-1 inline-flex items-center flex-shrink-0 font-semibold msc-label-pill"
    :class="[
      colorClasses,
      compact ? 'px-2 h-5.5 gap-1.5 text-[11px]' : 'px-2.5 h-7 gap-1.5 text-xs',
    ]"
  >
    <span
      v-if="labelColor"
      class="rounded-full flex-shrink-0"
      :class="compact ? 'size-2' : 'size-2.5'"
      :style="{ background: labelColor }"
    />
    <slot v-else name="icon" />
    <span
      class="whitespace-nowrap"
      :class="compact ? 'text-label-small' : 'text-label !font-420'"
    >
      {{ labelTitle }}
    </span>
    <slot name="action" />
  </div>
</template>

<style scoped>
.msc-label-pill {
  background: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 14%,
    #ffffff
  ) !important;
  outline-color: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 34%,
    transparent
  ) !important;
  color: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 76%,
    #0f172a
  ) !important;
}

:global(.dark) .msc-label-pill {
  background: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 20%,
    #09131d
  ) !important;
  outline-color: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 42%,
    transparent
  ) !important;
  color: color-mix(
    in srgb,
    var(--msc-label-color, #10b981) 55%,
    #f8fafc
  ) !important;
}
</style>
