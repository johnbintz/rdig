require 'test_helper'
class HpricotContentExtractorTest < Test::Unit::TestCase
  include TestHelper

  def setup
    @config = RDig.config.content_extraction.hpricot.clone
    @extractor = ContentExtractors::HpricotContentExtractor.new(OpenStruct.new(:hpricot => @config))
    @nbsp = [160].pack('U') # non breaking space
  end

  def test_can_do
    assert !@extractor.can_do('application/pdf')
    assert !@extractor.can_do('application/msword')
    assert @extractor.can_do('text/html')
    assert @extractor.can_do('text/xml')
    assert @extractor.can_do('application/xml')
    assert @extractor.can_do('application/xhtml+xml')
  end

  def test_simple
    result = ContentExtractors.process(html_doc('simple'), 'text/html')
    assert_not_nil result
    assert_equal 'Sample Title', result[:title]
    assert_not_nil result[:content]
    assert_not_nil result[:links]
    assert_equal 1, result[:links].size
    assert_equal 'A Link Affe Some sample text Lorem ipsum', result[:content]
    assert_equal 'http://test.host/affe.html', result[:links].first
  end

  def test_entities
    result = @extractor.process(html_doc('entities'))
    assert_equal 'Sample & Title', result[:title]
    assert_equal 'http://test.host/affe.html?b=a&c=d', result[:links].first
    assert_equal 'http://test.host/affe2.html?b=a&c=d', result[:links].last
    assert_equal "Some > Links don't#{@nbsp}break me! Affe Affe Ümläuts heiß hier ß", result[:content]
  end

  def test_custom_content_element
    @config.title_tag_selector = lambda do |doc|
      doc.at("h1[@class='title']")
    end
    @config.content_tag_selector = lambda do |doc|
      doc.at("div[@id='content']")
    end
    result = @extractor.process(html_doc('custom_tag_selectors'))
    assert_equal 'Sample Title in h1', result[:title]
    assert_equal 'Affe Real content is here.', result[:content]
    # check if links are collected outside the content tag, too:
    assert_equal 3, result[:links].size
    assert_equal 'http://test.host/outside.html', result[:links].first
    assert_equal '/inside.html', result[:links][1]
    assert_equal '/footer.html', result[:links][2]
  end

  def test_extracts_links_from_frameset
    result = @extractor.process(html_doc('frameset'))
    assert_equal 'http://test.host/first.html', result[:links].first
    assert_equal '/second.html', result[:links].last
  end

  def test_extracts_links_from_imagemap
    result = @extractor.process(html_doc('imagemap'))
    assert_equal 'http://test.host/first.html', result[:links].first
    assert_equal '/second.html', result[:links].last
  end


  def test_title_from_dcmeta
    @config.title_tag_selector = lambda do |doc|
      doc.at("meta[@name='DC.title']")['content']
    end
    result = @extractor.process(html_doc('custom_tag_selectors'))
    assert_equal 'Title from DC meta data', result[:title]
  end

  def test_preprocessed_title
    @config.title_tag_selector = lambda do |doc|
      title = doc.at("meta[@name='DC.title']")['content']
      # use only a portion of the title tag's contents if it matches our
      # regexp:
      (title =~ /^(.*)meta data$/ ? $1 : title).strip
    end
    result = @extractor.process(html_doc('custom_tag_selectors'))
    assert_equal 'Title from DC', result[:title]
  end
end
