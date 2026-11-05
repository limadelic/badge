require 'minitest/autorun'
require 'check'
require_relative 'check_helpers'

class CheckShieldTest < Minitest::Test
  include CheckHelpers

  def test_shield_url_busts_cache_with_run_id
    run_id = ENV.fetch('GITHUB_RUN_ID', nil)
    ENV['GITHUB_RUN_ID'] = '42'
    query = URI.decode_www_form(URI(Check::Remote.shield(BADGE)).query).to_h
    assert_equal '42', query['v']
  ensure
    ENV['GITHUB_RUN_ID'] = run_id
  end
end
