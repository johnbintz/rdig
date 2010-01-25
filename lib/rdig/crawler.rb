module RDig
  class Crawler
    def initialize(config = RDig.config, logger = RDig.logger)
      @documents = Queue.new
      @logger = logger
      @config = config
      @urls_crawled = []
    end

    def run
      @indexer = Index::Indexer.new(@config.index)
      crawl
    ensure
      @indexer.close if @indexer
    end

    def crawl
      raise 'no start urls given!' if @config.crawler.start_urls.empty?
      # check whether we are indexing on-disk or via http
      url_type = @config.crawler.start_urls.first =~ /^file:\/\// ? :file : :http
      chain_config = RDig.filter_chain[url_type]

      @config.crawler.start_urls.each do |url|
        begin
          uri = URI.parse(url)
          if uri.scheme == 'http'
            @config.crawler.include_hosts << uri.host
          end
        rescue
        end
      end

      @config.crawler.include_hosts.uniq!

      @etag_filter = ETagFilter.new
      filterchain = UrlFilters::FilterChain.new(chain_config)
      @config.crawler.start_urls.each { |url| add_url(url, filterchain) }

      num_threads = @config.crawler.num_threads
      group = ThreadsWait.new
      num_threads.times { |i|
        group.join_nowait Thread.new("fetcher #{i}") {
          filterchain = UrlFilters::FilterChain.new(chain_config)
          while (doc = @documents.pop) != :exit
            process_document doc, filterchain
          end
        }
      }

      # check for an empty queue every now and then
      sleep_interval = @config.crawler.wait_before_leave
      begin
        sleep sleep_interval
      end until @documents.empty?
      # nothing to do any more, tell the threads to exit
      num_threads.times { @documents << :exit }

      @logger.info "waiting for threads to finish..."
      group.all_waits
    end

    def process_document(doc, filterchain)
      @logger.debug "processing document #{doc}"
      doc.fetch
      case doc.status
      when :success
        if @etag_filter.apply(doc)
          # add links from this document to the queue
          doc.content[:links].each { |url|
            add_url(url, filterchain, doc)
          } unless doc.content[:links].nil?
          add_to_index doc
        end
      when :redirect
        @logger.debug "redirect to #{doc.content}"
        add_url(doc.content, filterchain, doc)
      else
        @logger.error "unknown doc status #{doc.status}: #{doc}"
      end
    rescue
      @logger.error "error processing document #{doc.uri.to_s}: #{$!}"
      @logger.debug "Trace: #{$!.backtrace.join("\n")}"
    end

    def add_to_index(doc)
      @indexer << doc if doc.needs_indexing?
    end


    # pipes a new document pointing to url through the filter chain,
    # if it survives that, it gets added to the documents queue for further
    # processing
    def add_url(url, filterchain, referring_document = nil)
      return if url.nil? || url.empty?

      url = follow_redirects(url)

      if !@urls_crawled.index(url)
        begin
          @logger.debug "add_url #{url}"
          doc = if referring_document
            referring_document.create_child(url)
          else
            Document.create(url)
          end

          if doc.uri.scheme = 'http'
            if url_in_included_hosts(doc.uri.to_s)
              doc = filterchain.apply(doc)

              if doc
                @documents << doc
                @logger.debug "url #{url} survived filterchain"
              end
            end
          end
        rescue
        end
        @urls_crawled << url
      end
    end

    def follow_redirects(url)
      begin
        uri = URI.parse(url)
        if uri.host && (uri.schema == 'http')
          h = Net::HTTP.new(uri.host)

          5.times do |i|
            headers = h.get(url)
            if headers['location']
              @logger.debug "redirecting to #{headers['location']}"
              url = headers['location']

              if !url_in_included_hosts(url)
                break
              end
            else
              break
            end
          end
        end
        rescue
      end

      url
    end

    def url_in_included_hosts(url)
      ok = false
      begin
        uri = URI.parse(url)
        if @config.crawler.include_hosts.index(uri.host)
          ok = true
        end
      rescue
      end
      ok
    end
  end

  # checks fetched documents' E-Tag headers against the list of E-Tags
  # of the documents already indexed.
  # This is supposed to help against double-indexing documents which can
  # be reached via different URLs (think http://host.com/ and
  # http://host.com/index.html )
  # Documents without ETag are allowed to pass through
  class ETagFilter
    include MonitorMixin

    def initialize
      @etags = Set.new
      super
    end

    def apply(document)
      return document unless (document.respond_to?(:etag) && document.etag && !document.etag.empty?)
      synchronize do
        @etags.add?(document.etag) ? document : nil
      end
    end
  end
end
