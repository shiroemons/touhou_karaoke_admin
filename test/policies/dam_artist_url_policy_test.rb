require 'test_helper'

class DamArtistUrlPolicyTest < ActiveSupport::TestCase
  test "permits base actions" do
    assert_policy_permits DamArtistUrlPolicy.new(nil, Object.new), :index?, :show?, :create?, :update?
  end

  test "inherits destroy denial" do
    assert_policy_forbids DamArtistUrlPolicy.new(nil, Object.new), :destroy?
  end

  test "scope resolves all records" do
    assert_scope_resolves_all DamArtistUrlPolicy::Scope
  end
end
