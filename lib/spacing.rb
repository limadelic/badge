module Spacing
  module_function

  def join(head, markup, tail)
    head = head.rstrip
    tail = tail.sub(/\A(?:\r?\n)+/, '')
    tail = '' if tail.strip.empty?
    [head.empty? ? nil : "#{head}\n\n", markup, tail.empty? ? nil : "\n#{tail}"].compact.join
  end

  def close(head, tail)
    return tail.lstrip if head.strip.empty?
    return "#{head.rstrip}\n" if tail.strip.empty?

    gap = [head[/\s*\z/].count("\n"), tail[/\A\s*/].count("\n")].max
    "#{head.rstrip}#{"\n" * gap}#{tail.lstrip}"
  end
end
