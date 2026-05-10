require 'test_helper'

class DisplayArtistPolicyTest < ActiveSupport::TestCase
  Record = Struct.new(:songs)

  test "permits read and operation actions" do
    assert_policy_permits DisplayArtistPolicy.new(nil, Record.new([])), :index?, :show?, :update?, :act_on?
  end

  test "allows destroy only when no songs are attached" do
    assert DisplayArtistPolicy.new(nil, Record.new([])).destroy?
    assert_not DisplayArtistPolicy.new(nil, Record.new([Object.new])).destroy?
  end

  test "inherits create denial" do
    assert_policy_forbids DisplayArtistPolicy.new(nil, Record.new([])), :create?
  end

  test "forbids nested association actions" do
    assert_policy_forbids(
      DisplayArtistPolicy.new(nil, Record.new([])),
      :edit_circles?,
      :create_circles?,
      :destroy_circles?,
      :attach_songs?,
      :detach_songs?,
      :edit_songs?,
      :create_songs?,
      :destroy_songs?,
      :attach_dam_songs?,
      :detach_dam_songs?,
      :edit_dam_songs?,
      :create_dam_songs?,
      :destroy_dam_songs?
    )
  end

  test "scope resolves all records" do
    assert_scope_resolves_all DisplayArtistPolicy::Scope
  end
end
