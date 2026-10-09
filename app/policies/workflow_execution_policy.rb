class WorkflowExecutionPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def retry_execution?
    @account_user.administrator?
  end

  def cancel?
    @account_user.administrator?
  end
end
