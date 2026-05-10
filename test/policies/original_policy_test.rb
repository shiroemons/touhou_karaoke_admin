require 'test_helper'

class OriginalPolicyTest < ActiveSupport::TestCase
  test "permits read actions" do
    assert_policy_permits OriginalPolicy.new(nil, Object.new), :index?, :show?
  end

  test "inherits mutation denials" do
    assert_policy_forbids OriginalPolicy.new(nil, Object.new), :create?, :update?, :destroy?
  end

  test "forbids nested association actions" do
    assert_policy_forbids(
      OriginalPolicy.new(nil, Object.new),
      :attach_original_songs?,
      :detach_original_songs?,
      :edit_original_songs?,
      :create_original_songs?,
      :destroy_original_songs?
    )
  end

  test "scope resolves all records" do
    assert_scope_resolves_all OriginalPolicy::Scope
  end
end
