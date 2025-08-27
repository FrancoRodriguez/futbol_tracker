class ParticipationPolicy < ApplicationPolicy
  def new?         = create?
  def create?      = admin?
  def edit?        = update?
  def update?      = admin?
  def destroy?     = admin?
  def bulk_create? = admin?

  class Scope < Scope
    def resolve = scope.all
  end
end
