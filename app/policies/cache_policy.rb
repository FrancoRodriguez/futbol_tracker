# app/policies/cache_policy.rb
class CachePolicy < ApplicationPolicy
  def clear? = admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
