# app/policies/match_policy.rb
class MatchPolicy < ApplicationPolicy
  def show?       = true
  def index?      = true
  def create?     = admin?
  def new?        = create?
  def update?     = admin?
  def edit?       = update?
  def destroy?    = admin?
  def autobalance? = admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
