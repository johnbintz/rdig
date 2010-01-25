require 'test_helper'
require 'mocha'

class SearcherTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @fixture_path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/'))
    index_dir = 'tmp/test-index'
    Dir.mkdir index_dir unless File.directory? index_dir
    RDig.configuration do |cfg|
      @old_crawler_cfg = cfg.crawler.clone
      cfg.crawler.start_urls = [ "file://#{@fixture_path}" ]
      cfg.crawler.num_threads = 1
      cfg.crawler.wait_before_leave = 1
      cfg.index.path = index_dir
      cfg.verbose = true
      cfg.log_level = :debug
      cfg.log_file = 'tmp/test.log'
    end
    crawler = Crawler.new
    crawler.run
  end

  def teardown
    RDig.configuration do |cfg|
      cfg.crawler = @old_crawler_cfg
    end
  end

  def test_search
    result = RDig.searcher.search 'some sample text'
    assert_equal 5, result[:hitcount]
    assert_equal 5, result[:list].size
  end

  def test_reopen_ferret_searcher
    mock = Class.new do
      def reader
        Class.new do
          def latest?; false; end
        end.new
      end
    end.new

    mock.expects(:close)

    RDig.searcher.instance_variable_set(:@ferret_searcher, mock)

    assert_not_equal RDig.searcher.ferret_searcher, mock
  end
end
