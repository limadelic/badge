module Heading
  module_function

  OPENER = /^ {0,3}(?<fence>(?<marker>[`~])\k<marker>{2,})(?:(?<=~)|(?![^\n]*`))[^\n]*\n?/
  FENCE = /#{OPENER}.*?(?:^ {0,3}\k<fence>\k<marker>*[ \t]*\r?$|\z)/m

  def index(text)
    masked = text.gsub(FENCE) { |fenced| "\n" * fenced.count("\n") }
    masked.lines.index { |line| line.start_with?('# ') }
  end
end
