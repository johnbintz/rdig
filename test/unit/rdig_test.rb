require 'test_helper'
class RDigTest < Test::Unit::TestCase
  include TestHelper

  def setup
    RDig.configuration do |cfg|
      @old_crawler_cfg = cfg.crawler.clone
      cfg.log_level = :debug
      cfg.log_file = 'tmp/test.log'
    end
  end

  def teardown
    RDig.configuration do |cfg|
      cfg.crawler = @old_crawler_cfg
    end
  end

  def test_proxy_config
    RDig.configuration do |cfg|
      cfg.crawler.http_proxy = 'http://proxy.com:8080'
    end
    assert_equal 'http://proxy.com:8080', RDig.open_uri_http_options[:proxy]
    assert_nil RDig.open_uri_http_options['Authorization']
  end

  def test_proxy_auth
    RDig.configuration do |cfg|
      cfg.crawler.http_proxy = 'http://proxy.com:8080'
      cfg.crawler.http_proxy_user = 'username'
      cfg.crawler.http_proxy_pass = 'password'
    end
    assert_equal 'http://proxy.com:8080', RDig.open_uri_http_options[:proxy]
    assert_equal "Basic dXNlcm5hbWU6cGFzc3dvcmQ=\n", RDig.open_uri_http_options['Authorization']
  end

  def test_logger_equals
    RDig.logger = "this is a logger"
    assert_equal "this is a logger", RDig.instance_variable_get(:@logger)
    RDig.logger = nil
    assert_not_equal "this is a logger", RDig.instance_variable_get(:@logger)
  end

  def test_options
    RDig.application.instance_variable_set(:@options, 'options')
    assert_equal 'options', RDig.application.options
  end

  def test_usage
    RDig.application.expects(:puts)
    RDig.application.usage
  end
end
