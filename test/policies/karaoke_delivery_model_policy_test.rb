require 'test_helper'

class KaraokeDeliveryModelPolicyTest < ActiveSupport::TestCase
  test "permits base actions" do
    assert_policy_permits KaraokeDeliveryModelPolicy.new(nil, Object.new), :index?, :show?, :create?, :update?, :reorder?
  end

  test "inherits destroy denial" do
    assert_policy_forbids KaraokeDeliveryModelPolicy.new(nil, Object.new), :destroy?
  end

  test "scope resolves all records" do
    assert_scope_resolves_all KaraokeDeliveryModelPolicy::Scope
  end
end
