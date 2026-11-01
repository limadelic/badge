require 'minitest/autorun'
require 'tmpdir'
require 'cukes'

class CukesTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/cucumber.json', __dir__)

  def write_json(dir, body)
    path = File.join(dir, 'cucumber.json')
    File.write(path, body)
    path
  end

  def scenario(status)
    { 'type' => 'scenario', 'steps' => [{ 'result' => { 'status' => status } }] }
  end

  def feature(*elements)
    [{ 'elements' => elements }].to_json
  end

  def test_fixture_all_pass
    assert_equal({ 'message' => '3/3', 'color' => 'brightgreen' }, Cukes.summary(FIXTURE))
  end

  def test_one_failing_step_is_red
    Dir.mktmpdir do |dir|
      path = write_json(dir, feature(scenario('passed'), scenario('failed')))
      assert_equal({ 'message' => '1/2', 'color' => 'red' }, Cukes.summary(path))
    end
  end

  def test_no_scenarios_is_red
    Dir.mktmpdir do |dir|
      path = write_json(dir, feature)
      assert_equal({ 'message' => '0/0', 'color' => 'red' }, Cukes.summary(path))
    end
  end

  def test_background_is_not_counted
    Dir.mktmpdir do |dir|
      background = { 'type' => 'background', 'steps' => [{ 'result' => { 'status' => 'passed' } }] }
      path = write_json(dir, feature(background, scenario('passed')))
      assert_equal({ 'message' => '1/1', 'color' => 'brightgreen' }, Cukes.summary(path))
    end
  end

  def test_missing_file_fails
    error = assert_raises(Cukes::Error) { Cukes.summary('/nope/cucumber.json') }
    assert_match(/no such file/, error.message)
  end

  def test_bad_json_fails
    Dir.mktmpdir do |dir|
      error = assert_raises(Cukes::Error) { Cukes.summary(write_json(dir, 'nope')) }
      assert_match(/bad json/, error.message)
    end
  end

  def test_non_array_json_fails
    Dir.mktmpdir do |dir|
      error = assert_raises(Cukes::Error) { Cukes.summary(write_json(dir, '{"elements":[]}')) }
      assert_match(/not a cucumber json array/, error.message)
    end
  end
end
