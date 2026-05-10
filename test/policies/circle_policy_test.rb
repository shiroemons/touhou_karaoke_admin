require 'test_helper'

class CirclePolicyTest < ActiveSupport::TestCase
  test "permits base actions" do
    assert_policy_permits CirclePolicy.new(nil, Object.new), :index?, :show?, :create?, :update?
  end

  test "forbids nested association actions" do
    assert_policy_forbids(
      CirclePolicy.new(nil, Object.new),
      :attach_display_artists?,
      :detach_display_artists?,
      :edit_display_artists?,
      :create_display_artists?,
      :destroy_display_artists?,
      :attach_songs?,
      :detach_songs?,
      :edit_songs?,
      :create_songs?,
      :destroy_songs?
    )
  end

  test "scope resolves all records" do
    assert_scope_resolves_all CirclePolicy::Scope
  end
end
