require 'minitest/autorun'
require 'check'
require_relative 'check_helpers'

class CheckSiteTest < Minitest::Test
  include CheckHelpers

  def test_empty_store_is_bad
    with_site([]) do |site|
      _out, err = capture_io { assert_equal 1, Check.run(base, Api.new(routes), ->(_url) {}, site) }
      assert_equal "check: store is empty\n", err
    end
  end

  def test_main_run_without_main_prefix_is_bad
    with_site(['7']) do |site|
      _out, err = capture_io { assert_equal 1, Check.run(base, Api.new(routes), ->(_url) {}, site) }
      assert_equal "check: store has no main prefix\n", err
    end
  end

  def test_files_in_store_are_not_prefixes
    with_site(['main']) do |site|
      File.write(File.join(site, 'index.html'), '')
      _out, err = capture_io { assert_equal 0, Check.run(base, Api.new(routes), ->(url) { served[url] }, site) }
      assert_equal '', err
    end
  end
end
