require 'minitest/autorun'
require 'prefix'

class PrefixPruneTest < Minitest::Test
  def test_closed_pull_request_drops_pr_and_branch
    env = { 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7', 'BRANCH' => 'feature/x' }
    assert_equal ['7/', 'feature-x/'], Prefix.prune(env)
  end

  def test_delete_drops_branch_only
    env = { 'EVENT_NAME' => 'delete', 'BRANCH' => 'feature/x' }
    assert_equal ['feature-x/'], Prefix.prune(env)
  end

  def test_delete_of_main_drops_nothing
    env = { 'EVENT_NAME' => 'delete', 'BRANCH' => 'main' }
    assert_empty Prefix.prune(env)
  end

  def test_closed_pull_request_from_main_drops_only_pr
    env = { 'EVENT_NAME' => 'pull_request', 'PR_NUMBER' => '7', 'BRANCH' => 'main' }
    assert_equal ['7/'], Prefix.prune(env)
  end
end
