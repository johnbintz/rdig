require "test_helper"
require "mocha"

class ContentExtractorTest < Test::Unit::TestCase
  include TestHelper

  def test_process
    external_app_helper = Class.new do
      include RDig::ContentExtractors::ExternalAppHelper
    end.new

    external_app_helper.stubs(:get_content).returns(" content ")

    result = { :content => "content" }

    assert_equal result, external_app_helper.process("test")
  end
end