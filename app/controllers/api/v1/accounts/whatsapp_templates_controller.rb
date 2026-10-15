# frozen_string_literal: true

class Api::V1::Accounts::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_template, only: [:show, :update, :destroy, :approve, :submit_review, :reject]
  before_action :check_authorization

  def sync
    result = Whatsapp::ImportTemplatesService.new(Current.account).perform
    if result[:success]
      render json: result.except(:success)
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def index
    @templates = visible_templates.with_attached_header_media.order(created_at: :desc)
    
    stats = {
      total: @templates.count,
      approved: @templates.approved.count,
      pending: @templates.pending.count,
      rejected: @templates.rejected.count
    }

    render json: {
      templates: @templates,
      stats: stats
    }
  end

  def show
    render json: @template
  end

  def create
    @template = Current.account.whatsapp_templates.new
    return unless assign_template(@template)
    return unless meta_valid?(@template, require_examples: @template.status == 'PENDING')
    return if @template.status == 'PENDING' && !submit_to_meta(@template)

    if @template.save
      render json: @template, status: :created
    else
      render json: { error: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    return unless assign_template(@template)
    return unless meta_valid?(@template, require_examples: @template.status == 'PENDING')

    if @template.save
      render json: @template
    else
      render json: { error: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy!
    head :no_content
  end

  def approve
    @template.approve!
    render json: @template
  end

  def submit_review
    return unless meta_valid?(@template, require_examples: true)
    return unless submit_to_meta(@template)

    @template.save!
    render json: @template
  end

  def reject
    @template.reject!(params[:reason])
    render json: @template
  end

  private

  def fetch_template
    @template = visible_templates.find(params[:id])
  end

  def visible_templates
    Current.account.whatsapp_templates.left_joins(:inbox).where('inboxes.id IS NULL OR inboxes.legacy = FALSE')
  end

  def meta_valid?(template, require_examples:)
    builder = Whatsapp::MetaTemplateBuilder.new(template, require_examples: require_examples)
    return true if builder.valid?

    render json: { error: builder.errors }, status: :unprocessable_entity
    false
  end

  def submit_to_meta(template)
    result = Whatsapp::SubmitMessageTemplateService.new(template).perform
    if result[:success]
      template.meta_template_id = result[:template_id]
      template.status = result[:status] || 'PENDING'
      return true
    end

    render json: { error: result[:error] }, status: :unprocessable_entity
    false
  end

  def assign_template(record)
    record.assign_attributes(template_params)
    return false unless official_inbox?(record)

    apply_stored_header_url(record)
    true
  end

  def official_inbox?(record)
    inbox = Current.account.inboxes.find_by(id: record.inbox_id)
    channel = inbox&.channel
    if channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud' && !inbox.legacy
      record.inbox = inbox
      return true
    end

    render json: { error: 'Selecione uma caixa da API oficial do WhatsApp.' }, status: :unprocessable_entity
    false
  end

  def apply_stored_header_url(record)
    return unless record.header_media.attached?
    return unless WhatsappTemplate::HEADER_MEDIA_TYPES.key?(record.header_type)

    record.header_content = url_for(record.header_media.blob)
  end

  def template_params
    params.require(:whatsapp_template).permit(
      :name,
      :category,
      :language,
      :status,
      :header_type,
      :header_content,
      :header_media,
      :body,
      :footer,
      :rejection_reason,
      :inbox_id,
      buttons: [:type, :text, :url, :phone_number],
      variables: [:key, :name, :component, :sample_value]
    )
  end
end
