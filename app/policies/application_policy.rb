class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  def admin?
    user.present?
  end

  def owner?
    record.respond_to?(:user_id) && user && record.user_id == user.id
  end

  def owner_or_admin?
    admin? || owner?
  end

  def index?   = false
  def show?    = true
  def create?  = admin?
  def new?     = create?
  def update?  = admin?
  def edit?    = update?
  def destroy? = admin?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end
