class WhatsappTemplatePolicy < ApplicationPolicy
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

  def approve?
    @account_user.administrator?
  end

  def submit_review?
    @account_user.administrator?
  end

  def reject?
    @account_user.administrator?
  end
end
