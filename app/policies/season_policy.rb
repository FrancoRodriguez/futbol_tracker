class SeasonPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
