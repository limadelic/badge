require 'minitest/autorun'
require 'heading'

class HeadingTest < Minitest::Test
  def test_backtick_fence
    assert_equal 4, Heading.index("```sh\n# install\n```\n\n# Project\n\nText\n")
  end

  def test_tilde_fence
    assert_equal 4, Heading.index("~~~sh\n# install\n~~~\n\n# Project\n\nText\n")
  end

  def test_four_backtick_fence_with_inner_triple
    text = "````md\n```\n# inner\n```\n````\n\n# Project\n\nText\n"

    assert_equal 6, Heading.index(text)
  end

  def test_no_fence
    assert_equal 2, Heading.index("Intro\n\n# Project\n\nText\n")
  end
end
