# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class ChatwootActionsExecutor < BaseExecutor
      def execute
        action_type = config[:action_type] || config[:action]
        conversation = execution.conversation
        contact = execution.contact
        account = execution.account

        result_data = {}

        case action_type
        when 'add_tag', 'add_label'
          tag_name = resolve_vars(config[:tag_name] || config[:label] || '')
          if conversation.present? && tag_name.present?
            conversation.add_labels([tag_name])
            result_data[:added_tag] = tag_name
          end

        when 'remove_tag', 'remove_label'
          tag_name = resolve_vars(config[:tag_name] || config[:label] || '')
          if conversation.present? && tag_name.present?
            tag_list = conversation.label_list - [tag_name]
            conversation.update_labels(tag_list)
            result_data[:removed_tag] = tag_name
          end

        when 'update_contact'
          if contact.present?
            updates = {}
            updates[:name] = resolve_vars(config[:name]) if config[:name].present?
            updates[:email] = resolve_vars(config[:email]) if config[:email].present?
            if config[:custom_attributes].is_a?(Hash)
              existing_attrs = contact.custom_attributes || {}
              config[:custom_attributes].each do |k, v|
                existing_attrs[k] = resolve_vars(v.to_s)
              end
              updates[:custom_attributes] = existing_attrs
            end
            contact.update!(updates) if updates.present?
            result_data[:updated_contact_id] = contact.id
          end

        when 'resolve_conversation'
          if conversation.present?
            conversation.resolved!
            result_data[:conversation_status] = 'resolved'
          end

        when 'reopen_conversation'
          if conversation.present?
            conversation.open!
            result_data[:conversation_status] = 'open'
          end

        when 'add_private_note'
          if conversation.present?
            note_content = resolve_vars(config[:note] || config[:content] || '')
            conversation.messages.create!(
              account_id: account.id,
              inbox_id: conversation.inbox_id,
              message_type: :activity,
              private: true,
              content: note_content
            )
            result_data[:private_note_added] = true
          end

        when 'set_variable'
          var_name = config[:variable_name]
          var_val = resolve_vars(config[:variable_value].to_s)
          current_vars = execution.variables || {}
          current_vars[var_name] = var_val
          execution.update!(variables: current_vars)
          result_data[:variable_set] = { var_name => var_val }
        else
          # Fallback to check if node['type'] matches direct action
          if node['type'] == 'add_tag'
            tag_name = resolve_vars(config[:tag_name] || config[:label] || '')
            if conversation.present? && tag_name.present?
              conversation.add_labels([tag_name])
              result_data[:added_tag] = tag_name
            end
          elsif node['type'] == 'resolve_conversation'
            conversation&.resolved!
            result_data[:conversation_status] = 'resolved'
          end
        end

        {
          status: 'success',
          output: result_data,
          next_nodes: next_nodes
        }
      end
    end
  end
end
