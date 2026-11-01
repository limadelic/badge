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
      json = File.read(File.join(site, 'main', 'cukes', 'badge.json'))
      assert_equal '{"schemaVersion":1,"label":"cukes","message":"3/3","color":"brightgreen"}', json
    end
  end

  def test_logo_is_named_logo
    Dir.mktmpdir do |site|
      Make.run(env('LOGO' => 'cucumber'), site: site)
      assert_includes File.read(File.join(site, 'main', 'cukes', 'badge.json')), '"namedLogo":"cucumber"'
    end
  end

  def test_pull_request_writes_under_pr_number
    Dir.mktmpdir do |site|
      Make.run(env('EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), site: site)
      assert File.exist?(File.join(site, '7', 'cukes', 'badge.json'))
    end
  end

  def test_copies_files_into_label_dir
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      site = File.join(dir, 'site')
      Make.run(env('FILES' => report, 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), site: site)
      assert_equal '<html></html>', File.read(File.join(site, '7', 'cukes', 'report.html'))
    end
  end

  def test_returns_path_dir_and_default_link
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      out = Make.run(env('FILES' => report), site: File.join(dir, 'site'))
      assert_equal 'main/cukes/', out['path']
      assert_equal File.join(dir, 'site', 'main', 'cukes/'), out['dir']
      assert_equal 'main/cukes/report.html', out['link']
    end
  end

  def test_link_defaults_to_badge_json_without_files
    Dir.mktmpdir do |site|
      assert_equal 'main/cukes/badge.json', Make.run(env, site: site)['link']
    end
  end

  def test_given_link_wins
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      extra = { 'FILES' => report, 'LINK' => 'report.html', 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7' }
      out = Make.run(env(extra), site: File.join(dir, 'site'))
      assert_equal '7/cukes/report.html', out['link']
    end
  end

  def test_link_to_missing_file_fails
    Dir.mktmpdir do |site|
      assert_raises(Make::Error) { Make.run(env('LINK' => 'index.html'), site: site) }
    end
  end

  def test_link_with_slash_fails
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      assert_raises(Make::Error) do
        Make.run(env('FILES' => report, 'LINK' => 'sub/report.html'), site: File.join(dir, 'site'))
      end
    end
  end

  def test_directory_in_files_fails
    Dir.mktmpdir do |dir|
      assert_raises(Make::Error) { Make.run(env('FILES' => dir), site: File.join(dir, 'site')) }
    end
  end

  def test_empty_label_fails
    Dir.mktmpdir do |site|
      assert_raises(Make::Error) { Make.run(env('LABEL' => ''), site: site) }
    end
  end

  def test_label_with_slash_fails
    Dir.mktmpdir do |site|
      assert_raises(Make::Error) { Make.run(env('LABEL' => 'a/b'), site: site) }
    end
  end

  def test_missing_file_fails
    Dir.mktmpdir do |site|
      assert_raises(Errno::ENOENT) { Make.run(env('FILES' => '/nope/report.html'), site: site) }
    end
  end
end
