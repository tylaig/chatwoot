json.id resource.id
json.rating resource.rating
json.feedback_message resource.feedback_message
json.csat_review_notes resource.csat_review_notes
json.review_notes_updated_at resource.review_notes_updated_at&.to_i
if resource.review_notes_updated_by
  json.review_notes_updated_by do
    json.id resource.review_notes_updated_by.id
    json.name resource.review_notes_updated_by.name
  end
end
json.account_id resource.account_id
json.message_id resource.message_id
if resource.contact
  json.contact do
    json.partial! 'api/v1/models/contact', formats: [:json], resource: resource.contact
  end
end
json.conversation_id resource.conversation.display_id
json.inbox_name resource.conversation.inbox&.name
if resource.assigned_agent
  json.assigned_agent do
    json.partial! 'api/v1/models/agent', formats: [:json], resource: resource.assigned_agent
  end
end
json.handled_by_ai resource.assigned_agent.nil?
json.ai_agent_name(
  if resource.assigned_agent.nil?
    resource.conversation.ai_assignee.try(:name) ||
      resource.conversation.inbox&.captain_assistant&.name ||
      'Leo (IA)'
  end
)
json.created_at resource.created_at.to_i
