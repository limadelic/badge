require 'minitest/autorun'
require 'body'
require_relative 'body_helpers'

class BodyStripTest < Minitest::Test
  include BodyHelpers

  def strip_event(extra = {})
    env({ 'TARGET' => 'strip', 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7' }.merge(extra))
  end

  def test_strip_text_removes_block
    assert_equal "a\n\nb\n", Body.strip("a<!-- badges-start -->\nx\n<!-- badges-end -->\nb")
  end

  def test_removes_block_and_keeps_text
    gh = FakeGh.new(body: "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\nBottom")
    Body.run(strip_event, gh)
    assert_equal "Top\n\nBottom\n", gh.patched
  end

  def test_strip_keeps_one_blank_line_around_text
    assert_equal "Top\n\nBottom\n", Body.strip("Top\n\n#{BLOCK_7}\n\nBottom")
  end

  def test_strip_never_keeps_more_than_one_blank_line
    assert_equal "Top\n\nBottom\n", Body.strip("Top\n\n\n#{BLOCK_7}\n\n\nBottom\n")
  end

  def test_strip_crlf_gives_lf_only
    assert_equal "Top\n\nBottom\n", Body.strip("Top\r\n\r\n#{BLOCK_7.gsub("\n", "\r\n")}\r\n\r\nBottom\r\n")
  end

  def test_strip_at_end_of_file_keeps_one_newline
    assert_equal "# badge\n", Body.strip("# badge\n\n#{BLOCK_7}\n")
  end

  def test_round_trip_between_text
    markup = Body.block(env, 'main/', false)
    assert_equal "Top\n\nBottom\n", Body.strip(Spacing.join('Top', markup, 'Bottom'))
  end

  def test_removes_every_block
    body = "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\n" \
           "Middle\n<!-- badges-start -->\nold2\n<!-- badges-end -->\nBottom"
    gh = FakeGh.new(body: body)
    Body.run(strip_event, gh)
    assert_equal "Top\n\nMiddle\n\nBottom\n", gh.patched
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
