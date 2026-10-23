class Api::V1::Accounts::SystemUpdatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_or_super_admin!

  def check
    data = SystemUpdateService.check_updates(
      force_refresh: ActiveModel::Type::Boolean.new.cast(params[:refresh])
    )
    render json: data
  end

  def apply
    result = SystemUpdateService.trigger_update!(
      user: Current.user,
      target_sha: params[:target_sha],
      force_window: params[:force_window]
    )

    if result[:ok]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  private

  def check_admin_or_super_admin!
    return if Current.user&.type == 'SuperAdmin'
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end
end
