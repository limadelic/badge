require 'fileutils'
require 'json'
require 'open3'
require 'uri'

module Prefix
  class Error < StandardError; end

  module_function

  def compute(env, api = method(:gh))
    number = pr_number(env, api)
    return "#{number}/" if number

    branch = env.fetch('BRANCH')
    branch == 'main' ? 'main/' : "#{safe_branch(branch)}/"
  end

  def pr_number(env, api = method(:gh))
    return env.fetch('PR_NUMBER') if pull_request?(env)
    return if env.fetch('BRANCH') == 'main'

    open_pr(env, api)
  end

  def prune(env)
    list = []
    list << "#{env.fetch('PR_NUMBER')}/" if pull_request?(env)
    branch = env.fetch('BRANCH')
    list << "#{safe_branch(branch)}/" unless branch == 'main'
    list
  end

  def drop(env, dir)
    prune(env).each { |prefix| FileUtils.rm_rf(File.join(dir, prefix)) }
  end

  def pull_request?(env)
    env.fetch('EVENT_NAME', '').start_with?('pull_request')
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
    case ARGV.first
    when 'prune' then puts Prefix.prune(ENV)
    when 'drop' then Prefix.drop(ENV, ARGV.fetch(1))
    else puts Prefix.compute(ENV)
    end
  rescue Prefix::Error => e
    warn "prefix: #{e.message}"
    exit 1
  end
end
