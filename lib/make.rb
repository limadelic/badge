require 'json'
require 'fileutils'
require_relative 'prefix'

module Make
  module_function

  def run(env, site: 'site')
    dir = File.join(site, Prefix.compute(env))
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{env.fetch('LABEL')}.json"), JSON.generate(endpoint(env)))
    files(env).each { |file| FileUtils.cp(file, dir) }
  end

  def endpoint(env)
    json = { schemaVersion: 1, label: env.fetch('LABEL'), message: env.fetch('MESSAGE'), color: env.fetch('COLOR') }
    logo = env.fetch('LOGO', '')
    logo.empty? ? json : json.merge(namedLogo: logo)
  end

  def files(env)
    env.fetch('FILES', '').split
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    Make.run(ENV)
  rescue Prefix::Error, Errno::ENOENT => e
    warn "make: #{e.message}"
    exit 1
  end
end
