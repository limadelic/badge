require 'json'
require 'open3'

module Store
  class Error < StandardError; end

  module_function

  def run_id(env, api = method(:gh))
    artifacts = JSON.parse(api.call(artifacts_path(env))).fetch('artifacts')
    live = artifacts.reject { |artifact| artifact['expired'] }
    live.max_by { |artifact| artifact['created_at'] }&.dig('workflow_run', 'id')&.to_s
  end

  def artifacts_path(env)
    "repos/#{env.fetch('REPO')}/actions/artifacts?name=github-pages&per_page=100"
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
    puts Store.run_id(ENV)
  rescue Store::Error => e
    warn "store: #{e.message}"
    exit 1
  end
end
