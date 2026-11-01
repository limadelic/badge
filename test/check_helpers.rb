require 'json'
require 'check'

module CheckHelpers
  Reply = Struct.new(:code, :body, :headers) do
    def [](key)
      headers[key]
    end
  end

  Api = Struct.new(:routes) do
    def call(path, *_args)
      routes.fetch(path) { raise Check::Error, "no route #{path}" }
    end
  end

  REPO = 'limadelic/badge'.freeze
  PAGES = 'https://limadelic.github.io/badge'.freeze
  BADGE = "#{PAGES}/main/cukes/badge.json".freeze
  PR_BADGE = "#{PAGES}/7/cukes/badge.json".freeze
  CAMO = 'https://camo.githubusercontent.com/readme.svg'.freeze
  IMG = %(<img src="#{CAMO}">).freeze
  TREE = '{"tree":[{"path":"main","type":"tree"}]}'.freeze
  JSON_OK = JSON.generate(schemaVersion: 1, label: 'cukes', message: '3/3', color: 'brightgreen')
  PR_BODY = "<!-- badges-start -->\nold\n<!-- badges-end -->".freeze
  STALE_TREE = '{"tree":[{"path":"main","type":"tree"},{"path":"7","type":"tree"},' \
               '{"path":"unit","type":"tree"},{"path":"old","type":"tree"}]}'.freeze

  def ok(body, type = 'image/svg+xml')
    Reply.new('200', body, { 'content-type' => type })
  end

  def bad_status
    Reply.new('404', '', {})
  end

  def base(extra = {})
    { 'REPO' => REPO, 'BRANCH' => 'main', 'EVENT_NAME' => 'push', 'LABELS' => 'cukes=cucumber.json',
      'TRIES' => '1', 'GAP' => '0' }.merge(extra)
  end

  def routes(extra = {})
    { "repos/#{REPO}/git/trees/badges" => TREE, "repos/#{REPO}/pulls?state=open" => '',
      "repos/#{REPO}/branches" => "main\n", "repos/#{REPO}/readme?ref=main" => IMG }.merge(extra)
  end

  def served(extra = {})
    { BADGE => ok(JSON_OK), Check::Remote.shield(BADGE) => ok('cukes 3/3'), CAMO => ok('<svg/>') }.merge(extra)
  end

  def run_with(env, api, http)
    status = nil
    out, = capture_io { status = Check.run(env, Api.new(api), http) }
    [status, out.lines.map(&:chomp)]
  end

  def check(env: {}, api: {}, http: {})
    run_with(base(env), routes(api), ->(url) { served(http)[url] })
  end

  def pull(html, body = PR_BODY)
    JSON.generate(body: body, body_html: html)
  end

  def stale_api
    { "repos/#{REPO}/git/trees/badges" => STALE_TREE, "repos/#{REPO}/pulls?state=open" => "7\n",
      "repos/#{REPO}/branches" => "main\nunit\n", "repos/#{REPO}/pulls/7" => pull(IMG) }
  end

  def pr_env
    { 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7', 'BRANCH' => 'unit' }
  end

  def pr_api
    { "repos/#{REPO}/git/trees/badges" => '{"tree":[{"path":"7","type":"tree"}]}',
      "repos/#{REPO}/pulls?state=open" => "7\n", "repos/#{REPO}/branches" => "unit\n",
      "repos/#{REPO}/pulls/7" => pull(IMG) }
  end
end
