# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class ConditionExecutor < BaseExecutor
      def execute
        conditions = config[:conditions] || []
        match_type = config[:match_type] || 'all' # 'all' or 'any'

        results = conditions.map do |cond|
          evaluate_single_condition(cond)
        end

        is_match = if match_type == 'any'
                     results.any?
                   else
                     results.all?
                   end

        handle = is_match ? 'yes' : 'no'
        target_nodes = next_nodes(handle)

        # Fallback if no specific handle edge
        target_nodes = next_nodes if target_nodes.empty?

        {
          status: 'success',
          output: {
            matched: is_match,
            branch_taken: handle,
            conditions_count: conditions.size
          },
          next_nodes: target_nodes
        }
      end

      private

      def evaluate_single_condition(cond)
        field_path = cond['field'] || cond['variable']
        raw_val = variable_resolver.extract_value(field_path).to_s
        expected_val = resolve_vars(cond['value'].to_s)
        operator = cond['operator'] || 'equal_to'

        case operator
        when 'equal_to', 'equals', '=='
          raw_val.downcase.strip == expected_val.downcase.strip
        when 'not_equal_to', '!=', 'different'
          raw_val.downcase.strip != expected_val.downcase.strip
        when 'contains'
          raw_val.downcase.include?(expected_val.downcase)
        when 'does_not_contain', 'not_contains'
          !raw_val.downcase.include?(expected_val.downcase)
        when 'starts_with'
          raw_val.downcase.start_with?(expected_val.downcase)
        when 'ends_with'
          raw_val.downcase.end_with?(expected_val.downcase)
        when 'is_empty', 'empty'
          raw_val.blank?
        when 'is_not_empty', 'not_empty'
          raw_val.present?
        when 'greater_than', '>'
          raw_val.to_f > expected_val.to_f
        when 'less_than', '<'
          raw_val.to_f < expected_val.to_f
        else
          raw_val == expected_val
        end
      end
    end
  end
end
