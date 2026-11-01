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
    assert_equal "Top\n\n#{BLOCK_7}\n\nMiddle\nBottom", gh.patched
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
    assert_equal "Top\n\n#{BLOCK_7}\n\nBottom", gh.patched
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

  def test_block_has_blank_line_after_start_and_before_end
    markup = Body.block(env, 'main/', false)
    assert markup.start_with?("#{Body::START}\n\n[![cukes]")
    assert_includes markup, "\n\n#{Body::STOP}\n"
  end

  def test_old_block_without_blank_lines_is_replaced
    old = BLOCK_7.gsub("\n\n", "\n")
    gh = FakeGh.new(body: "Top\n#{old}\nBottom")
    Body.run(pr_event, gh)
    assert_equal "Top\n\n#{BLOCK_7}\n\nBottom", gh.patched
  end

  def test_place_leaves_one_blank_line_before_text_after_end
    markup = Body.block(env, 'main/', false)
    text = "# badge\n\n<!-- badges-start -->\nold\n<!-- badges-end -->\nSome text\n"
    assert_equal "# badge\n\n#{markup}\nSome text\n", Body.place(text, markup)
  end

  def test_place_at_end_of_file_adds_no_blank_line
    markup = Body.block(env, 'main/', false)
    text = "# badge\n\n#{markup}"
    assert_equal text, Body.place(text, markup)
  end

  def test_insert_leaves_one_blank_line_before_text
    markup = Body.block(env, 'main/', false)
    assert_equal "# badge\n\n#{markup}\nSome text\n", Body.insert("# badge\nSome text\n", markup)
  end

  def test_second_run_of_place_and_insert_changes_nothing
    markup = Body.block(env, 'main/', false)
    placed = Body.place("# badge\n\n<!-- badges-start -->\nold\n<!-- badges-end -->\nSome text\n", markup)
    assert_equal placed, Body.place(placed, markup)
    inserted = Body.insert("# badge\nSome text\n", markup)
    assert_equal inserted, Body.place(inserted, markup)
  end

  def test_second_run_changes_nothing
    gh = FakeGh.new(body: "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\nBottom")
    Body.run(pr_event, gh)
    again = FakeGh.new(body: gh.patched)
    Body.run(pr_event, again)
    assert_nil again.patched
  end

  def test_main_push_never_patches_pr
    gh = FakeGh.new(body: 'Hi', pulls: '[{"number":12}]')
    Body.run(env('BRANCH' => 'main'), gh)
    assert_nil gh.patched
  end
end
