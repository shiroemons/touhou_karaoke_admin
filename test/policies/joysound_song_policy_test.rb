require 'test_helper'

class JoysoundSongPolicyTest < ActiveSupport::TestCase
  test "permits read and operation actions" do
    assert_policy_permits JoysoundSongPolicy.new(nil, Object.new), :index?, :show?, :act_on?
  end

  test "inherits mutation denials" do
    assert_policy_forbids JoysoundSongPolicy.new(nil, Object.new), :create?, :update?, :destroy?
  end

  test "scope resolves all records" do
    assert_scope_resolves_all JoysoundSongPolicy::Scope
  end
end
