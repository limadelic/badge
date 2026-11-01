require 'fileutils'
require 'json'
require 'tmpdir'
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
  JSON_OK = JSON.generate(schemaVersion: 1, label: 'cukes', message: '3/3', color: 'brightgreen')
  PR_BODY = "<!-- badges-start -->\nold\n<!-- badges-end -->".freeze

  def ok(body, type = 'image/svg+xml')
    Reply.new('200', body, { 'content-type' => type })
  end

  def bad_status
    Reply.new('404', '', {})
  end

  def svg(label)
    %(<svg role="img" aria-label="#{label}"></svg>)
  end

  def base(extra = {})
    { 'REPO' => REPO, 'BRANCH' => 'main', 'EVENT_NAME' => 'push', 'LABELS' => 'cukes=cucumber.json',
      'TRIES' => '1', 'GAP' => '0' }.merge(extra)
  end

  def routes(extra = {})
    { "repos/#{REPO}/pulls?state=open" => '', "repos/#{REPO}/branches" => "main\n",
      "repos/#{REPO}/readme" => IMG }.merge(extra)
  end

  def served(extra = {})
    { BADGE => ok(JSON_OK), Check::Remote.shield(BADGE) => ok('cukes 3/3'), CAMO => ok('<svg/>') }.merge(extra)
  end

  def with_site(dirs)
    Dir.mktmpdir do |site|
      dirs.each { |dir| FileUtils.mkdir_p(File.join(site, dir)) }
      yield site
    end
  end

  def run_with(env, api, http, dirs = ['main'])
    status = nil
    out, = with_site(dirs) { |site| capture_io { status = Check.run(env, Api.new(api), http, site) } }
    [status, out.lines.map(&:chomp)]
  end

  def check(env: {}, api: {}, http: {}, dirs: ['main'])
    run_with(base(env), routes(api), ->(url) { served(http)[url] }, dirs)
  end

  def pull(html, body = PR_BODY)
    JSON.generate(body: body, body_html: html)
  end

  def stale_api
    { "repos/#{REPO}/pulls?state=open" => "7\n", "repos/#{REPO}/branches" => "main\nunit\n",
      "repos/#{REPO}/pulls/7" => pull(IMG) }
  end

  def pr_env
    { 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7', 'BRANCH' => 'unit' }
  end

  def pr_check(http:)
    check(env: pr_env, api: pr_api, http: http, dirs: ['7'])
  end

  def pr_served(extra = {})
    { PR_BADGE => ok(JSON_OK), Check::Remote.shield(PR_BADGE) => ok('cukes 3/3') }.merge(extra)
  end

  def pr_api
    { "repos/#{REPO}/pulls?state=open" => "7\n", "repos/#{REPO}/branches" => "unit\n",
      "repos/#{REPO}/pulls/7" => pull(IMG) }
  end
end
