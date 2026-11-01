require 'json'

module Cukes
  class Error < StandardError; end

  module_function

  def summary(path)
    scenarios = scenarios(features(path))
    passed = scenarios.count { |sc| ok?(sc) }
    total = scenarios.length
    { 'message' => "#{passed}/#{total}", 'color' => color(total.positive? && passed == total) }
  end

  def features(path)
    list = JSON.parse(File.read(path))
    raise Error, "not a cucumber json array: #{path}" unless list.is_a?(Array)

    list
  rescue Errno::ENOENT
    raise Error, "no such file: #{path}"
  rescue JSON::ParserError
    raise Error, "bad json: #{path}"
  end

  def scenarios(features)
    features.flat_map { |f| f.fetch('elements', []) }.select { |el| el['type'] == 'scenario' }
  end

  def ok?(scenario)
    scenario.fetch('steps', []).all? { |s| s.dig('result', 'status') == 'passed' }
  end

  def color(pass)
    pass ? 'brightgreen' : 'red'
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    Cukes.summary(ARGV.fetch(0)).each { |key, value| puts "#{key}=#{value}" }
  rescue Cukes::Error => e
    warn "cukes: #{e.message}"
    exit 1
  end
end
