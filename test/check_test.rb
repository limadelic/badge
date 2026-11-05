require 'minitest/autorun'
require 'check'
require_relative 'check_helpers'

class CheckTest < Minitest::Test
  include CheckHelpers

  def test_all_good_is_clean
    assert_equal [0, []], check
  end

  def test_missing_badge_json_is_bad
    assert_equal [1, ["#{BADGE}: HTTP 404"]], check(http: { BADGE => bad_status })
  end

  def test_svg_without_message_is_bad
    http = { Check::Remote.shield(BADGE) => ok('cukes') }
    assert_equal [1, ["#{BADGE}: shield svg lacks 3/3"]], check(http: http)
  end

  def test_shield_svg_lacks_cukes_is_bad
    json = JSON.generate(schemaVersion: 1, label: 'cukes', message: 'invalid', color: 'red')
    http = { BADGE => ok(json), Check::Remote.shield(BADGE) => ok('custom badge: inaccessible') }
    assert_equal [1, ["#{BADGE}: shield svg lacks cukes"]], check(http: http)
  end

  def test_svg_without_label_is_bad
    http = { Check::Remote.shield(BADGE) => ok('3/3') }
    assert_equal [1, ["#{BADGE}: shield svg lacks cukes"]], check(http: http)
  end

  def test_bad_json_is_bad
    assert_equal [1, ["#{BADGE}: body is not JSON"]], check(http: { BADGE => ok('nope', 'application/json') })
  end

  def test_json_for_other_label_is_bad
    json = JSON.generate(schemaVersion: 1, label: 'cover', message: '3/3', color: 'red')
    assert_equal [1, ["#{BADGE}: not a cukes badge json"]], check(http: { BADGE => ok(json) })
  end

  def test_network_error_is_bad
    assert_equal [1, ["#{BADGE}: no response"]], check(http: { BADGE => nil })
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
    assert_equal [1, ["#{BADGE}: HTTP 404"]], run_with(base('TRIES' => '3'), routes, http)
    assert_equal 3, seen
  end

  def test_stale_dir_is_bad
    assert_equal [1, ['stale badges dir: old/']], check(api: stale_api, dirs: %w[main 7 unit old])
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
    assert_equal [1, ["#{CAMO}: content-type image/png"]], check(http: { CAMO => ok('x', 'image/png') })
  end

  def test_camo_missing_content_type_is_bad
    assert_equal [1, ["#{CAMO}: content-type missing"]], check(http: { CAMO => ok('x', nil) })
  end

  def test_camo_http_error_is_bad
    assert_equal [1, ["#{CAMO}: HTTP 404"]], check(http: { CAMO => bad_status })
  end

  def test_camo_ok_label_is_good
    assert_equal [0, []], check(http: { CAMO => ok(svg('cukes: 3/3')) })
  end

  def test_camo_not_found_label_is_bad_after_retries
    seen = 0
    http = lambda do |url|
      next served[url] unless url == CAMO

      seen += 1
      ok(svg('cukes: not found'))
    end
    reason = "#{CAMO}: aria-label \"cukes: not found\""
    assert_equal [1, [reason]], run_with(base('TRIES' => '10'), routes, http)
    assert_equal 10, seen
  end

  def test_camo_inaccessible_label_is_bad
    reason = "#{CAMO}: aria-label \"custom badge: inaccessible\""
    assert_equal [1, [reason]], check(http: { CAMO => ok(svg('custom badge: inaccessible')) })
  end

  def test_camo_invalid_label_is_bad
    reason = "#{CAMO}: aria-label \"cukes: invalid\""
    assert_equal [1, [reason]], check(http: { CAMO => ok(svg('cukes: invalid')) })
  end

  def test_pr_body_camo_not_found_label_is_bad
    http = pr_served(CAMO => ok(svg('cukes: not found')))
    assert_equal [1, ["#{CAMO}: aria-label \"cukes: not found\""]], pr_check(http: http)
  end

  def test_pr_badge_on_pull_request_is_good
    assert_equal [0, []], pr_check(http: pr_served)
  end

  def test_gh_failure_is_bad_not_a_crash
    assert_equal [1, []], run_with(base, {}, ->(_url) {})
  end
end
