class Api::V1::Widget::MessagesController < Api::V1::Widget::BaseController
  before_action :prevent_reply_to_resolved_conversation, only: [:create]
  before_action :set_conversation, only: [:create]
  before_action :enforce_anti_spam_limit, only: [:create]
  before_action :set_message, only: [:update]

  def index
    @messages = conversation.nil? ? [] : message_finder.perform
  end

  def create
    @message = conversation.messages.new(message_params)
    build_attachment
    @message.save!
  end

  def update
    if @message.content_type == 'input_email'
      @message.update!(submitted_email: contact_email)
      ContactIdentifyAction.new(
        contact: @contact,
        params: { email: contact_email, name: contact_name },
        retain_original_contact_name: true
      ).perform
    else
      @message.update!(message_update_params[:message])
    end
  rescue StandardError => e
    render json: { error: @contact.errors, message: e.message }.to_json, status: :internal_server_error
  end

  private

  def build_attachment
    return if params[:message][:attachments].blank?

    params[:message][:attachments].each do |uploaded_attachment|
      attachment = @message.attachments.new(
        account_id: @message.account_id,
        file: uploaded_attachment
      )

      attachment.file_type = helpers.file_type(uploaded_attachment&.content_type) if uploaded_attachment.is_a?(ActionDispatch::Http::UploadedFile)
    end
  end

  # Hiding the reply box does not stop requests reaching this endpoint, so the setting is
  # enforced here.
  def prevent_reply_to_resolved_conversation
    return unless conversation&.resolved?
    return if inbox.allow_messages_after_resolved

    render json: { error: I18n.t('errors.conversations.resolved') }, status: :forbidden
  end

  def enforce_anti_spam_limit
    return unless conversation.present? && ActiveModel::Type::Boolean.new.cast(inbox.anti_spam_enabled)

    max_messages = (inbox.anti_spam_max_messages.presence || 10).to_i.clamp(2, 100)
    window_seconds = (inbox.anti_spam_window_seconds.presence || 60).to_i.clamp(10, 600)
    cooldown_seconds = (inbox.anti_spam_cooldown_seconds.presence || 120).to_i.clamp(15, 3600)
    warning_msg = inbox.anti_spam_warning_message.presence ||
                  '⚠️ Você enviou muitas mensagens em sequência. Aguarde alguns instantes antes de enviar novas mensagens para não atrasar seu atendimento.'

    lock_key = "anti_spam_lock:conv:#{conversation.id}"
    last_human_agent_msg_at = conversation.messages.outgoing.where(sender_type: 'User', private: false).maximum(:created_at)

    locked_until_ts = $alfred.with { |conn| conn.get(lock_key) }&.to_i
    if locked_until_ts.present? && locked_until_ts > Time.current.to_i
      if last_human_agent_msg_at.present? && last_human_agent_msg_at.to_i > (locked_until_ts - cooldown_seconds)
        $alfred.with { |conn| conn.del(lock_key) }
      else
        remaining = locked_until_ts - Time.current.to_i
        render json: {
          error: warning_msg,
          anti_spam_locked: true,
          retry_after: remaining,
          locked_until: locked_until_ts
        }, status: :too_many_requests
        return
      end
    end

    window_start = [Time.current - window_seconds.seconds, last_human_agent_msg_at].compact.max
    recent_incoming_count = conversation.messages.incoming.where('created_at >= ?', window_start).count

    if recent_incoming_count >= max_messages - 1
      new_locked_until = (Time.current + cooldown_seconds.seconds).to_i
      $alfred.with { |conn| conn.setex(lock_key, cooldown_seconds, new_locked_until.to_s) }
    end

    return if recent_incoming_count < max_messages

    render json: {
      error: warning_msg,
      anti_spam_locked: true,
      retry_after: cooldown_seconds,
      locked_until: (Time.current + cooldown_seconds.seconds).to_i
    }, status: :too_many_requests
  end

  def set_conversation
    return if conversation.present?

    @conversation = create_conversation
    apply_labels if permitted_params[:labels].present?
  end

  def apply_labels
    valid_labels = inbox.account.labels.where(title: permitted_params[:labels]).pluck(:title)
    @conversation.update_labels(valid_labels) if valid_labels.present?
  end

  def message_finder_params
    {
      filter_internal_messages: true,
      before: permitted_params[:before],
      after: permitted_params[:after]
    }
  end

  def message_finder
    @message_finder ||= MessageFinder.new(conversation, message_finder_params)
  end

  def message_update_params
    params.permit(message: [{ submitted_values: [:name, :title, :value, { csat_survey_response: [:feedback_message, :rating] }] }])
  end

  def permitted_params
    # timestamp parameter is used in create conversation method
    # custom_attributes and labels are applied when a new conversation is created alongside the first message
    params.permit(
      :id, :before, :after, :website_token,
      contact: [:name, :email],
      message: [:content, :referer_url, :timestamp, :echo_id, :reply_to],
      custom_attributes: {},
      labels: []
    )
  end

  def set_message
    # `conversation.messages.find` would be simpler, but `conversation` is `conversations.last`,
    # which means a visitor with more than one open thread could not edit a message in any
    # but their most recent one. Scoping across all of the visitor's conversations keeps the
    # happy path correct for that future multi-conversation widget flow.
    @message = Message.where(conversation_id: conversations.select(:id)).find(permitted_params[:id])
  end
end
