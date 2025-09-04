# app/policies/season_policy.rb
class SeasonPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end

  def index?   = user.present?
  def show?    = user.present?
  def create?     = user.present?
  def new?        = create?
  def update?     = user.present?
  def edit?       = update?
  def destroy?    = user.present?
  def activate?   = user.present?
  def deactivate? = user.present?
end
