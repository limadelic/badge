require 'minitest/autorun'
require 'tmpdir'
require 'make'

class MakeTest < Minitest::Test
  def env(extra = {})
    { 'LABEL' => 'cukes', 'MESSAGE' => '3/3', 'COLOR' => 'brightgreen', 'BRANCH' => 'main',
      'EVENT_NAME' => 'push', 'LOGO' => '', 'FILES' => '' }.merge(extra)
  end

  def test_writes_endpoint_json_on_main
    Dir.mktmpdir do |site|
      Make.run(env, site: site)
      json = File.read(File.join(site, 'cukes.json'))
      assert_equal '{"schemaVersion":1,"label":"cukes","message":"3/3","color":"brightgreen"}', json
    end
  end

  def test_logo_is_named_logo
    Dir.mktmpdir do |site|
      Make.run(env('LOGO' => 'cucumber'), site: site)
      assert_includes File.read(File.join(site, 'cukes.json')), '"namedLogo":"cucumber"'
    end
  end

  def test_pull_request_writes_under_pr_number
    Dir.mktmpdir do |site|
      Make.run(env('EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), site: site)
      assert File.exist?(File.join(site, '7', 'cukes.json'))
    end
  end

  def test_copies_files_under_prefix
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      site = File.join(dir, 'site')
      Make.run(env('FILES' => report, 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), site: site)
      assert_equal '<html></html>', File.read(File.join(site, '7', 'report.html'))
    end
  end

  def test_missing_file_fails
    Dir.mktmpdir do |site|
      assert_raises(Errno::ENOENT) { Make.run(env('FILES' => '/nope/report.html'), site: site) }
    end
  end
end
