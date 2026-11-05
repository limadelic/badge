require 'minitest/autorun'
require 'body'
require_relative 'body_helpers'

class BodySpacingTest < Minitest::Test
  include BodyHelpers

  def test_pr_whitespace_only_body_gets_markup_only
    gh = FakeGh.new(body: '   ')
    Body.run(pr_event, gh)
    assert_equal "#{BLOCK_7}\n", gh.patched
  end

  def test_pr_body_keeps_one_blank_line_before_text
    gh = FakeGh.new(body: "\n\nSome text\n")
    Body.run(pr_event, gh)
    assert_equal "#{BLOCK_7}\n\nSome text\n", gh.patched
  end

  def test_pr_orphan_end_keeps_one_blank_line_around_text
    gh = FakeGh.new(body: "Top\n\n<!-- badges-end -->\n\n\nBottom\n")
    Body.run(pr_event, gh)
    assert_equal "#{BLOCK_7}\n\nTop\n\nBottom\n", gh.patched
  end

  def test_place_treats_whitespace_only_head_line_as_blank
    markup = Body.block(env, 'main/')
    text = "# badge\n   \n<!-- badges-start -->\nold\n<!-- badges-end -->\nSome text\n"
    assert_equal "# badge\n\n#{markup}\nSome text\n", Body.place(text, markup)
  end

  def test_place_treats_whitespace_only_tail_line_as_blank
    markup = Body.block(env, 'main/')
    text = "# badge\n\n<!-- badges-start -->\nold\n<!-- badges-end -->\n   \nSome text\n"
    assert_equal "# badge\n\n#{markup}\nSome text\n", Body.place(text, markup)
  end
end
