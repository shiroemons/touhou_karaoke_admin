require 'test_helper'

class JoysoundMusicPostPolicyTest < ActiveSupport::TestCase
  test "permits read and operation actions" do
    assert_policy_permits JoysoundMusicPostPolicy.new(nil, Object.new), :index?, :show?, :update?, :act_on?
  end

  test "inherits mutation denials" do
    assert_policy_forbids JoysoundMusicPostPolicy.new(nil, Object.new), :create?, :destroy?
  end

  test "scope resolves all records" do
    assert_scope_resolves_all JoysoundMusicPostPolicy::Scope
  end
end
