begin
  require 'hpricot'
  require 'htmlentities'
rescue LoadError
  require 'rubygems'
  require 'hpricot'
  require 'htmlentities'
end

module RDig
  module ContentExtractors

    # extracts title, content and links from html documents using the hpricot library
    class HpricotContentExtractor < ContentExtractor

      def initialize(config)
        super(config.hpricot)
        # if not configured, refuse to handle any content:
        @pattern = /^(text\/(html|xml)|application\/(xhtml\+xml|xml))/ if config.hpricot
      end

      # returns:
      # { :content => 'extracted clear text',
      #   :title => 'Title',
      #   :links => [array of urls] }
      def process(content)
        entities = HTMLEntities.new
        doc = Hpricot(content)
        {
          :title => entities.decode(extract_title(doc)).strip,
          :links => extract_links(doc),
          :content => entities.decode(extract_content(doc))
        }
      end

      # Extracts textual content from the HTML tree.
      #
      # - First, the root element to use is determined using the
      # +content_element+ method, which itself uses the content_tag_selector
      # from RDig.configuration.
      # - Then, this element is processed by +extract_text+, which will give
      # all textual content contained in the root element and all it's
      # children.
      def extract_content(doc)
        if ce = content_element(doc)
          return strip_tags(strip_comments(ce.inner_html))
        end
          # return (ce.inner_text || '').gsub(Regexp.new('\s+', Regexp::MULTILINE, 'u'), ' ').strip
        return ''
      end

      # extracts the href attributes of all a tags, except
      # internal links like <a href="#top">
      def extract_links(doc)
        {'a' => 'href', 'area' => 'href', 'frame' => 'src'}.map do |tag, attr|
          (doc/tag).map do |tag|
            value = tag[attr]
            CGI.unescapeHTML(value) if value && value !~ /^#/
          end
        end.flatten.compact
      end

      # Extracts the title from the given html tree
      def extract_title(doc)
        the_title_tag = title_tag(doc)
        return the_title_tag unless the_title_tag.respond_to? :inner_html
        strip_tags(the_title_tag.inner_html)
      end

      # Returns the element to extract the title from.
      #
      # This may return a string, e.g. an attribute value selected from a meta
      # tag, too.
      def title_tag(doc)
        tag_from_config(doc, :title_tag_selector) || doc.at('title')
      end

      # Retrieve the root element to extract document content from
      def content_element(doc)
        tag_from_config(doc, :content_tag_selector) || doc.at('body')
      end

      def tag_from_config(doc, config_key)
        cfg = @config.send(config_key)
        cfg.is_a?(String) ? doc/cfg : cfg.call(doc) if cfg
      end

      # Return the given string minus all html comments
      def strip_comments(string)
        string.gsub Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), ''
      end

      def strip_tags(string)
        string.gsub! Regexp.new('<(script|style).*?>.*?<\/(script|style).*?>',
                               Regexp::MULTILINE, 'u'), ''
        string.gsub! Regexp.new('<.+?>',
                               Regexp::MULTILINE, 'u'), ''
        string.gsub! Regexp.new('\s+', Regexp::MULTILINE, 'u'), ' '
        string.strip
      end

    end

  end
end
