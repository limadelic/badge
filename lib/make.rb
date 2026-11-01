require 'json'
require 'fileutils'
require_relative 'prefix'

module Make
  module_function

  def run(env, site: "badge-#{env.fetch('LABEL')}/site")
    path = "#{Prefix.compute(env)}#{env.fetch('LABEL')}/"
    dir = File.join(site, path)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'badge.json'), JSON.generate(endpoint(env)))
    files(env).each { |file| FileUtils.cp(file, dir) }
    { 'dir' => dir, 'path' => path, 'link' => "#{path}#{link(env)}" }
  end

  def endpoint(env)
    json = { schemaVersion: 1, label: env.fetch('LABEL'), message: env.fetch('MESSAGE'), color: env.fetch('COLOR') }
    logo = env.fetch('LOGO', '')
    logo.empty? ? json : json.merge(namedLogo: logo)
  end

  def link(env)
    given = env.fetch('LINK', '')
    return given unless given.empty?

    first = files(env).first
    first ? File.basename(first) : 'badge.json'
  end

  def files(env)
    env.fetch('FILES', '').split
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    Make.run(ENV).each { |key, value| puts "#{key}=#{value}" }
  rescue Prefix::Error, Errno::ENOENT => e
    warn "make: #{e.message}"
    exit 1
  end
end
