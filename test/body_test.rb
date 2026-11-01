require 'minitest/autorun'
require 'tmpdir'
require 'body'
require_relative 'body_helpers'

class BodyTest < Minitest::Test
  include BodyHelpers

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

  def test_prepends_block_to_body_without_one
    gh = FakeGh.new(body: 'Fixes things')
    Body.run(pr_event, gh)
    assert_equal "#{BLOCK_7}\n\nFixes things", gh.patched
  end

  def test_patch_goes_to_pr_body_endpoint
    gh = FakeGh.new(body: 'Fixes things')
    Body.run(pr_event, gh)
    assert_equal ['repos/limadelic/badge/pulls/7', '-X', 'PATCH'], gh.calls.last.first(3)
  end

  def test_replaces_block_in_place
    gh = FakeGh.new(body: "Top\n<!-- badges-start -->\nold\n<!-- badges-end -->\nBottom")
    Body.run(pr_event, gh)
    assert gh.patched.start_with?("Top\n\n<!-- badges-start -->\n\n[![cukes]")
    assert gh.patched.end_with?("<!-- badges-end -->\n\nBottom")
    refute_includes gh.patched, 'old'
  end

  def test_only_missing_keeps_existing_block
    gh = FakeGh.new(body: "<!-- badges-start -->\nold\n<!-- badges-end -->")
    Body.run(pr_event('ONLY_MISSING' => 'true'), gh)
    assert_nil gh.patched
  end

  def test_no_open_pr_does_nothing
    gh = FakeGh.new
    Body.run(env, gh)
    assert_nil gh.patched
    assert_equal [['repos/limadelic/badge/pulls?state=open&head=limadelic%3Aunit&per_page=100']], gh.calls
  end

  def test_numeric_branch_without_pr_is_not_patched
    gh = FakeGh.new(body: 'Hi')
    Body.run(env('BRANCH' => '42'), gh)
    assert_nil gh.patched
  end

  def test_open_pr_of_branch_is_patched
    gh = FakeGh.new(body: 'Hi', pulls: '[{"number":12}]')
    Body.run(env, gh)
    assert_equal ['repos/limadelic/badge/pulls/12', '-X', 'PATCH'], gh.calls.last.first(3)
    assert_includes gh.patched, 'https://limadelic.github.io/badge/12/cukes/cucumber.json'
  end

  def test_badge_without_link_links_badge_json
    markup = Body.block(env('BADGES' => 'cukes'), 'main/', false)
    assert_includes markup, '(https://limadelic.github.io/badge/main/cukes/badge.json)'
  end

  def test_readme_block_goes_under_first_heading
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'README.md')
      File.write(path, "# badge\n\nText\n")
      Body.readme(env('TARGET' => 'readme', 'BRANCH' => 'main'), path)
      assert_equal "# badge\n\n#{MAIN_BLOCK}\n\nText\n", File.read(path)
    end
  end

  def test_readme_same_block_is_unchanged
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'README.md')
      File.write(path, "# badge\n")
      readme = env('TARGET' => 'readme', 'BRANCH' => 'main')
      Body.readme(readme, path)
      first = File.read(path)
      Body.readme(readme, path)
      assert_equal first, File.read(path)
    end
  end

  def test_readme_skips_other_branch
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'README.md')
      File.write(path, "# badge\n")
      Body.readme(env('TARGET' => 'readme'), path)
      assert_equal "# badge\n", File.read(path)
    end
  end

  def test_readme_without_heading_fails
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'README.md')
      File.write(path, "text\n")
      error = assert_raises(Body::Error) { Body.readme(env('TARGET' => 'readme', 'BRANCH' => 'main'), path) }
      assert_match(/no # heading/, error.message)
    end
  end

  def test_gh_failure_fails_loud
    with_gh_script("echo denied >&2\nexit 1\n") do
      error = assert_raises(Body::Error) { Body.run(env) }
      assert_match(/failed: denied/, error.message)
    end
  end
end
