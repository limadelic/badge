module Spacing
  module_function

  def join(head, markup, tail)
    head = head.rstrip
    tail = tail.sub(/\A(?:\r?\n)+/, '')
    [head.empty? ? nil : "#{head}\n\n", markup, tail.empty? ? nil : "\n#{tail}"].compact.join
  end
end
