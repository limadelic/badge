require 'minitest/autorun'
require 'body'
require_relative 'body_helpers'

class BodyBlockTest < Minitest::Test
  include BodyHelpers

  def test_all_blocks_become_one_at_first_place
    body = "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\n" \
           "Middle\n<!-- badges-start -->\nold2\n<!-- badges-end -->\nBottom"
    gh = FakeGh.new(body: body)
    Body.run(pr_event, gh)
    assert_equal "Top\n#{BLOCK_7}\nMiddle\nBottom", gh.patched
  end

  def test_orphan_markers_are_removed
    gh = FakeGh.new(body: "<!-- badges-end -->\nText\n<!-- badges-start -->")
    Body.run(pr_event, gh)
    assert_equal "#{BLOCK_7}\n\nText\n", gh.patched
  end

  def test_only_missing_patches_orphan_marker
    gh = FakeGh.new(body: "<!-- badges-start -->\nold")
    Body.run(pr_event('ONLY_MISSING' => 'true'), gh)
    refute_nil gh.patched
  end

  def test_crlf_block_is_replaced
    gh = FakeGh.new(body: "Top\r\n<!-- badges-start -->\r\nold\r\n<!-- badges-end -->\r\nBottom")
    Body.run(pr_event, gh)
    assert_equal "Top\r\n#{BLOCK_7}\nBottom", gh.patched
  end

  def test_only_missing_skips_crlf_block
    gh = FakeGh.new(body: "<!-- badges-start -->\r\nold\r\n<!-- badges-end -->\r\n")
    Body.run(pr_event('ONLY_MISSING' => 'true'), gh)
    assert_nil gh.patched
  end

  def test_label_and_link_are_percent_encoded
    markup = Body.block(env('BADGES' => 'cuke s=my file.json'), 'main/', false)
    assert_includes markup, '(https://limadelic.github.io/badge/main/cuke%20s/my%20file.json)'
  end

  def test_main_push_never_patches_pr
    gh = FakeGh.new(body: 'Hi', pulls: '[{"number":12}]')
    Body.run(env('BRANCH' => 'main'), gh)
    assert_nil gh.patched
  end
end
