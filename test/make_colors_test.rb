require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'make'

class MakeColorsTest < Minitest::Test
  def env(extra = {})
    { 'LABEL' => 'cukes', 'MESSAGE' => '3/3', 'COLOR' => 'brightgreen', 'BRANCH' => 'main',
      'EVENT_NAME' => 'push' }.merge(extra)
  end

  def badge_json(env)
    Dir.mktmpdir do |site|
      Make.run(env, site: site)
      JSON.parse(File.read(File.join(site, 'main', 'cukes', 'badge.json')))
    end
  end

  def test_given_colors_are_written
    json = badge_json(env('LABEL_COLOR' => 'black', 'LOGO_COLOR' => 'white'))
    assert_equal({ 'schemaVersion' => 1, 'label' => 'cukes', 'message' => '3/3', 'color' => 'brightgreen',
                   'labelColor' => 'black', 'logoColor' => 'white' }, json)
  end

  def test_missing_colors_are_left_out
    json = badge_json(env)
    assert_equal({ 'schemaVersion' => 1, 'label' => 'cukes', 'message' => '3/3', 'color' => 'brightgreen' }, json)
  end
end
