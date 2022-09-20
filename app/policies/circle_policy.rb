class CirclePolicy < ApplicationPolicy
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

  def attach_display_artists?
    false
  end

  def detach_display_artists?
    false
  end

  def edit_display_artists?
    false
  end

  def create_display_artists?
    false
  end

  def destroy_display_artists?
    false
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
