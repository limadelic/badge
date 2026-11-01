require 'open3'
require 'tempfile'
require 'uri'
require_relative 'prefix'

module Body
  class Error < StandardError; end

  START = '<!-- badges-start -->'.freeze
  STOP = '<!-- badges-end -->'.freeze
  BLOCK = /#{START}.*?#{STOP}\n?/m

  module_function

  def run(env, api = method(:gh))
    case env.fetch('TARGET')
    when 'pr' then pr(env, api)
    when 'readme' then readme(env)
    else raise Error, "target must be pr or readme: #{env.fetch('TARGET')}"
    end
  end

  def pr(env, api)
    number = pr_number(env, api)
    return unless number

    path = "repos/#{env.fetch('REPO')}/pulls/#{number}"
    body = api.call(path, '--jq', '.body // ""').chomp
    return if only_missing?(env) && body.include?(START)

    updated = merge(body, block(env, "#{number}/", true))
    patch(api, path, updated) unless updated == body
  end

  def readme(env, path = 'README.md')
    return unless env.fetch('BRANCH') == 'main'

    text = File.read(path)
    markup = block(env, 'main/', false)
    updated = text.match?(BLOCK) ? text.sub(BLOCK) { markup } : insert(text, markup)
    File.write(path, updated)
  end

  def block(env, prefix, cache)
    root = pages_root(env)
    lines = badges(env).map do |label, link|
      "[![#{label}](#{shield(env, prefix, label, cache)})](#{root}#{prefix}#{label}/#{link})"
    end
    "#{START}\n#{lines.join("\n")}\n#{STOP}\n"
  end

  def shield(env, prefix, label, cache)
    params = { 'url' => "#{pages_root(env)}#{prefix}#{label}/badge.json", 'cacheSeconds' => 60 }
    params['v'] = env.fetch('RUN_ID') if cache
    "https://img.shields.io/endpoint?#{URI.encode_www_form(params)}"
  end

  def badges(env)
    list = env.fetch('BADGES').lines.map(&:strip).reject(&:empty?).map { |line| badge(line) }
    raise Error, 'badges must not be empty' if list.empty?

    list
  end

  def badge(line)
    label, link = line.split('=', 2)
    pair = [label, link || 'badge.json']
    raise Error, "bad badge: #{line}" if pair.any? { |part| part.empty? || part.include?('/') }

    pair
  end

  def pr_number(env, api)
    return env.fetch('PR_NUMBER') if env.fetch('EVENT_NAME').start_with?('pull_request')

    Prefix.open_pr(env, api)
  end

  def only_missing?(env)
    env.fetch('ONLY_MISSING') == 'true'
  end

  def merge(body, markup)
    return body.sub(BLOCK) { markup } if body.match?(BLOCK)

    [markup, body].reject(&:empty?).join("\n")
  end

  def insert(text, markup)
    lines = text.lines
    index = lines.index { |line| line.start_with?('# ') }
    raise Error, 'README.md has no # heading' unless index

    lines.insert(index + 1, "\n", markup).join
  end

  def patch(api, path, body)
    Tempfile.create('body') do |file|
      file.write(body)
      file.flush
      api.call(path, '-X', 'PATCH', '-F', "body=@#{file.path}")
    end
  end

  def pages_root(env)
    owner, name = env.fetch('REPO').split('/')
    "https://#{owner}.github.io/#{name}/"
  end

  def gh(*args)
    out, err, status = Open3.capture3('gh', 'api', *args)
    raise Error, "gh api #{args.first} failed: #{err.strip}" unless status.success?

    out
  rescue Errno::ENOENT
    raise Error, 'gh not found on PATH'
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    Body.run(ENV)
  rescue Body::Error, Prefix::Error, Errno::ENOENT => e
    warn "body: #{e.message}"
    exit 1
  end
end
