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

  def test_closer_cannot_carry_info_string
    assert_equal 5, Heading.index("```\n```python\n# not heading\n```\n\n# Project\n\nText\n")
  end

  def test_closer_with_trailing_text_does_not_close
    assert_nil Heading.index("```\n# x\n```foo\n\n# Project\n")
  end

  def test_fence_indented_up_to_three_spaces
    assert_equal 4, Heading.index("  ```sh\n# install\n  ```\n\n# Project\n")
    assert_equal 4, Heading.index("   ```sh\n# install\n   ```\n\n# Project\n")
  end

  def test_four_space_indent_is_not_a_fence
    assert_equal 1, Heading.index("    ```\n# not fence\n    ```\n\n# Project\n")
  end

  def test_backtick_info_string_cannot_hold_backtick
    assert_equal 2, Heading.index("```x``` is inline\n\n# Project\n")
  end
end
