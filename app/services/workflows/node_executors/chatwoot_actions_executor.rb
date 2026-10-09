# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class ChatwootActionsExecutor < BaseExecutor
      def execute
        action_type = config[:action_type] || config[:action] || node['type']
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
            updates[:phone_number] = resolve_vars(config[:phone_number]) if config[:phone_number].present?

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

        when 'update_custom_attribute'
          target = config[:target] || 'contact' # 'contact' or 'conversation'
          attr_key = config[:attribute_key]
          attr_val = resolve_vars(config[:attribute_value].to_s)

          if target == 'conversation' && conversation.present? && attr_key.present?
            existing_attrs = conversation.custom_attributes || {}
            existing_attrs[attr_key] = attr_val
            conversation.update!(custom_attributes: existing_attrs)
            result_data[:updated_conversation_attribute] = { attr_key => attr_val }
          elsif contact.present? && attr_key.present?
            existing_attrs = contact.custom_attributes || {}
            existing_attrs[attr_key] = attr_val
            contact.update!(custom_attributes: existing_attrs)
            result_data[:updated_contact_attribute] = { attr_key => attr_val }
          end

        when 'update_conversation'
          if conversation.present?
            updates = {}
            updates[:status] = config[:status] if config[:status].present? && %w[open resolved pending snoozed].include?(config[:status].to_s)
            updates[:priority] = config[:priority] if config[:priority].present? && %w[low medium high urgent].include?(config[:priority].to_s)
            conversation.update!(updates) if updates.present?
            result_data[:updated_conversation] = updates
          end

        when 'assign_agent'
          if conversation.present?
            agent_id = config[:agent_id] || config[:assignee_id]
            agent = account.users.find_by(id: agent_id)
            if agent.present?
              conversation.update!(assignee_id: agent.id)
              result_data[:assigned_agent_id] = agent.id
            end
          end

        when 'assign_team'
          if conversation.present?
            team_id = config[:team_id]
            team = account.teams.find_by(id: team_id)
            if team.present?
              conversation.update!(team_id: team.id)
              result_data[:assigned_team_id] = team.id
            end
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

        when 'end_workflow'
          result_data[:workflow_ended] = true
          return {
            status: 'success',
            output: result_data,
            next_nodes: [] # Stops any further branches
          }
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
