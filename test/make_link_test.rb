require 'minitest/autorun'
require 'tmpdir'
require 'make'

class MakeLinkTest < Minitest::Test
  def env(extra = {})
    { 'LABEL' => 'cukes', 'MESSAGE' => '3/3', 'COLOR' => 'brightgreen', 'BRANCH' => 'main',
      'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7', 'LOGO' => '', 'FILES' => '' }.merge(extra)
  end

  def test_link_to_path_in_copied_dir_is_pages_url
    Dir.mktmpdir do |dir|
      cover = File.join(dir, 'cover')
      Dir.mkdir(cover)
      File.write(File.join(cover, 'index.html'), '<html></html>')
      out = Make.run(env('FILES' => cover, 'LINK' => 'cover/index.html'), site: File.join(dir, 'site'))
      assert_equal '7/cukes/cover/index.html', out['link']
    end
  end

  def test_url_link_is_kept_exactly
    Dir.mktmpdir do |site|
      url = 'https://github.com/limadelic/elita/actions/runs/1'
      assert_equal url, Make.run(env('LINK' => url), site: site)['link']
    end
  end
end
