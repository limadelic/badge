class FakeGh
  attr_reader :calls, :patched

  def initialize(body: '', pulls: '[]')
    @body = body
    @pulls = pulls
    @calls = []
    @patched = nil
  end

  def call(*args)
    @calls << args
    return "#{@pulls}\n" if args.first.start_with?('repos/limadelic/badge/pulls?')
    return "#{@body}\n" if args.include?('--jq')

    @patched = File.read(args.last.delete_prefix('body=@'))
    ''
  end
end

BLOCK_7 = [
  '<!-- badges-start -->',
  '',
  '[![cukes](https://img.shields.io/endpoint?url=https%3A%2F%2Flimadelic.github.io%2Fbadge%2F7%2Fcukes%2F' \
  'badge.json&cacheSeconds=60&v=42)](https://limadelic.github.io/badge/7/cukes/cucumber.json)',
  '',
  '<!-- badges-end -->'
].join("\n")

MAIN_BLOCK = [
  '<!-- badges-start -->',
  '',
  '[![cukes](https://img.shields.io/endpoint?url=https%3A%2F%2Flimadelic.github.io%2Fbadge%2Fmain%2Fcukes%2F' \
  'badge.json&cacheSeconds=60)](https://limadelic.github.io/badge/main/cukes/cucumber.json)',
  '',
  '<!-- badges-end -->'
].join("\n")

module BodyHelpers
  def env(extra = {})
    { 'REPO' => 'limadelic/badge', 'BRANCH' => 'unit', 'EVENT_NAME' => 'push', 'TARGET' => 'pr',
      'BADGES' => 'cukes=cucumber.json', 'RUN_ID' => '42', 'ONLY_MISSING' => 'false', 'PR_NUMBER' => '' }.merge(extra)
  end

  def pr_event(extra = {})
    env({ 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7' }.merge(extra))
  end
end
