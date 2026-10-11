class WorkflowPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def publish?
    @account_user.administrator?
  end

  def pause?
    @account_user.administrator?
  end

  def activate?
    @account_user.administrator?
  end

  def duplicate?
    @account_user.administrator?
  end

  def executions?
    @account_user.administrator?
  end

  def test_http?
    @account_user.administrator?
  end

  def webhook_trigger?
    @account_user.administrator?
  end

  def upsert_webhook_trigger?
    @account_user.administrator?
  end

  def test_webhook_trigger?
    @account_user.administrator?
  end

  def show_flow_test?
    @account_user.administrator?
  end

  def start_flow_test?
    @account_user.administrator?
  end

  def reply_flow_test?
    @account_user.administrator?
  end

  def timeout_flow_test?
    @account_user.administrator?
  end
end
