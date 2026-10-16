class Captain::ConversationCompletionSchema < RubyLLM::Schema
  boolean :complete, description: 'Whether the conversation is complete and can be immediately closed'
  string :status, description: 'Decision status: "complete" (ready to close), "awaiting_customer_reply" (assistant asked for customer data like email/order/screenshot and is waiting for customer reply — snooze), or "needs_human" (customer needs human agent intervention)'
  string :reason, description: 'Brief explanation in Brazilian Portuguese of why the conversation is complete, awaiting customer reply, or needs human handoff'
end
