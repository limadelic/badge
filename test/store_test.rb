require 'minitest/autorun'
require 'store'

class StoreTest < Minitest::Test
  def env
    { 'REPO' => 'limadelic/badge' }
  end

  def api_returning(artifacts)
    ->(_path) { JSON.generate('artifacts' => artifacts) }
  end

  def artifact(run, created, expired: false)
    { 'name' => 'github-pages', 'created_at' => created, 'expired' => expired, 'workflow_run' => { 'id' => run } }
  end

  def test_no_artifact_is_nil
    assert_nil Store.run_id(env, api_returning([]))
  end

  def test_newest_artifact_gives_its_run_id
    list = [artifact(1, '2026-10-01T10:00:00Z'), artifact(2, '2026-10-02T10:00:00Z')]
    assert_equal '2', Store.run_id(env, api_returning(list))
  end

  def test_newest_wins_regardless_of_order
    list = [artifact(2, '2026-10-02T10:00:00Z'), artifact(1, '2026-10-01T10:00:00Z')]
    assert_equal '2', Store.run_id(env, api_returning(list))
  end

  def test_expired_artifact_is_skipped
    list = [artifact(2, '2026-10-02T10:00:00Z', expired: true), artifact(1, '2026-10-01T10:00:00Z')]
    assert_equal '1', Store.run_id(env, api_returning(list))
  end

  def test_only_expired_artifacts_is_nil
    list = [artifact(2, '2026-10-02T10:00:00Z', expired: true)]
    assert_nil Store.run_id(env, api_returning(list))
  end

  def test_lists_github_pages_artifacts
    path = nil
    api = lambda do |p|
      path = p
      JSON.generate('artifacts' => [])
    end
    Store.run_id(env, api)
    assert_equal 'repos/limadelic/badge/actions/artifacts?name=github-pages&per_page=100', path
  end
end
