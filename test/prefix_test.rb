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

  def test_main_is_empty
    assert_equal '', Prefix.compute(env('BRANCH' => 'main'), NO_GH)
  end

  def test_pull_request_event_uses_pr_number_without_gh
    assert_equal '7/', Prefix.compute(env('EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7'), NO_GH)
  end

  def test_branch_with_pr_uses_pr_number
    assert_equal '12/', Prefix.compute(env, gh_returning('[{"number":12}]'))
  end

  def test_branch_without_pr_uses_branch
    assert_equal 'feat/', Prefix.compute(env, gh_returning('[]'))
  end

  def test_gh_bad_json_fails
    assert_raises(Prefix::Error) { Prefix.compute(env, gh_returning('nope')) }
  end

  def test_gh_non_array_fails
    assert_raises(Prefix::Error) { Prefix.compute(env, gh_returning('{"message":"Not Found"}')) }
  end

  def test_gh_exit_failure_fails
    Dir.mktmpdir do |dir|
      gh = File.join(dir, 'gh')
      File.write(gh, "#!/bin/sh\necho denied >&2\nexit 1\n")
      File.chmod(0o755, gh)
      path = ENV.fetch('PATH', nil)
      ENV['PATH'] = "#{dir}:#{path}"
      assert_raises(Prefix::Error) { Prefix.compute(env) }
    ensure
      ENV['PATH'] = path
    end
  end
end
