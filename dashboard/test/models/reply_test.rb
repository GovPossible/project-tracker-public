require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  test "valid reply" do
    reply = replies(:unread_email)
    assert reply.valid?
  end

  test "requires channel" do
    reply = Reply.new(project: projects(:waiting_input), body: "test", received_at: Time.current)
    assert_not reply.valid?
    assert_includes reply.errors[:channel], "can't be blank"
  end

  test "requires body or images" do
    reply = Reply.new(project: projects(:waiting_input), channel: :email, body: nil, image_urls: [], received_at: Time.current)
    assert_not reply.valid?
    assert_includes reply.errors[:base], "must include a body or at least one image"
  end

  test "valid with image_urls and no body" do
    reply = Reply.new(project: projects(:waiting_input), channel: :email, body: nil, image_urls: ["https://example.com/img.png"], received_at: Time.current)
    assert reply.valid?
  end

  test "unread scope" do
    unread = Reply.unread
    assert_includes unread, replies(:unread_email)
    assert_not_includes unread, replies(:read_sms)
  end

  test "dashboard channel is valid" do
    reply = Reply.new(project: projects(:waiting_input), channel: :dashboard, body: "test", received_at: Time.current)
    assert reply.valid?
    assert_equal "dashboard", reply.channel
  end

  test "github channel is valid" do
    reply = Reply.new(project: projects(:waiting_input), channel: :github, body: "test", received_at: Time.current)
    assert reply.valid?
    assert_equal "github", reply.channel
  end

  test "mark_read changes read to true" do
    reply = replies(:unread_email)
    assert_not reply.read
    reply.mark_read!
    assert reply.read
  end
end
