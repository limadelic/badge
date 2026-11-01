require 'minitest/autorun'
require 'tmpdir'
require 'prefix'

class PrefixTest < Minitest::Test
  NO_GH = ->(_path) { raise 'gh must not be called' }

  def env(extra = {})
    { 'REPO' => 'limadelic/badge', 'BRANCH' => 'feat', 'EVENT_NAME' => 'push' }.merge(extra)
  end

  def gh_returning(out)
    ->(_path) { out }
  end

  def with_gh_script(body)
    Dir.mktmpdir do |dir|
      gh = File.join(dir, 'gh')
      File.write(gh, "#!/bin/sh\n#{body}")
      File.chmod(0o755, gh)
      path = ENV.fetch('PATH', nil)
      ENV['PATH'] = "#{dir}:#{path}"
      yield
    ensure
      ENV['PATH'] = path
    end
  end

  def test_main_is_main
    assert_equal 'main/', Prefix.compute(env('BRANCH' => 'main'), NO_GH)
  end

  def test_pull_request_event_uses_pr_number_without_gh
    assert_equal '7/', Prefix.compute(env('EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), NO_GH)
  end

  def test_pull_request_from_main_branch_uses_pr_number
    pr = env('BRANCH' => 'main', 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7')
    assert_equal '7/', Prefix.compute(pr, NO_GH)
  end

  def test_branch_with_pr_uses_pr_number
    assert_equal '12/', Prefix.compute(env, gh_returning('[{"number":12}]'))
  end

  def test_open_pr_lookup_queries_owner_and_branch
    path = nil
    api = lambda do |p|
      path = p
      '[]'
    end
    Prefix.compute(env, api)
    assert_equal 'repos/limadelic/badge/pulls?state=open&head=limadelic%3Afeat&per_page=100', path
  end

  def test_pr_number_is_nil_without_open_pr
    assert_nil Prefix.pr_number(env, gh_returning('[]'))
  end

  def test_branch_without_pr_uses_branch
    assert_equal 'feat/', Prefix.compute(env, gh_returning('[]'))
  end

  def test_branch_with_slash_uses_safe_branch
    assert_equal 'feature-x/', Prefix.compute(env('BRANCH' => 'feature/x'), gh_returning('[]'))
  end

  def test_safe_branch_replaces_slash
    assert_equal 'feature-x', Prefix.safe_branch('feature/x')
  end

  def test_gh_bad_json_fails
    assert_raises(Prefix::Error) { Prefix.compute(env, gh_returning('nope')) }
  end

  def test_gh_non_array_fails
    assert_raises(Prefix::Error) { Prefix.compute(env, gh_returning('{"message":"Not Found"}')) }
  end

  def test_gh_exit_failure_fails
    with_gh_script("echo '[{\"number\":1}]'\necho denied >&2\nexit 1\n") do
      error = assert_raises(Prefix::Error) { Prefix.compute(env) }
      assert_match(/failed: denied/, error.message)
    end
  end
end
