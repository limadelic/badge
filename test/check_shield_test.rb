require 'minitest/autorun'
require 'check'
require_relative 'check_helpers'

class CheckShieldTest < Minitest::Test
  include CheckHelpers

  def test_shield_url_busts_cache_with_run_id
    ENV['GITHUB_RUN_ID'] = '42'
    assert_includes Check::Remote.shield(BADGE), 'v=42'
  ensure
    ENV.delete('GITHUB_RUN_ID')
  end
end
