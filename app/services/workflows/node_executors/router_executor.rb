# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class RouterExecutor < BaseExecutor
      def execute
        routes = config[:routes] || []
        target_handle = 'default'

        routes.each_with_index do |route, idx|
          field_path = route['field']
          actual_val = variable_resolver.extract_value(field_path).to_s.strip.downcase
          expected_val = resolve_vars(route['value'].to_s).strip.downcase

          if actual_val == expected_val
            target_handle = route['handle'] || "route_#{idx + 1}"
            break
          end
        end

        target_nodes = next_nodes(target_handle)
        target_nodes = next_nodes('default') if target_nodes.empty?
        target_nodes = next_nodes if target_nodes.empty?

        {
          status: 'success',
          output: {
            selected_route: target_handle
          },
          next_nodes: target_nodes
        }
      end
    end
  end
end
