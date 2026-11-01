require 'erb'
require 'open3'
require 'tempfile'
require 'uri'
require_relative 'prefix'

module Body
  class Error < StandardError; end

  START = '<!-- badges-start -->'.freeze
  STOP = '<!-- badges-end -->'.freeze
  BLOCK = /#{START}.*?#{STOP}\r?\n?/m
  MARKER = /(?:#{START}|#{STOP})\r?\n?/

  module_function

  def run(env, api = method(:gh))
    case env.fetch('TARGET')
    when 'pr' then pr(env, api)
    when 'readme' then readme(env)
    when 'strip' then strip_pr(env, api)
    else raise Error, "target must be pr, readme or strip: #{env.fetch('TARGET')}"
    end
  end

  def strip_pr(env, api)
    path = "repos/#{env.fetch('REPO')}/pulls/#{env.fetch('PR_NUMBER')}"
    body = api.call(path, '--jq', '.body // ""').chomp
    patch(api, path, strip(body)) unless strip(body) == body
  end

  def pr(env, api)
    number = Prefix.pr_number(env, api)
    return unless number

    prefix = "#{number}/"
    path = "repos/#{env.fetch('REPO')}/pulls/#{number}"
    body = api.call(path, '--jq', '.body // ""').chomp
    return if only_missing?(env) && body.match?(BLOCK)

    markup = block(env, prefix, true)
    updated = place(body, markup) || [markup, strip(body)].reject(&:empty?).join("\n")
    patch(api, path, updated) unless updated == body
  end

  def readme(env, path = 'README.md')
    return unless env.fetch('BRANCH') == 'main'

    text = File.read(path)
    markup = block(env, 'main/', false)
    updated = place(text, markup) || insert(strip(text), markup)
    File.write(path, updated)
  end

  def block(env, prefix, cache)
    lines = badges(env).map do |label, link|
      "[![#{label}](#{shield(env, prefix, label, cache)})](#{url(env, prefix, label, link)})"
    end
    "#{START}\n#{lines.join("\n")}\n#{STOP}\n"
  end

  def shield(env, prefix, label, cache)
    params = { 'url' => url(env, prefix, label, 'badge.json'), 'cacheSeconds' => 60 }
    params['v'] = env.fetch('RUN_ID') if cache
    "https://img.shields.io/endpoint?#{URI.encode_www_form(params)}"
  end

  def url(env, prefix, label, file)
    dir = prefix.split('/', -1).map { |part| segment(part) }.join('/')
    "#{pages_root(env)}#{dir}#{segment(label)}/#{segment(file)}"
  end

  def segment(part)
    ERB::Util.url_encode(part)
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

  def only_missing?(env)
    env.fetch('ONLY_MISSING') == 'true'
  end

  def place(text, markup)
    before, found, after = text.partition(BLOCK)
    return if found.empty?

    strip(before) + markup + strip(after)
  end

  def strip(text)
    text.gsub(BLOCK, '').gsub(MARKER, '')
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
    "https://#{env.fetch('REPO').sub('/', '.github.io/')}/"
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
