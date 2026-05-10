require 'test_helper'

class SongPolicyTest < ActiveSupport::TestCase
  test "permits read and operation actions" do
    assert_policy_permits SongPolicy.new(nil, Object.new), :index?, :show?, :update?, :act_on?, :upload_tsv_file?
  end

  test "inherits mutation denials" do
    assert_policy_forbids SongPolicy.new(nil, Object.new), :create?, :destroy?
  end

  test "forbids nested association actions" do
    assert_policy_forbids(
      SongPolicy.new(nil, Object.new),
      :attach_song_with_dam_ouchikaraoke?,
      :detach_song_with_dam_ouchikaraoke?,
      :attach_song_with_joysound_utasuki?,
      :detach_song_with_joysound_utasuki?,
      :attach_karaoke_delivery_models?,
      :detach_karaoke_delivery_models?,
      :edit_karaoke_delivery_models?,
      :create_karaoke_delivery_models?,
      :destroy_karaoke_delivery_models?,
      :edit_original_songs?,
      :create_original_songs?,
      :destroy_original_songs?
    )
  end

  test "scope resolves all records" do
    assert_scope_resolves_all SongPolicy::Scope
  end
end
