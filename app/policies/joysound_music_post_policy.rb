class JoysoundMusicPostPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def update?
    true
  end

  def act_on?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
