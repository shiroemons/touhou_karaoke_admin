class DisplayArtistPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def act_on?
    true
  end

  def edit_circles?
    false
  end

  def create_circles?
    false
  end

  def destroy_circles?
    false
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

  def attach_dam_songs?
    false
  end

  def detach_dam_songs?
    false
  end

  def edit_dam_songs?
    false
  end

  def create_dam_songs?
    false
  end

  def destroy_dam_songs?
    false
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
