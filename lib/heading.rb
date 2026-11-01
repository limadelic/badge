module Heading
  module_function

  FENCE = /^(`{3,}|~{3,}).*?(?:^\1[^\n]*|\z)/m

  def index(text)
    masked = text.gsub(FENCE) { |fenced| "\n" * fenced.count("\n") }
    masked.lines.index { |line| line.start_with?('# ') }
  end
end
