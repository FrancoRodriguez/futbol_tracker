class PlayerPolicy < ApplicationPolicy
  def show? = true
  def edit?    = update?
  def update?  = owner_or_admin?
  def destroy? = admin?

  class Scope < Scope
    def resolve
      scope.all # o filtra si lo necesitas
    end
  end
end
