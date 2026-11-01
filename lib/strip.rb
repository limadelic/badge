require_relative 'spacing'

module Strip
  module_function

  def call(text, block, marker)
    before, found, after = text.partition(block)
    return text.gsub(marker, '') if found.empty?

    Spacing.close(before.gsub(marker, ''), call(after, block, marker))
  end
end
