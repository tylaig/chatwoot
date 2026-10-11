# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class BaseExecutor
      attr_reader :execution, :node, :config, :version

      def self.config_for(node)
        return {}.with_indifferent_access if node.blank?

        nested = node.dig('data', 'config')
        top = node['config']
        raw = nested.presence || top || {}
        raw = raw.to_h unless raw.is_a?(Hash)
        raw.with_indifferent_access
      end

      def self.node_type_for(node)
        type = node['type'].to_s
        type = node.dig('data', 'type').to_s if type.blank? || type == 'custom'
        type
      end

      def initialize(execution:, node:, version:)
        @execution = execution
        @node = node
        @config = self.class.config_for(node)
        @version = version
      end

      def execute
        raise NotImplementedError, "#{self.class.name} must implement #execute"
      end

      protected

      def variable_resolver
        @variable_resolver ||= Workflows::VariableResolverService.new(execution)
      end

      def resolve_vars(text)
        variable_resolver.resolve(text)
      end

      def next_nodes(handle = nil)
        edges = version.outgoing_edges(node['id'], handle)
        edges.map { |e| version.find_node(e['target']) }.compact
      end
    end
  end
end
