# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class RouterExecutor < BaseExecutor
      def execute
        routes = Array(config[:routes])
        source_path = config[:source_variable].presence
        target_handle = nil

        routes.each do |route|
          field_path = route['field'].presence || source_path
          actual_val = variable_resolver.extract_value(field_path).to_s.strip.downcase
          expected_val = resolve_vars(route['value'].to_s).strip.downcase
          next unless route_matches?(actual_val, expected_val, route['operator'])

          target_handle = route['name'].presence || route['handle']
          break if target_handle.present?
        end

        target_handle ||= config[:default_route_name].presence || 'Default'
        target_nodes = next_nodes(target_handle)

        {
          status: 'success',
          output: {
            selected_route: target_handle
          },
          next_nodes: target_nodes
        }
      end

      private

      def route_matches?(actual_val, expected_val, operator)
        case operator.to_s
        when 'not_equal_to', '!='
          actual_val != expected_val
        when 'contains'
          actual_val.include?(expected_val)
        else
          actual_val == expected_val
        end
      end
    end
  end
end
