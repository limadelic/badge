require 'json'
require 'net/http'
require 'open3'
require 'uri'
require_relative 'body'
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
    class Miss < StandardError; end

    SVG = 'image/svg+xml'.freeze
    FAILED = /not found|inaccessible|invalid/
    LABEL = /aria-label="([^"]*)"/

    def initialize(http)
      @http = http
    end

    def badge(url, label)
      attempt(url) do
        json = badge_json(url, label)
        shield = @http.call(Remote.shield(url))
        expect(ok?(shield), status(shield))
        svg = shield.body.to_s
        expect(svg.include?(label), "shield svg lacks #{label}")
        expect(svg.include?(json['message']), "shield svg lacks #{json['message']}")
      end
    end

    def camo(url)
      attempt(url) do
        res = @http.call(url)
        expect(ok?(res), status(res))
        expect(res['content-type'].to_s.start_with?(SVG), "content-type #{res['content-type'] || 'missing'}")
        label_ok(res.body.to_s)
      end
    end

    private

    def label_ok(svg)
      label = svg[LABEL, 1].to_s
      expect(!FAILED.match?(label), "aria-label \"#{label}\"")
    end

    def badge_json(url, label)
      res = @http.call(url)
      expect(ok?(res), status(res))
      json = parse(res.body.to_s)
      expect(valid?(json, label), "not a #{label} badge json")
      expect(filled?(json), 'empty badge json')
      json
    end

    def parse(text)
      JSON.parse(text)
    rescue JSON::ParserError
      raise Miss, 'body is not JSON'
    end

    def valid?(json, label)
      json.is_a?(Hash) && json.values_at('schemaVersion', 'label') == [1, label]
    end

    def filled?(json)
      json.values_at('message', 'color').all?(/\S/)
    end

    def expect(cond, reason)
      raise Miss, reason unless cond
    end

    def attempt(url)
      yield
      nil
    rescue Miss => e
      "#{url}: #{e.message}"
    end

    def status(res)
      res ? "HTTP #{res.code}" : 'no response'
    end

    def ok?(res)
      res&.code == '200'
    end
  end

  HTML = 'Accept: application/vnd.github.html+json'.freeze
  CAMO_SRC = %r{src="(https://camo\.githubusercontent\.com/[^"]+)"}

  def self.run(env, api = Remote.method(:gh), http = Remote.method(:get), site = '_site')
    bad = new(env, api, http, site).failures
    bad.each { |item| puts item }
    bad.empty? ? 0 : 1
  rescue Error, Prefix::Error, JSON::ParserError, KeyError => e
    warn "check: #{e.message}"
    1
  end

  def initialize(env, api, http, site)
    @env = env
    @api = api
    @probe = Probe.new(http)
    @site = site
  end

  def failures
    store = store_dirs
    pulls = open_numbers
    sources = camo_sources(store, pulls)
    missing_images(sources) + stale(store, pulls) + unsettled(badge_checks(store) + camo_checks(sources))
  end

  def store_dirs
    dirs = Dir.children(@site).sort.select { |name| File.directory?(File.join(@site, name)) }
    raise Error, 'store is empty' if dirs.empty?
    raise Error, 'store has no main prefix' if main_run? && !dirs.include?('main')

    dirs
  end

  def main_run?
    @env.fetch('BRANCH') == 'main' && !Prefix.pull_request?(@env)
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
    sources = pulls.filter_map do |number|
      pull = JSON.parse(@api.call("repos/#{repo}/pulls/#{number}", '-H', HTML))
      ["PR #{number} body", camo(pull['body_html'].to_s)] if pull['body'].to_s.include?(Body::START)
    end
    return sources unless store.include?('main')

    sources + [['README on main', camo(@api.call("repos/#{repo}/readme", '-H', HTML))]]
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
      -> { @probe.badge(url, label) }
    end
  end

  def camo_checks(sources)
    sources.flat_map { |_label, urls| urls }.map { |url| -> { @probe.camo(url) } }
  end

  def dirs(store)
    current = [Prefix.compute(@env, @api)]
    store.include?('main') ? (current + ['main/']).uniq : current
  end

  def unsettled(checks)
    checks.filter_map { |check| settle(check) }
  end

  def settle(check)
    reason = check.call
    (tries - 1).times do
      break unless reason

      sleep gap
      reason = check.call
    end
    reason
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

  def tries
    Integer(@env.fetch('TRIES', 10))
  end

  def gap
    Float(@env.fetch('GAP', 15))
  end
end

exit Check.run(ENV) if __FILE__ == $PROGRAM_NAME
