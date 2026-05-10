require 'test_helper'

class OriginalSongPolicyTest < ActiveSupport::TestCase
  test "permits read actions" do
    assert_policy_permits OriginalSongPolicy.new(nil, Object.new), :index?, :show?
  end

  test "inherits mutation denials" do
    assert_policy_forbids OriginalSongPolicy.new(nil, Object.new), :create?, :update?, :destroy?
  end

  test "forbids nested association actions" do
    assert_policy_forbids(
      OriginalSongPolicy.new(nil, Object.new),
      :attach_songs?,
      :detach_songs?,
      :edit_songs?,
      :create_songs?,
      :destroy_songs?
    )
  end

  test "scope resolves all records" do
    assert_scope_resolves_all OriginalSongPolicy::Scope
  end
end
