require_relative 'spacing'

module Strip
  module_function

  def call(text, block, marker)
    text = text.gsub("\r\n", "\n")
    before, found, after = text.partition(block)
    return Spacing.join(*text.split(marker)) if found.empty?

    Spacing.join(*before.split(marker), call(after, block, marker))
  end
end
