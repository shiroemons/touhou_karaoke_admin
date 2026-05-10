require 'test_helper'

class DamSongPolicyTest < ActiveSupport::TestCase
  test "permits read and operation actions" do
    assert_policy_permits DamSongPolicy.new(nil, Object.new), :index?, :show?, :act_on?
  end

  test "inherits mutation denials" do
    assert_policy_forbids DamSongPolicy.new(nil, Object.new), :create?, :update?, :destroy?
  end

  test "scope resolves all records" do
    assert_scope_resolves_all DamSongPolicy::Scope
  end
end
