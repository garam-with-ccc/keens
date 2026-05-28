require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email to lowercase and strips whitespace" do
    user = User.create!(email: "  Writer@Example.COM  ")
    assert_equal "writer@example.com", user.email
  end

  test "rejects duplicate emails case-insensitively" do
    User.create!(email: "writer@example.com")
    dup = User.new(email: "WRITER@example.com")
    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "rejects invalid emails" do
    user = User.new(email: "not-an-email")
    assert_not user.valid?
  end

  test "rejects unknown roles" do
    user = User.new(email: "x@example.com", role: "admin")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "defaults to writer role" do
    user = User.create!(email: "w@example.com")
    assert_equal "writer", user.role
    assert user.writer?
    assert_not user.organizer?
  end

  test "accepts organizer and observer roles" do
    o = User.create!(email: "o@example.com", role: "organizer")
    assert o.organizer?
    obs = User.create!(email: "obs@example.com", role: "observer")
    assert_equal "observer", obs.role
  end
end
