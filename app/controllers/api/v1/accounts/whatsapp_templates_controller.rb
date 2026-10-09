# frozen_string_literal: true

class Api::V1::Accounts::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_template, only: [:show, :update, :destroy, :approve, :submit_review, :reject]

  def index
    @templates = Current.account.whatsapp_templates.order(created_at: :desc)
    
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
    @template = Current.account.whatsapp_templates.new(template_params)

    if @template.save
      render json: @template, status: :created
    else
      render json: { error: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @template.update(template_params)
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
    @template.submit_review!
    render json: @template
  end

  def reject
    @template.reject!(params[:reason])
    render json: @template
  end

  private

  def fetch_template
    @template = Current.account.whatsapp_templates.find(params[:id])
  end

  def template_params
    params.require(:whatsapp_template).permit(
      :name,
      :category,
      :language,
      :status,
      :header_type,
      :header_content,
      :body,
      :footer,
      :rejection_reason,
      :inbox_id,
      buttons: [:type, :text, :url, :phone_number],
      variables: [:key, :name, :sample_value]
    )
  end
end
