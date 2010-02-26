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

      def process(content)
        doc = Hpricot(content)

        ret = {}

        @config.methods.collect { |m| if m[/_tag_selector$/]; [ m, m.to_s.gsub('_tag_selector', '') ]; end }.compact.each do |method, tag|
          value = tag_from_config(doc, method)
          if value
            post_process_method = "post_process_#{tag}".to_sym
            if respond_to? post_process_method
              value = send(post_process_method, value)
            end

            if value.respond_to? :to_html
              value = value.to_html
            end
            ret[tag.to_sym] = value
          end
        end

        methods.find_all { |m| m[/^extract_/] }.each do |method|
          tag = method.gsub('extract_', '').to_sym
          ret[tag] = send(method.to_sym, doc)
        end

        ret
      end

      # extracts the href attributes of all a tags, except
      # internal links like <a href="#top">
      def extract_links(doc)
        {'a' => 'href', 'area' => 'href', 'frame' => 'src'}.map do |tag, attr|
          (doc/tag).map do |tag|
            value = tag[attr]
            CGI.unescapeHTML(value) if value && value !~ /^#/
           	if @config.link_filter
           		value = @config.link_filter.call(value)
           	end
           	value
          end
        end.flatten.compact
      end

      # post process title elements
      def post_process_title(title)
        if title.respond_to? :inner_html
          title = title.inner_html
        end

        HTMLEntities.new.decode(strip_tags(title)).strip
      end

      # post process content elements
      def post_process_content(content)
        if content.respond_to? :inner_html
          content = content.inner_html
        end

        HTMLEntities.new.decode(strip_tags(content))
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
