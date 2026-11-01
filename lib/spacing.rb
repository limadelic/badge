module Spacing
  module_function

  def join(*pieces)
    text = pieces.map { |piece| clean(piece) }.reject(&:empty?).join("\n\n")
    text.empty? ? '' : "#{text}\n"
  end

  def clean(piece)
    piece.gsub("\r\n", "\n").sub(/\A(?:[ \t]*\n)+/, '').rstrip
  end
end
