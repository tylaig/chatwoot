# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class BaseExecutor
      attr_reader :execution, :node, :config, :version

      def initialize(execution:, node:, version:)
        @execution = execution
        @node = node
        @config = (node['config'] || {}).with_indifferent_access
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
