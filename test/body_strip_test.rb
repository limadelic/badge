require 'minitest/autorun'
require 'body'
require_relative 'body_helpers'

class BodyStripTest < Minitest::Test
  include BodyHelpers

  def strip_event(extra = {})
    env({ 'TARGET' => 'strip', 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7' }.merge(extra))
  end

  def test_strip_text_removes_block
    assert_equal 'ab', Body.strip("a<!-- badges-start -->\nx\n<!-- badges-end -->\nb")
  end

  def test_removes_block_and_keeps_text
    gh = FakeGh.new(body: "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\nBottom")
    Body.run(strip_event, gh)
    assert_equal "Top\nBottom", gh.patched
  end

  def test_removes_every_block
    body = "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\n" \
           "Middle\n<!-- badges-start -->\nold2\n<!-- badges-end -->\nBottom"
    gh = FakeGh.new(body: body)
    Body.run(strip_event, gh)
    assert_equal "Top\nMiddle\nBottom", gh.patched
  end

  def test_removes_orphan_markers
    gh = FakeGh.new(body: "<!-- badges-end -->\nText\n<!-- badges-start -->")
    Body.run(strip_event, gh)
    assert_equal "Text\n", gh.patched
  end

  def test_body_without_block_is_not_patched
    gh = FakeGh.new(body: 'Hi')
    Body.run(strip_event, gh)
    assert_nil gh.patched
  end

  def test_patch_goes_to_pr_body_endpoint
    gh = FakeGh.new(body: "<!-- badges-start -->\nold\n<!-- badges-end -->")
    Body.run(strip_event, gh)
    assert_equal ['repos/limadelic/badge/pulls/7', '-X', 'PATCH'], gh.calls.last.first(3)
  end
end
