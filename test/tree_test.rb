require 'minitest/autorun'
require 'tmpdir'
require 'tree'

class TreeTest < Minitest::Test
  def test_copies_file_into_dir_under_its_name
    Dir.mktmpdir do |dir|
      report = File.join(dir, 'report.html')
      File.write(report, '<html></html>')
      out = File.join(dir, 'out')
      Dir.mkdir(out)
      Tree.copy(report, out)
      assert_equal '<html></html>', File.read(File.join(out, 'report.html'))
    end
  end

  def test_copies_nested_dir_under_its_name
    Dir.mktmpdir do |dir|
      cover = build_cover(dir)
      out = File.join(dir, 'out')
      Dir.mkdir(out)
      Tree.copy(cover, out)
      assert File.exist?(File.join(out, 'cover', 'index.html'))
      assert_equal 'a', File.read(File.join(out, 'cover', 'modules', 'a.html'))
    end
  end

  def build_cover(dir)
    cover = File.join(dir, 'cover')
    Dir.mkdir(cover)
    Dir.mkdir(File.join(cover, 'modules'))
    File.write(File.join(cover, 'index.html'), 'index')
    File.write(File.join(cover, 'modules', 'a.html'), 'a')
    cover
  end
end
