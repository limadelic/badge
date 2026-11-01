module Heading
  module_function

  FENCE = /^ {0,3}(?<fence>(?<c>[`~])\k<c>{2,})(?:(?<=~)|(?![^\n]*`))[^\n]*\n?.*?(?:^ {0,3}\k<fence>\k<c>*[ \t]*$|\z)/m

  def index(text)
    masked = text.gsub(FENCE) { |fenced| "\n" * fenced.count("\n") }
    masked.lines.index { |line| line.start_with?('# ') }
  end
end
