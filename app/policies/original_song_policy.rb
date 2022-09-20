class OriginalSongPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def attach_songs?
    false
  end

  def detach_songs?
    false
  end

  def edit_songs?
    false
  end

  def create_songs?
    false
  end

  def destroy_songs?
    false
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
