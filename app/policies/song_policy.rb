class SongPolicy < ApplicationPolicy
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

  def attach_song_with_dam_ouchikaraoke?
    false
  end

  def detach_song_with_dam_ouchikaraoke?
    false
  end

  def attach_song_with_joysound_utasuki?
    false
  end

  def detach_song_with_joysound_utasuki?
    false
  end

  def attach_karaoke_delivery_models?
    false
  end

  def detach_karaoke_delivery_models?
    false
  end

  def edit_karaoke_delivery_models?
    false
  end

  def create_karaoke_delivery_models?
    false
  end

  def destroy_karaoke_delivery_models?
    false
  end

  def edit_original_songs?
    false
  end

  def create_original_songs?
    false
  end

  def destroy_original_songs?
    false
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
