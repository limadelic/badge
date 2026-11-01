require 'minitest/autorun'
require 'check'
require_relative 'check_helpers'

class CheckTest < Minitest::Test
  include CheckHelpers

  def test_all_good_is_clean
    assert_equal [0, []], check
  end

  def test_missing_badge_json_is_bad
    assert_equal [1, [BADGE]], check(http: { BADGE => bad_status })
  end

  def test_svg_without_message_is_bad
    assert_equal [1, [BADGE]], check(http: { Check::Remote.shield(BADGE) => ok('cukes') })
  end

  def test_svg_without_label_is_bad
    assert_equal [1, [BADGE]], check(http: { Check::Remote.shield(BADGE) => ok('3/3') })
  end

  def test_bad_json_is_bad
    assert_equal [1, [BADGE]], check(http: { BADGE => ok('nope', 'application/json') })
  end

  def test_json_for_other_label_is_bad
    json = JSON.generate(schemaVersion: 1, label: 'cover', message: '3/3', color: 'red')
    assert_equal [1, [BADGE]], check(http: { BADGE => ok(json) })
  end

  def test_network_error_is_bad
    assert_equal [1, [BADGE]], check(http: { BADGE => nil })
  end

  def test_retries_until_good
    seen = 0
    http = lambda do |url|
      seen += 1 if url == BADGE
      seen < 3 && url == BADGE ? bad_status : served[url]
    end
    assert_equal [0, []], run_with(base('TRIES' => '3'), routes, http)
  end

  def test_gives_up_after_tries
    seen = 0
    http = lambda do |url|
      next served[url] unless url == BADGE

      seen += 1
      bad_status
    end
    assert_equal [1, [BADGE]], run_with(base('TRIES' => '3'), routes, http)
    assert_equal 3, seen
  end

  def test_stale_dir_is_bad
    assert_equal [1, ['stale badges dir: old/']], check(api: stale_api)
  end

  def test_pr_block_without_badge_is_bad
    api = { "repos/#{REPO}/pulls?state=open" => "7\n", "repos/#{REPO}/pulls/7" => pull('<p>hi</p>') }
    assert_equal [1, ['PR 7 body has no badge image']], check(api: api)
  end

  def test_pr_without_block_is_not_checked
    api = { "repos/#{REPO}/pulls?state=open" => "7\n", "repos/#{REPO}/pulls/7" => pull('<p>hi</p>', 'hi') }
    assert_equal [0, []], check(api: api)
  end

  def test_camo_not_svg_is_bad
    assert_equal [1, [CAMO]], check(http: { CAMO => ok('x', 'image/png') })
  end

  def test_pr_badge_on_pull_request_is_good
    http = { PR_BADGE => ok(JSON_OK), Check::Remote.shield(PR_BADGE) => ok('cukes 3/3') }
    assert_equal [0, []], check(env: pr_env, api: pr_api, http: http)
  end

  def test_gh_failure_is_bad_not_a_crash
    assert_equal [1, []], run_with(base, {}, ->(_url) {})
  end
end
