require 'json'
require 'open3'
require 'uri'

module Prefix
  class Error < StandardError; end

  module_function

  def compute(env, api = method(:gh))
    return "#{env.fetch('PR_NUMBER')}/" if env.fetch('EVENT_NAME', '').start_with?('pull_request')

    branch = env.fetch('BRANCH')
    return '' if branch == 'main'

    "#{open_pr(env, api) || safe_branch(branch)}/"
  end

  def safe_branch(branch)
    branch.tr('/', '-')
  end

  def open_pr(env, api)
    pulls = parse(api.call(pulls_path(env)))
    pulls.first&.fetch('number')&.to_s
  end

  def parse(out)
    pulls = JSON.parse(out)
    raise Error, 'gh api returned bad JSON' unless pulls.is_a?(Array)

    pulls
  rescue JSON::ParserError
    raise Error, 'gh api returned bad JSON'
  end

  def pulls_path(env)
    repo = env.fetch('REPO')
    owner = repo.split('/').first
    query = URI.encode_www_form('state' => 'open', 'head' => "#{owner}:#{env.fetch('BRANCH')}", 'per_page' => 100)
    "repos/#{repo}/pulls?#{query}"
  end

  def gh(path)
    out, err, status = Open3.capture3('gh', 'api', path)
    raise Error, "gh api #{path} failed: #{err.strip}" unless status.success?

    out
  rescue Errno::ENOENT
    raise Error, 'gh not found on PATH'
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    puts Prefix.compute(ENV)
  rescue Prefix::Error => e
    warn "prefix: #{e.message}"
    exit 1
  end
end
