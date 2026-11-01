require 'json'
require 'net/http'
require 'open3'
require 'uri'
require_relative 'prefix'

class Check
  class Error < StandardError; end

  module Remote
    module_function

    def gh(path, *)
      out, err, status = Open3.capture3('gh', 'api', path, *)
      raise Error, "gh api #{path} failed: #{err.strip}" unless status.success?

      out
    rescue Errno::ENOENT
      raise Error, 'gh not found on PATH'
    end

    def get(url)
      Net::HTTP.get_response(URI(url))
    rescue StandardError
      nil
    end

    def shield(url)
      "https://img.shields.io/endpoint?#{URI.encode_www_form('url' => url, 'cacheSeconds' => 60)}"
    end
  end

  class Probe
    SVG = 'image/svg+xml'.freeze

    def initialize(http)
      @http = http
    end

    def badge?(url, label)
      json = badge_json(url, label)
      return false unless json

      res = @http.call(Remote.shield(url))
      ok?(res) && res.body.to_s.include?(label) && res.body.to_s.include?(json['message'])
    end

    def camo?(url)
      res = @http.call(url)
      ok?(res) && res['content-type'].to_s.start_with?(SVG)
    end

    private

    def badge_json(url, label)
      res = @http.call(url)
      return unless ok?(res)

      json = JSON.parse(res.body.to_s)
      json if valid?(json, label)
    rescue JSON::ParserError
      nil
    end

    def valid?(json, label)
      json.is_a?(Hash) && json['schemaVersion'] == 1 && json['label'] == label &&
        json['message'].is_a?(String) && !json['message'].empty? && json['color'].is_a?(String)
    end

    def ok?(res)
      res&.code == '200'
    end
  end

  HTML = 'Accept: application/vnd.github.html+json'.freeze
  CAMO_SRC = %r{src="(https://camo\.githubusercontent\.com/[^"]+)"}

  def self.run(env, api = Remote.method(:gh), http = Remote.method(:get))
    bad = new(env, api, http).failures
    bad.each { |item| puts item }
    bad.empty? ? 0 : 1
  rescue Error, Prefix::Error, JSON::ParserError, KeyError => e
    warn "check: #{e.message}"
    1
  end

  def initialize(env, api, http)
    @env = env
    @api = api
    @probe = Probe.new(http)
  end

  def failures
    store = store_dirs
    pulls = open_numbers
    sources = camo_sources(store, pulls)
    missing_images(sources) + stale(store, pulls) + unsettled(badge_checks(store) + camo_checks(sources))
  end

  def store_dirs
    tree = JSON.parse(@api.call("repos/#{repo}/git/trees/#{store}")).fetch('tree')
    tree.select { |entry| entry['type'] == 'tree' }.map { |entry| entry['path'] }
  end

  def open_numbers
    lines(@api.call("repos/#{repo}/pulls?state=open", '--paginate', '--jq', '.[].number'))
  end

  def stale(store, pulls)
    branches = lines(@api.call("repos/#{repo}/branches", '--paginate', '--jq', '.[].name'))
    live = pulls + branches.map { |name| Prefix.safe_branch(name) }
    (store - ['main', *live]).map { |dir| "stale badges dir: #{dir}/" }
  end

  def camo_sources(store, pulls)
    sources = pulls.map do |number|
      html = @api.call("repos/#{repo}/pulls/#{number}", '-H', HTML, '--jq', '.body_html')
      ["PR #{number} body", camo(html)]
    end
    return sources unless store.include?('main')

    sources + [['README on main', camo(@api.call("repos/#{repo}/readme?ref=main", '-H', HTML))]]
  end

  def missing_images(sources)
    sources.select { |_label, urls| urls.empty? }.map { |label, _urls| "#{label} has no badge image" }
  end

  def camo(html)
    html.scan(CAMO_SRC).flatten
  end

  def badge_checks(store)
    dirs(store).product(labels).map do |dir, label|
      url = "#{pages}#{dir}#{label}/badge.json"
      [url, -> { @probe.badge?(url, label) }]
    end
  end

  def camo_checks(sources)
    sources.flat_map { |_label, urls| urls }.map { |url| [url, -> { @probe.camo?(url) }] }
  end

  def dirs(store)
    current = [Prefix.compute(@env, @api)]
    store.include?('main') ? (current + ['main/']).uniq : current
  end

  def unsettled(checks)
    checks.reject { |_url, check| settle(check) }.map(&:first)
  end

  def settle(check)
    return true if check.call

    (tries - 1).times.any? do
      sleep gap
      check.call
    end
  end

  def labels
    lines(@env.fetch('LABELS')).map { |line| line.split('=', 2).first }
  end

  def lines(text)
    text.lines.map(&:strip).reject(&:empty?)
  end

  def pages
    "https://#{repo.sub('/', '.github.io/')}/"
  end

  def repo
    @env.fetch('REPO')
  end

  def store
    @env.fetch('STORE', 'badges')
  end

  def tries
    Integer(@env.fetch('TRIES', 10))
  end

  def gap
    Float(@env.fetch('GAP', 15))
  end
end

exit Check.run(ENV) if __FILE__ == $PROGRAM_NAME
