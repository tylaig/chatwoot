<script setup>
import { computed, inject } from 'vue';
import { BaseEdge, EdgeLabelRenderer, getBezierPath, Position } from '@vue-flow/core';

const props = defineProps({
  id: { type: String, required: true },
  sourceX: { type: Number, required: true },
  sourceY: { type: Number, required: true },
  targetX: { type: Number, required: true },
  targetY: { type: Number, required: true },
  sourcePosition: { type: String, required: true },
  targetPosition: { type: String, required: true },
  style: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
});

const builder = inject('workflowBuilder', null);

const path = computed(() => {
  const sx = Number.isFinite(props.sourceX) ? props.sourceX : 0;
  const sy = Number.isFinite(props.sourceY) ? props.sourceY : 0;
  const tx = Number.isFinite(props.targetX) ? props.targetX : sx + 80;
  const ty = Number.isFinite(props.targetY) ? props.targetY : sy;
  return getBezierPath({
    sourceX: sx,
    sourceY: sy,
    targetX: tx,
    targetY: ty,
    sourcePosition: props.sourcePosition || Position.Right,
    targetPosition: props.targetPosition || Position.Left,
    curvature: 0.25,
  });
});

const isActive = computed(
  () => props.selected || builder?.hoveredEdgeId.value === props.id
);

const edgeStyle = computed(() => ({
  ...props.style,
  strokeWidth: isActive.value ? 3.2 : 2.4,
  filter: isActive.value
    ? `drop-shadow(0 0 8px ${props.style?.stroke || '#10B981'})`
    : `drop-shadow(0 0 4px ${props.style?.stroke || 'rgba(16, 185, 129, 0.45)'})`,
}));
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <BaseEdge
    :id="id"
    :path="path[0]"
    :style="edgeStyle"
    :interaction-width="28"
  />
  <EdgeLabelRenderer v-if="builder && !builder.readOnly">
    <div
      class="absolute z-10 nodrag nopan transition-opacity"
      :class="
        isActive
          ? 'opacity-100 pointer-events-auto'
          : 'opacity-0 pointer-events-none'
      "
      :style="{
        transform: `translate(-50%, -50%) translate(${path[1]}px, ${path[2]}px)`,
      }"
      @mouseenter="builder.setHoveredEdge(id)"
      @mouseleave="builder.setHoveredEdge(null)"
    >
      <button
        type="button"
        class="flex items-center justify-center rounded-full size-8 bg-n-ruby-9 text-white shadow-lg"
        title="Remover conexão"
        @click.stop="builder.removeEdge(id)"
      >
        <span class="i-lucide-trash-2 size-4" />
      </button>
    </div>
  </EdgeLabelRenderer>
</template>
