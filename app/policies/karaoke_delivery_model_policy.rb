class KaraokeDeliveryModelPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def reorder?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
