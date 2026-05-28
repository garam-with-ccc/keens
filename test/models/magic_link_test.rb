require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "writer@example.com")
  end

  test "issue! returns the record and a plaintext token; only the digest is persisted" do
    record, token = MagicLink.issue!(user: @user)

    assert_kind_of MagicLink, record
    assert token.is_a?(String) && token.length >= 32
    assert_not_equal token, record.token_digest
    assert_equal OpenSSL::Digest::SHA256.hexdigest(token), record.token_digest
  end

  test "find_live_by_token returns a live record for the correct plaintext only" do
    _record, token = MagicLink.issue!(user: @user)
    assert MagicLink.find_live_by_token(token).present?
    assert_nil MagicLink.find_live_by_token("not-the-real-token")
    assert_nil MagicLink.find_live_by_token(nil)
    assert_nil MagicLink.find_live_by_token("")
  end

  test "find_live_by_token returns nil after consumption (single-use)" do
    record, token = MagicLink.issue!(user: @user)
    record.consume!
    assert_nil MagicLink.find_live_by_token(token)
  end

  test "find_live_by_token returns nil after expiry (time-limited)" do
    _record, token = MagicLink.issue!(user: @user, lifetime: 1.minute)
    travel 2.minutes do
      assert_nil MagicLink.find_live_by_token(token)
    end
  end
end
